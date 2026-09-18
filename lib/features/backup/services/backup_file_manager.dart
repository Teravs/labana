import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/backup_models.dart';

/// Kontrak abstraksi pengelolaan berkas cadangan database lokal.
abstract class BackupFileManager {
  /// Mengembalikan direktori penyimpanan berkas cadangan lokal.
  Future<Directory> getBackupDirectory();

  /// Menghasilkan nama berkas cadangan dasar sesuai tanggal (misal: "Labana-Backup-2026-09-16").
  String generateBackupFileName({DateTime? date});

  /// Mengembalikan berkas target unik dengan penanganan tabrakan nama (-2.db, -3.db, dst).
  Future<File> resolveUniqueBackupFile(String baseName);

  /// Membaca dan mengurutkan seluruh berkas cadangan lokal (.db) dari yang terbaru.
  Future<List<BackupFileInfo>> listLocalBackups();

  /// Menghapus berkas cadangan lokal.
  Future<bool> deleteBackup(String filePath);

  /// Membagikan berkas cadangan melalui system share sheet via share_plus.
  Future<bool> shareBackup(String filePath, {String? subject});

  /// Mengunduh / menyalin berkas cadangan ke folder Download publik perangkat.
  /// Mengembalikan path absolut berkas yang berhasil disimpan, atau null jika dibatalkan oleh pengguna.
  Future<String?> downloadBackupToDownloads(String filePath);
}

/// Implementasi produksi BackupFileManager menggunakan path_provider dan share_plus.
class AppBackupFileManager implements BackupFileManager {
  const AppBackupFileManager();

  @override
  Future<Directory> getBackupDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  @override
  String generateBackupFileName({DateTime? date}) {
    final d = date ?? DateTime.now();
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'Labana-Backup-$year-$month-$day';
  }

  /// Membersihkan nama dari karakter terlarang filesystem.
  static String sanitizeFileName(String name) {
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    var clean = name.replaceAll(invalidChars, '-');
    clean = clean.replaceAll(RegExp(r'\s+'), '-');
    clean = clean.replaceAll(RegExp(r'-+'), '-');
    clean = clean.trim();
    if (clean.isEmpty) clean = 'Labana-Backup';
    return clean;
  }

  @override
  Future<File> resolveUniqueBackupFile(String baseName) async {
    final backupDir = await getBackupDirectory();
    final sanitized = sanitizeFileName(baseName);

    var finalPath = p.join(backupDir.path, '$sanitized.db');
    var file = File(finalPath);
    var counter = 2;

    while (await file.exists()) {
      finalPath = p.join(backupDir.path, '$sanitized-$counter.db');
      file = File(finalPath);
      counter++;
    }

    return file;
  }

  @override
  Future<List<BackupFileInfo>> listLocalBackups() async {
    final backupDir = await getBackupDirectory();
    final entities = await backupDir.list().toList();

    final result = <BackupFileInfo>[];
    for (final entity in entities) {
      if (entity is File && entity.path.toLowerCase().endsWith('.db')) {
        final fileName = p.basename(entity.path);
        // Abaikan file sementara seperti restore_tmp atau pre_restore
        if (fileName.contains('.tmp') || fileName.contains('.snapshot')) {
          continue;
        }

        final stat = await entity.stat();
        result.add(
          BackupFileInfo(
            filePath: entity.path,
            fileName: fileName,
            fileSizeBytes: stat.size,
            createdAt: stat.modified,
          ),
        );
      }
    }

    // Urutkan dari yang terbaru ke terlama
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<bool> deleteBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  @override
  Future<bool> shareBackup(String filePath, {String? subject}) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final xFile = XFile(filePath, mimeType: 'application/x-sqlite3');
    final result = await Share.shareXFiles([
      xFile,
    ], subject: subject ?? 'Cadangan Database Labana');

    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<String?> downloadBackupToDownloads(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException(
        'Berkas cadangan sumber tidak ditemukan.',
      );
    }

    final originalName = p.basenameWithoutExtension(filePath);
    final ext = p.extension(filePath).isNotEmpty
        ? p.extension(filePath)
        : '.db';

    // 1. Coba simpan langsung ke folder Download publik perangkat
    Directory? targetDir;
    if (Platform.isAndroid) {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) {
        targetDir = publicDownload;
      }
    }

