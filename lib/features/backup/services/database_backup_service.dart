import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../sales/data/sale_repository.dart';
import '../models/backup_models.dart';
import 'backup_file_manager.dart';
import 'external_file_picker.dart';

/// Layanan utama untuk orkestrasi pembuatan backup, validasi berkas, dan pemulihan (restore)
/// database SQLite Labana secara aman dengan proteksi rollback atomik (zero data loss).
class DatabaseBackupService {
  final DatabaseHelper _dbHelper;
  final BackupFileManager _fileManager;
  final ExternalFilePicker _filePicker;

  DatabaseBackupService({
    DatabaseHelper? dbHelper,
    BackupFileManager? fileManager,
    ExternalFilePicker? filePicker,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _fileManager = fileManager ?? const AppBackupFileManager(),
       _filePicker = filePicker ?? const AppExternalFilePicker();

  BackupFileManager get fileManager => _fileManager;
  ExternalFilePicker get filePicker => _filePicker;

  /// Header ASCII 16-byte standar SQLite 3: "SQLite format 3\000"
  static const List<int> sqliteHeaderMagicBytes = [
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  /// Membuat berkas cadangan (.db) dari database SQLite aktual Labana.
  Future<File> createBackup({String? customName}) async {
    // 1. Checkpoint WAL pada database aktif untuk mengonsolidasikan transaksi terakhir ke file utama
    await _dbHelper.checkpoint();

    // 2. Dapatkan lokasi absolut berkas database aktif
    final activeDbPath = await _dbHelper.getDatabasePath();
    final activeDbFile = File(activeDbPath);

    if (!await activeDbFile.exists()) {
      // Pastikan database terinisialisasi jika belum pernah dibuka
      await _dbHelper.database;
      if (!await activeDbFile.exists()) {
        throw const DatabaseBackupException(
          'Berkas database utama tidak ditemukan untuk dicadangkan.',
        );
      }
    }

    // 3. Tentukan nama target berkas cadangan dengan penanganan tabrakan nama
    final baseName = customName ?? _fileManager.generateBackupFileName();
    final targetFile = await _fileManager.resolveUniqueBackupFile(baseName);

    // 4. Salin berkas database ke folder tujuan
    await activeDbFile.copy(targetFile.path);

    return targetFile;
  }

  /// Membuka file picker untuk memilih berkas .db dari luar aplikasi.
  Future<File?> pickExternalBackupFile() async {
    return await _filePicker.pickDatabaseFile();
  }

  /// Memvalidasi berkas cadangan secara menyeluruh:
  /// 1. Eksistensi dan ukuran berkas (> 100 bytes).
  /// 2. 16-byte magic header SQLite.
  /// 3. Read-only integrity check (PRAGMA integrity_check = 'ok').
  /// 4. Foreign key check (PRAGMA foreign_key_check).
  /// 5. Kompatibilitas versi skema database (PRAGMA user_version).
  /// 6. Keberadaan seluruh 12 tabel inti Labana.
  /// 7. Ekstraksi ringkasan data (transaksi, produk, bahan).
  Future<BackupValidationResult> validateBackupFile(File file) async {
    // 1. Validasi eksistensi dan ukuran berkas
    if (!await file.exists()) {
      return const BackupValidationResult.invalid(
        'Berkas cadangan tidak ditemukan di penyimpanan.',
      );
    }

    final length = await file.length();
    if (length < 100) {
      return const BackupValidationResult.invalid(
        'Ukuran berkas terlalu kecil atau bukan merupakan berkas database SQLite yang valid.',
      );
    }

    // 2. Validasi 16-byte SQLite Header Magic Bytes
    try {
      final headerBytes = await file.openRead(0, 16).first;
      if (headerBytes.length < 16) {
        return const BackupValidationResult.invalid(
          'Header berkas cadangan tidak lengkap.',
        );
      }
      for (int i = 0; i < 16; i++) {
        if (headerBytes[i] != sqliteHeaderMagicBytes[i]) {
          return const BackupValidationResult.invalid(
            'Format berkas tidak valid. Berkas bukan merupakan database SQLite Labana yang sah.',
          );
        }
      }
    } catch (e) {
      return BackupValidationResult.invalid('Gagal membaca header berkas: $e');
    }

    // 3. Validasi isi database menggunakan koneksi read-only sementara
    Database? tempDb;
    try {
      tempDb = await openDatabase(file.path, readOnly: true);

      // A. Integrity Check
      final integrityResult = await tempDb.rawQuery('PRAGMA integrity_check;');
      if (integrityResult.isEmpty ||
          integrityResult.first.values.first.toString().toLowerCase() != 'ok') {
        return const BackupValidationResult.invalid(
          'Integritas database cadangan rusak (corrupt). Pemulihan dibatalkan demi keamanan.',
        );
      }

      // B. Foreign Key Check
      final fkCheckResult = await tempDb.rawQuery('PRAGMA foreign_key_check;');
      if (fkCheckResult.isNotEmpty) {
        return const BackupValidationResult.invalid(
          'Database cadangan memiliki inkonsistensi relasi data (foreign key violation).',
        );
      }

      // C. Versi Database / Kompatibilitas Skema
      final versionResult = await tempDb.rawQuery('PRAGMA user_version;');
      final dbVersion = versionResult.isNotEmpty
          ? (versionResult.first.values.first as int? ?? 0)
          : 0;

      if (dbVersion > DatabaseConstants.databaseVersion) {
        return BackupValidationResult.invalid(
          'Versi database cadangan (v$dbVersion) lebih baru daripada versi aplikasi ini (v${DatabaseConstants.databaseVersion}). Silakan perbarui aplikasi Labana.',
        );
      }

      // D. Validasi Keberadaan Seluruh 12 Tabel Labana
      final tablesResult = await tempDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata';",
      );
      final existingTables = tablesResult
          .map((row) => row['name'] as String)
          .toSet();

      for (final expectedTable in TableNames.all) {
        if (!existingTables.contains(expectedTable)) {
          return BackupValidationResult.invalid(
            'Skema database tidak cocok. Tabel "$expectedTable" tidak ditemukan pada berkas cadangan.',
          );
        }
      }

      // E. Ekstraksi Ringkasan Data
      final trxCount =
          Sqflite.firstIntValue(
            await tempDb.rawQuery('SELECT COUNT(*) FROM ${TableNames.sales};'),
          ) ??
          0;

      final prodCount =
          Sqflite.firstIntValue(
            await tempDb.rawQuery(
              'SELECT COUNT(*) FROM ${TableNames.products};',
            ),
          ) ??
          0;

      final ingCount =
          Sqflite.firstIntValue(
            await tempDb.rawQuery(
              'SELECT COUNT(*) FROM ${TableNames.ingredients};',
            ),
          ) ??
          0;

      final procCount =
          Sqflite.firstIntValue(
            await tempDb.rawQuery(
              'SELECT COUNT(*) FROM ${TableNames.processedIngredients};',
            ),
          ) ??
          0;

      final lastSale = await tempDb.rawQuery(
        'SELECT transaction_date FROM ${TableNames.sales} ORDER BY transaction_date DESC, id DESC LIMIT 1;',
      );
      final lastDate = lastSale.isNotEmpty
          ? lastSale.first['transaction_date'] as String?
          : null;

      final summary = BackupDataSummary(
        transactionCount: trxCount,
        productCount: prodCount,
        ingredientCount: ingCount,
        processedIngredientCount: procCount,
        databaseVersion: dbVersion,
        lastTransactionDate: lastDate,
      );

      return BackupValidationResult.valid(summary);
    } catch (e) {
      return BackupValidationResult.invalid(
        'Gagal memvalidasi struktur database cadangan: $e',
      );
    } finally {
      await tempDb?.close();
    }
  }

  /// Memulihkan (restore) database dari berkas cadangan dengan alur atomik bertahap
  /// dan proteksi rollback otomatis jika terjadi kegagalan.
  Future<void> restoreDatabase({
    required File backupFile,
    Function()? onStateRefresh,
  }) async {
    // 1. Validasi awal berkas cadangan sebelum melakukan perubahan apa pun
    final validation = await validateBackupFile(backupFile);
    if (!validation.isValid) {
      throw DatabaseBackupException(
        validation.errorMessage ?? 'Berkas cadangan tidak valid.',
      );
    }

    final activeDbPath = await _dbHelper.getDatabasePath();
    final dbDir = p.dirname(activeDbPath);
    final activeDbFile = File(activeDbPath);

    final preRestoreSnapshotFile = File(
      p.join(dbDir, 'labana.db.pre_restore_snapshot'),
    );
    final oldActiveBackupFile = File(p.join(dbDir, 'labana.db.old'));
    final tempRestoreFile = File(p.join(dbDir, 'labana.db.restore_tmp'));

    // 2. Checkpoint WAL database aktif jika sedang terbuka
    await _dbHelper.checkpoint();

    // 3. Buat Pre-Restore Safety Snapshot dari database aktif
    if (await activeDbFile.exists()) {
      if (await preRestoreSnapshotFile.exists()) {
        await preRestoreSnapshotFile.delete();
      }
      await activeDbFile.copy(preRestoreSnapshotFile.path);
    }

    // 4. Tutup koneksi DatabaseHelper aktif dengan tuntas
    await _dbHelper.close();

    // 5. Bersihkan file WAL dan SHM lama HANYA SETELAH koneksi ditutup secara tuntas
    await _cleanupWalFiles(activeDbPath);

    // 6. Siapkan berkas restore sementara (restore_tmp)
    if (await tempRestoreFile.exists()) {
      await tempRestoreFile.delete();
    }
    await backupFile.copy(tempRestoreFile.path);

    // 7. Verifikasi integritas berkas restore sementara
    Database? tempVerifyDb;
    try {
      tempVerifyDb = await openDatabase(tempRestoreFile.path, readOnly: true);
      final check = await tempVerifyDb.rawQuery('PRAGMA integrity_check;');
      final fkCheck = await tempVerifyDb.rawQuery('PRAGMA foreign_key_check;');
      if (check.isEmpty ||
          check.first.values.first.toString().toLowerCase() != 'ok' ||
          fkCheck.isNotEmpty) {
        throw const DatabaseBackupException(
          'Verifikasi berkas pemulihan sementara gagal.',
        );
      }
    } catch (e) {
      // Pemulihan sementara gagal, database aktif belum disentuh
      await tempVerifyDb?.close();
      if (await tempRestoreFile.exists()) {
        await tempRestoreFile.delete();
      }
      if (await preRestoreSnapshotFile.exists()) {
        await preRestoreSnapshotFile.delete();
      }
      await _dbHelper.reopenDatabase();
      throw DatabaseBackupException(
        'Gagal memverifikasi berkas cadangan sementara: $e',
      );
    } finally {
      await tempVerifyDb?.close();
    }

    // 8. Penggantian database secara aman: simpan active lama ke .old lalu salin restore_tmp ke active
    try {
      if (await activeDbFile.exists()) {
        if (await oldActiveBackupFile.exists()) {
          await oldActiveBackupFile.delete();
        }
        await activeDbFile.copy(oldActiveBackupFile.path);
      }

      await tempRestoreFile.copy(activeDbPath);
      await tempRestoreFile.delete();
    } catch (e) {
      // Jika terjadi kesalahan filesystem saat penggantian, lakukan rollback darurat
      await _emergencyRollback(
        preRestoreSnapshotFile: preRestoreSnapshotFile,
        activeDbPath: activeDbPath,
      );
      throw DatabaseBackupException(
        'Gagal mengganti berkas database pada filesystem. Database telah dipulihkan ke kondisi semula.',
        e.toString(),
      );
    }

    // 9. Buka kembali koneksi database
    Database? newActiveDb;
    try {
      newActiveDb = await _dbHelper.reopenDatabase();

      // 10. Verifikasi integritas akhir & foreign key pada database yang baru dibuka
      final finalIntegrity = await newActiveDb.rawQuery(
        'PRAGMA integrity_check;',
      );
      final finalFk = await newActiveDb.rawQuery('PRAGMA foreign_key_check;');

      if (finalIntegrity.isEmpty ||
          finalIntegrity.first.values.first.toString().toLowerCase() != 'ok' ||
          finalFk.isNotEmpty) {
        throw const DatabaseBackupException(
          'Database baru gagal melewati verifikasi integritas akhir.',
        );
      }

      // Verifikasi pembacaan tabel dasar
      await newActiveDb.rawQuery(
        'SELECT COUNT(*) FROM ${TableNames.ingredients};',
      );
      await newActiveDb.rawQuery('SELECT COUNT(*) FROM ${TableNames.sales};');
    } catch (e) {
      // ROLLBACK OTOMATIS: Tutup database rusak, kembalikan dari pre_restore_snapshot, buka kembali
      await _emergencyRollback(
        preRestoreSnapshotFile: preRestoreSnapshotFile,
        activeDbPath: activeDbPath,
      );
      throw DatabaseBackupException(
        'Verifikasi database aktif pasca-pemulihan gagal. Database telah dipulihkan ke kondisi semula.',
        e.toString(),
      );
    }

    // 11. Sukses tuntas: bersihkan berkas snapshot cadangan
    if (await preRestoreSnapshotFile.exists()) {
      await preRestoreSnapshotFile.delete();
    }
    if (await oldActiveBackupFile.exists()) {
      await oldActiveBackupFile.delete();
    }

    // 12. Refresh seluruh state aplikasi (Home, Laporan, Bahan, Penjualan)
    SaleRepository.salesChangeNotifier.value++;
    onStateRefresh?.call();
  }

  /// Menghapus file log WAL dan shared memory hanya saat koneksi database sudah ditutup.
  Future<void> _cleanupWalFiles(String dbPath) async {
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    final journalFile = File('$dbPath-journal');

    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
    if (await shmFile.exists()) {
      try {
        await shmFile.delete();
      } catch (_) {}
    }
    if (await journalFile.exists()) {
      try {
        await journalFile.delete();
      } catch (_) {}
    }
  }

  /// Rollback darurat: mengembalikan database aktif dari pre_restore_snapshot.
  Future<void> _emergencyRollback({
    required File preRestoreSnapshotFile,
    required String activeDbPath,
  }) async {
    try {
      await _dbHelper.close();
      await _cleanupWalFiles(activeDbPath);

      if (await preRestoreSnapshotFile.exists()) {
        final activeFile = File(activeDbPath);
        if (await activeFile.exists()) {
          await activeFile.delete();
        }
        await preRestoreSnapshotFile.copy(activeDbPath);
        await preRestoreSnapshotFile.delete();
      }

      await _dbHelper.reopenDatabase();
      SaleRepository.salesChangeNotifier.value++;
    } catch (_) {
      // Upaya terbaik rollback
    }
  }
}
