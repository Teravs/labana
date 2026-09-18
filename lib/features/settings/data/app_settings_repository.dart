import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/business_profile.dart';

/// Repository untuk mengelola konfigurasi aplikasi dan identitas usaha (nama toko, slogan, logo)
/// pada tabel `settings` SQLite.
class AppSettingsRepository {
  static const String keyBusinessName = 'business_name';
  static const String keyBusinessTagline = 'business_tagline';
  static const String keyBusinessLogoPath = 'business_logo_path';

  /// Notifier reaktif global untuk menyebarkan perubahan profil toko ke seluruh UI secara instan.
  static final ValueNotifier<BusinessProfile> businessProfileNotifier =
      ValueNotifier<BusinessProfile>(const BusinessProfile());

  final DatabaseHelper _dbHelper;
  final Directory? _customBrandingDir;

  AppSettingsRepository({
    DatabaseHelper? dbHelper,
    Directory? customBrandingDir,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _customBrandingDir = customBrandingDir;

  Future<Database> get _db async => await _dbHelper.database;

  /// Mengembalikan direktori penyimpanan logo kustom aplikasi.
  Future<Directory> _getBrandingDirectory() async {
    if (_customBrandingDir != null) {
      if (!await _customBrandingDir.exists()) {
        await _customBrandingDir.create(recursive: true);
      }
      return _customBrandingDir;
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final brandingDir = Directory(p.join(docsDir.path, 'branding'));
    if (!await brandingDir.exists()) {
      await brandingDir.create(recursive: true);
    }
    return brandingDir;
  }

  /// Membaca profil usaha dari database dan memperbarui `businessProfileNotifier`.
  Future<BusinessProfile> getBusinessProfile() async {
    final db = await _db;
    final results = await db.query(TableNames.settings);

    final map = <String, String>{};
    for (final row in results) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key != null && value != null) {
        map[key] = value;
      }
    }

    final name = map[keyBusinessName]?.trim().isNotEmpty == true
        ? map[keyBusinessName]!
        : AppConstants.appName;
    final tagline = map[keyBusinessTagline]?.trim().isNotEmpty == true
        ? map[keyBusinessTagline]!
        : AppConstants.appTagline;
    final logoPath = map[keyBusinessLogoPath]?.trim().isNotEmpty == true
        ? map[keyBusinessLogoPath]
        : null;

    final profile = BusinessProfile(
      name: name,
      tagline: tagline,
      logoPath: logoPath,
    );

    businessProfileNotifier.value = profile;
    return profile;
  }

  /// Menyimpan perubahan profil usaha ke database SQLite dan memperbarui `businessProfileNotifier`.
  Future<BusinessProfile> saveBusinessProfile({
    required String name,
    required String tagline,
    String? newLogoSourcePath,
    bool clearLogo = false,
  }) async {
    final db = await _db;
    final currentProfile = businessProfileNotifier.value;
    String? finalLogoPath = currentProfile.logoPath;

    if (clearLogo) {
      if (finalLogoPath != null) {
        final oldFile = File(finalLogoPath);
        if (await oldFile.exists()) {
          try {
            await oldFile.delete();
          } catch (_) {}
        }
      }
      finalLogoPath = null;
    } else if (newLogoSourcePath != null && newLogoSourcePath.trim().isNotEmpty) {
      final sourceFile = File(newLogoSourcePath);
      if (await sourceFile.exists()) {
        final brandingDir = await _getBrandingDirectory();
        final ext = p.extension(newLogoSourcePath).isNotEmpty
            ? p.extension(newLogoSourcePath)
            : '.png';
        final targetPath = p.join(brandingDir.path, 'business_logo$ext');
        await sourceFile.copy(targetPath);
        finalLogoPath = targetPath;
      }
    }

    final cleanName = name.trim().isNotEmpty ? name.trim() : AppConstants.appName;
    final cleanTagline =
        tagline.trim().isNotEmpty ? tagline.trim() : AppConstants.appTagline;

    await db.transaction((txn) async {
      await txn.insert(
        TableNames.settings,
        {'key': keyBusinessName, 'value': cleanName},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        TableNames.settings,
        {'key': keyBusinessTagline, 'value': cleanTagline},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (finalLogoPath != null) {
        await txn.insert(
          TableNames.settings,
          {'key': keyBusinessLogoPath, 'value': finalLogoPath},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.delete(
          TableNames.settings,
          where: 'key = ?',
          whereArgs: [keyBusinessLogoPath],
        );
      }
    });

    final updatedProfile = BusinessProfile(
      name: cleanName,
      tagline: cleanTagline,
      logoPath: finalLogoPath,
    );

    businessProfileNotifier.value = updatedProfile;
    return updatedProfile;
  }

  /// Mengembalikan identitas usaha ke bawaan Labana asli.
  Future<BusinessProfile> resetToDefault() async {
    final db = await _db;
    final currentProfile = businessProfileNotifier.value;
    if (currentProfile.logoPath != null) {
      final file = File(currentProfile.logoPath!);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }

    await db.transaction((txn) async {
      await txn.delete(
        TableNames.settings,
        where: 'key IN (?, ?, ?)',
        whereArgs: [keyBusinessName, keyBusinessTagline, keyBusinessLogoPath],
      );
    });

    const defaultProfile = BusinessProfile();
    businessProfileNotifier.value = defaultProfile;
    return defaultProfile;
  }
}

