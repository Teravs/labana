import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/backup/models/backup_models.dart';
import 'package:labana/features/backup/services/backup_file_manager.dart';
import 'package:labana/features/backup/services/database_backup_service.dart';
import 'package:labana/features/backup/services/external_file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempTestDir;
  late String activeDbPath;
  late FakeBackupFileManager fakeFileManager;
  late FakeExternalFilePicker fakeFilePicker;
  late DatabaseBackupService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempTestDir = Directory.systemTemp.createTempSync('db_backup_test_');
    activeDbPath = p.join(tempTestDir.path, DatabaseConstants.databaseName);

    // Buat database SQLite aktif dengan skema lengkap Labana
    final db = await openDatabase(
      activeDbPath,
      version: DatabaseConstants.databaseVersion,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
    );

    // Isi data awal (seed)
    await db.insert(TableNames.ingredients, {
      'id': 1,
      'name': 'Gula Pasir',
      'status': 'active',
      'created_at': '2026-09-16 10:00:00',
      'updated_at': '2026-09-16 10:00:00',
    });

    await db.insert(TableNames.products, {
      'id': 1,
      'name': 'Es Teh Manis',
      'status': 'active',
      'created_at': '2026-09-16 10:00:00',
      'updated_at': '2026-09-16 10:00:00',
    });

    await db.insert(TableNames.sales, {
      'id': 1,
      'transaction_number': 'TRX-20260916-0001',
      'transaction_date': '2026-09-16 11:30:00',
      'total_amount': 15000,
      'total_hpp': 5000,
      'total_profit': 10000,
      'payment_method': 'cash',
      'created_at': '2026-09-16 11:30:00',
      'updated_at': '2026-09-16 11:30:00',
    });

    DatabaseHelper.instance.setTestDatabase(db);

    fakeFileManager = FakeBackupFileManager(
      tempDir: Directory(p.join(tempTestDir.path, 'backups')),
    );
    fakeFilePicker = FakeExternalFilePicker();

    service = DatabaseBackupService(
      dbHelper: DatabaseHelper.instance,
      fileManager: fakeFileManager,
      filePicker: fakeFilePicker,
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    if (tempTestDir.existsSync()) {
      tempTestDir.deleteSync(recursive: true);
    }
  });

  group('DatabaseBackupService Tests', () {
    test(
      '1. createBackup menghasilkan berkas SQLite valid dengan seluruh tabel dan data',
      () async {
        final backupFile = await service.createBackup(
          customName: 'Backup-Uji-1',
        );

        expect(await backupFile.exists(), isTrue);
        expect(p.basename(backupFile.path), 'Backup-Uji-1.db');

        // Validasi berkas cadangan
        final validation = await service.validateBackupFile(backupFile);
        expect(validation.isValid, isTrue);
        expect(validation.summary, isNotNull);

        final summary = validation.summary!;
        expect(summary.ingredientCount, 1);
        expect(summary.productCount, 1);
        expect(summary.transactionCount, 1);
        expect(summary.lastTransactionDate, '2026-09-16 11:30:00');
      },
    );

    test(
      '2. validateBackupFile menolak berkas yang tidak ada atau kosong (< 100 byte)',
      () async {
        final nonExistent = File(p.join(tempTestDir.path, 'ghost.db'));
        final res1 = await service.validateBackupFile(nonExistent);
        expect(res1.isValid, isFalse);
        expect(res1.errorMessage, contains('tidak ditemukan'));

        final emptyFile = File(p.join(tempTestDir.path, 'empty.db'));
        await emptyFile.writeAsString('terlalu kecil');
        final res2 = await service.validateBackupFile(emptyFile);
        expect(res2.isValid, isFalse);
        expect(res2.errorMessage, contains('terlalu kecil'));
      },
    );

    test(
      '3. validateBackupFile menolak berkas non-SQLite (magic header salah)',
      () async {
        final corruptFile = File(p.join(tempTestDir.path, 'fake_header.db'));
        // Buat file 150 byte tanpa header SQLite
        await corruptFile.writeAsBytes(List.filled(150, 0x41));

        final res = await service.validateBackupFile(corruptFile);
        expect(res.isValid, isFalse);
        expect(res.errorMessage, contains('bukan merupakan database SQLite'));
      },
    );

    test(
      '4. validateBackupFile menolak berkas SQLite yang bukan database Labana (tabel tidak lengkap)',
      () async {
        final nonLabanaDbPath = p.join(tempTestDir.path, 'other_app.db');
        final otherDb = await openDatabase(nonLabanaDbPath, version: 1);
        await otherDb.execute(
          'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);',
        );
        await otherDb.close();

        final res = await service.validateBackupFile(File(nonLabanaDbPath));
        expect(res.isValid, isFalse);
        expect(
          res.errorMessage,
          contains('tidak ditemukan pada berkas cadangan'),
        );
      },
    );

    test(
      '5. validateBackupFile menolak berkas database dengan user_version lebih tinggi',
      () async {
        final futureDbPath = p.join(tempTestDir.path, 'future.db');
        final futureDb = await openDatabase(
          futureDbPath,
          version: 99,
          onConfigure: DatabaseHelper.onConfigure,
          onCreate: DatabaseHelper.onCreate,
        );
        await futureDb.close();

        final res = await service.validateBackupFile(File(futureDbPath));
        expect(res.isValid, isFalse);
        expect(
          res.errorMessage,
          contains('lebih baru daripada versi aplikasi ini'),
        );
      },
    );

    test(
      '6. restoreDatabase berhasil mengganti data aktif dengan data dari cadangan',
      () async {
        // 1. Buat database cadangan sekunder dengan data berbeda
        final secondaryDbPath = p.join(tempTestDir.path, 'secondary.db');
        final secondaryDb = await openDatabase(
          secondaryDbPath,
          version: DatabaseConstants.databaseVersion,
          onConfigure: DatabaseHelper.onConfigure,
          onCreate: DatabaseHelper.onCreate,
        );

        // Isi secondary data: 3 bahan, 2 produk, 5 sales
        for (int i = 1; i <= 3; i++) {
          await secondaryDb.insert(TableNames.ingredients, {
            'id': 10 + i,
            'name': 'Bahan Restored $i',
            'status': 'active',
            'created_at': '2026-09-16 12:00:00',
            'updated_at': '2026-09-16 12:00:00',
          });
        }
        for (int i = 1; i <= 2; i++) {
          await secondaryDb.insert(TableNames.products, {
            'id': 20 + i,
            'name': 'Produk Restored $i',
            'status': 'active',
            'created_at': '2026-09-16 12:00:00',
            'updated_at': '2026-09-16 12:00:00',
          });
        }
        await secondaryDb.close();

        bool refreshCalled = false;

        // 2. Jalankan pemulihan database
        await service.restoreDatabase(
          backupFile: File(secondaryDbPath),
          onStateRefresh: () {
            refreshCalled = true;
          },
        );

        expect(refreshCalled, isTrue);

        // 3. Verifikasi data pada koneksi aktif DatabaseHelper
        final activeDb = await DatabaseHelper.instance.database;
        final ingCount = Sqflite.firstIntValue(
          await activeDb.rawQuery(
            'SELECT COUNT(*) FROM ${TableNames.ingredients};',
          ),
        );
        final prodCount = Sqflite.firstIntValue(
          await activeDb.rawQuery(
            'SELECT COUNT(*) FROM ${TableNames.products};',
          ),
        );

        expect(ingCount, 3);
        expect(prodCount, 2);

        // Pastikan data lama (Gula Pasir ID 1) sudah tergantikan
        final oldIng = await activeDb.rawQuery(
          'SELECT * FROM ${TableNames.ingredients} WHERE id = 1;',
        );
        expect(oldIng.isEmpty, isTrue);
      },
    );

    test(
      '7. Rollback Protection: jika restore gagal, database aktif lama TIDAK hilang dan pulih utuh',
      () async {
        // Siapkan berkas cadangan rusak
        final brokenBackup = File(p.join(tempTestDir.path, 'broken_backup.db'));
        await brokenBackup.writeAsString('ini bukan database');

        // Jalankan restore yang dipastikan melempar exception
        expect(
          () async => await service.restoreDatabase(backupFile: brokenBackup),
          throwsA(isA<DatabaseBackupException>()),
        );

        // Verifikasi bahwa database aktif tetap sehat dan data aslinya (Gula Pasir) utuh
        final db = await DatabaseHelper.instance.database;
        final ing = await db.rawQuery(
          'SELECT * FROM ${TableNames.ingredients} WHERE id = 1;',
        );
        expect(ing.isNotEmpty, isTrue);
        expect(ing.first['name'], 'Gula Pasir');
      },
    );
  });
}