    if (targetDir == null) {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
    }

    if (targetDir != null) {
      try {
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        var candidatePath = p.join(targetDir.path, '$originalName$ext');
        var candidateFile = File(candidatePath);
        var counter = 2;
        while (await candidateFile.exists()) {
          candidatePath = p.join(targetDir.path, '$originalName-$counter$ext');
          candidateFile = File(candidatePath);
          counter++;
        }

        await sourceFile.copy(candidatePath);
        return candidatePath;
      } catch (_) {
        // Jika gagal direct copy karena Scoped Storage Android, lanjut ke fallback SAF
      }
    }

    // 2. Fallback SAF via FilePicker.platform.saveFile
    final cleanExt = ext.replaceFirst('.', '');
    final allowedExts = cleanExt.isNotEmpty ? [cleanExt] : ['db'];
    try {
      final bytes = await sourceFile.readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Unduh Berkas ke Folder Download',
        fileName: '$originalName$ext',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: allowedExts,
      );
      return savedPath;
    } catch (_) {
      try {
        final bytes = await sourceFile.readAsBytes();
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Unduh Cadangan ke Folder Download',
          fileName: '$originalName$ext',
          bytes: bytes,
          type: FileType.any,
        );
        return savedPath;
      } catch (e) {
        throw FileSystemException('Gagal mengunduh berkas cadangan: $e');
      }
    }
  }
}

/// Implementasi fake untuk keperluan unit dan widget testing.
class FakeBackupFileManager implements BackupFileManager {
  final List<BackupFileInfo> localBackups = [];
  final Directory tempDirectory;
  bool shareCalled = false;
  String? lastSharedPath;
  bool downloadCalled = false;
  String? lastDownloadedPath;

  FakeBackupFileManager({Directory? tempDir})
    : tempDirectory =
          tempDir ?? Directory.systemTemp.createTempSync('labana_fake_backup_');

  @override
  Future<Directory> getBackupDirectory() async {
    if (!tempDirectory.existsSync()) {
      tempDirectory.createSync(recursive: true);
    }
    return tempDirectory;
  }

  @override
  String generateBackupFileName({DateTime? date}) {
    final d = date ?? DateTime.now();
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'Labana-Backup-$year-$month-$day';
  }

  @override
  Future<File> resolveUniqueBackupFile(String baseName) async {
    final dir = await getBackupDirectory();
    final sanitized = AppBackupFileManager.sanitizeFileName(baseName);

    var finalPath = p.join(dir.path, '$sanitized.db');
    var file = File(finalPath);
    var counter = 2;

    while (file.existsSync()) {
      finalPath = p.join(dir.path, '$sanitized-$counter.db');
      file = File(finalPath);
      counter++;
    }

    return file;
  }

  @override
  Future<List<BackupFileInfo>> listLocalBackups() async {
    final result = <BackupFileInfo>[...localBackups];
    if (tempDirectory.existsSync()) {
      final entities = tempDirectory.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.db')) {
          final fileName = p.basename(entity.path);
          if (fileName.contains('.tmp') || fileName.contains('.snapshot')) {
            continue;
          }
          if (result.any((b) => b.filePath == entity.path)) {
            continue;
          }
          final stat = entity.statSync();
          result.add(
            BackupFileInfo(
              filePath: entity.path,
              fileName: fileName,
              fileSizeBytes: stat.size,
              createdAt: stat.modified,
            ),
          );
        }
      }
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  @override
  Future<bool> deleteBackup(String filePath) async {
    localBackups.removeWhere((item) => item.filePath == filePath);
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    return true;
  }

  @override
  Future<bool> shareBackup(String filePath, {String? subject}) async {
    shareCalled = true;
    lastSharedPath = filePath;
    return true;
  }

  @override
  Future<String?> downloadBackupToDownloads(String filePath) async {
    downloadCalled = true;
    final sourceFile = File(filePath);
    final downloadsDir = Directory(p.join(tempDirectory.path, 'downloads'));
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }
    final targetPath = p.join(downloadsDir.path, p.basename(filePath));
    if (sourceFile.existsSync()) {
      sourceFile.copySync(targetPath);
    } else {
      File(targetPath).writeAsStringSync('fake backup data');
    }
    lastDownloadedPath = targetPath;
    return targetPath;
  }
}
