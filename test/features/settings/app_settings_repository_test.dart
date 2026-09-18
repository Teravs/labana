import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/settings/data/app_settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbFilePath;
  late Database testDb;
  late AppSettingsRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_settings_test_');
    dbFilePath = p.join(tempDir.path, DatabaseConstants.databaseName);

    testDb = await openDatabase(
      dbFilePath,
      version: DatabaseConstants.databaseVersion,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
    );
    DatabaseHelper.instance.setTestDatabase(testDb);

    repo = AppSettingsRepository(
      dbHelper: DatabaseHelper.instance,
      customBrandingDir: Directory(p.join(tempDir.path, 'branding')),
    );
  });

  tearDown(() async {
    DatabaseHelper.instance.setTestDatabase(null);
    await testDb.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AppSettingsRepository - BusinessProfile', () {
    test('mengembalikan profil default jika database settings kosong', () async {
      final profile = await repo.getBusinessProfile();

      expect(profile.name, 'Labana');
      expect(profile.tagline, 'Kelola Modal, Pahami Laba.');
      expect(profile.logoPath, isNull);
      expect(profile.hasCustomLogo, isFalse);
      expect(AppSettingsRepository.businessProfileNotifier.value.name, 'Labana');
    });

    test('menyimpan dan memuat profil bisnis kustom dengan benar', () async {
      // Buat berkas dummy logo
      final dummyLogo = File(p.join(tempDir.path, 'source_logo.png'));
      dummyLogo.writeAsBytesSync([1, 2, 3, 4, 5]);

      final saved = await repo.saveBusinessProfile(
        name: 'Dapur Nusantara',
        tagline: 'Cita Rasa Nusantara Asli',
        newLogoSourcePath: dummyLogo.path,
      );

      expect(saved.name, 'Dapur Nusantara');
      expect(saved.tagline, 'Cita Rasa Nusantara Asli');
      expect(saved.hasCustomLogo, isTrue);
      expect(saved.logoPath, isNotNull);
      expect(File(saved.logoPath!).existsSync(), isTrue);

      // Verifikasi ValueNotifier terupdate
      expect(
        AppSettingsRepository.businessProfileNotifier.value.name,
        'Dapur Nusantara',
      );

      // Verifikasi pembacaan ulang dari database SQLite
      final loaded = await repo.getBusinessProfile();
      expect(loaded.name, 'Dapur Nusantara');
      expect(loaded.tagline, 'Cita Rasa Nusantara Asli');
      expect(loaded.hasCustomLogo, isTrue);
      expect(loaded.logoPath, saved.logoPath);
    });

    test('resetToDefault mengembalikan profil ke Labana dan membersihkan logo', () async {
      final dummyLogo = File(p.join(tempDir.path, 'source_logo.png'));
      dummyLogo.writeAsBytesSync([1, 2, 3]);

      final custom = await repo.saveBusinessProfile(
        name: 'Kedai Kopi 99',
        tagline: 'Kopi Mantap',
        newLogoSourcePath: dummyLogo.path,
      );
      expect(File(custom.logoPath!).existsSync(), isTrue);

      final resetProfile = await repo.resetToDefault();

      expect(resetProfile.name, 'Labana');
      expect(resetProfile.tagline, 'Kelola Modal, Pahami Laba.');
      expect(resetProfile.logoPath, isNull);
      expect(resetProfile.hasCustomLogo, isFalse);
      expect(File(custom.logoPath!).existsSync(), isFalse);

      final loaded = await repo.getBusinessProfile();
      expect(loaded.name, 'Labana');
      expect(loaded.tagline, 'Kelola Modal, Pahami Laba.');
      expect(loaded.hasCustomLogo, isFalse);
    });
  });
}

