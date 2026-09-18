import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/backup/presentation/screens/backup_restore_screen.dart';
import 'package:labana/features/backup/services/backup_file_manager.dart';
import 'package:labana/features/backup/services/database_backup_service.dart';
import 'package:labana/features/backup/services/external_file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String activeDbPath;
  late FakeBackupFileManager fakeFileManager;
  late FakeExternalFilePicker fakeFilePicker;
  late DatabaseBackupService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('screen_backup_test_');
    activeDbPath = p.join(tempDir.path, DatabaseConstants.databaseName);

    final db = await openDatabase(
      activeDbPath,
      version: DatabaseConstants.databaseVersion,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
    );
    DatabaseHelper.instance.setTestDatabase(db);

    fakeFileManager = FakeBackupFileManager(
      tempDir: Directory(p.join(tempDir.path, 'backups')),
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
    DatabaseHelper.instance.setTestDatabase(null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper untuk melepas FakeAsync ke event loop nyata secara terukur
  /// hanya ketika menunggu operasi I/O / SQLite asynchronous selesai.
  Future<void> settleAsync(
    WidgetTester tester, {
    bool Function()? condition,
    int maxSteps = 20,
  }) async {
    for (var i = 0; i < maxSteps; i++) {
      await tester.pump();
      if (condition != null && condition()) {
        return;
      }
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump();
  }

  Widget createWidgetUnderTest() {
    return MaterialApp(home: BackupRestoreScreen(backupService: service));
  }

  group('BackupRestoreScreen Widget Tests', () {
    testWidgets('1. Menampilkan empty state saat belum ada cadangan lokal', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Backup & Restore Data'), findsOneWidget);
      expect(find.text('Cadangkan Sekarang'), findsOneWidget);
      expect(find.text('Pilih Berkas Cadangan (.db)'), findsOneWidget);
      expect(find.text('Belum Ada Cadangan'), findsOneWidget);
    });

    testWidgets(
      '2. Menekan Cadangkan Sekarang membuat cadangan baru dan memperbarui UI',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        // Tekan tombol Cadangkan Sekarang
        await tester.tap(find.text('Cadangkan Sekarang'));
        await settleAsync(
          tester,
          condition: () =>
              find.byIcon(Icons.storage_rounded).evaluate().isNotEmpty,
        );

        // Berkas cadangan terbuat di file manager
        expect(find.text('Belum Ada Cadangan'), findsNothing);
        expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
      },
    );

    testWidgets(
      '3. External file picker batal tidak memunculkan modal apa pun',
      (tester) async {
        fakeFilePicker.fileToReturn = null;

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Pilih Berkas Cadangan (.db)'));
        await settleAsync(tester, condition: () => fakeFilePicker.wasCalled);

        expect(fakeFilePicker.wasCalled, isTrue);
        expect(find.text('Konfirmasi Pemulihan Database'), findsNothing);
      },
    );

    testWidgets(
      '4. External file picker invalid menampilkan dialog Berkas Tidak Valid',
      (tester) async {
        final invalidFile = File(p.join(tempDir.path, 'invalid.db'));
        invalidFile.writeAsStringSync('not a sqlite file');
        fakeFilePicker.fileToReturn = invalidFile;

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Pilih Berkas Cadangan (.db)'));
        await settleAsync(
          tester,
          condition: () =>
              find.text('Berkas Tidak Valid').evaluate().isNotEmpty,
        );

        expect(find.text('Berkas Tidak Valid'), findsOneWidget);

        // Tutup dialog
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        expect(find.text('Berkas Tidak Valid'), findsNothing);
      },
    );

    testWidgets(
      '5. Memilih cadangan valid menampilkan rincian data dan dialog konfirmasi',
      (tester) async {
        // Buat backup valid terlebih dahulu via runAsync
        final backup = await tester.runAsync(
          () => service.createBackup(customName: 'Backup-Valid'),
        );
        fakeFilePicker.fileToReturn = backup;

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Pilih Berkas Cadangan (.db)'));
        await settleAsync(
          tester,
          condition: () =>
              find.text('Konfirmasi Pemulihan Database').evaluate().isNotEmpty,
        );

        // Konfirmasi dialog muncul
        expect(find.text('Konfirmasi Pemulihan Database'), findsOneWidget);
        expect(
          find.text(
            'PERINGATAN: Memulihkan database akan menggantikan seluruh data aktif saat ini dengan data dari cadangan ini.',
          ),
          findsOneWidget,
        );
        expect(find.text('Total Transaksi'), findsOneWidget);
        expect(find.text('Produk Menu'), findsOneWidget);
        expect(find.text('Bahan Mentah'), findsOneWidget);

        // Batalkan
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(find.text('Konfirmasi Pemulihan Database'), findsNothing);
      },
    );

    testWidgets(
      '6. Menyetujui konfirmasi restore memulihkan database dan memunculkan dialog sukses',
      (tester) async {
        final backup = await tester.runAsync(
          () => service.createBackup(customName: 'Backup-Restore-Test'),
        );
        fakeFilePicker.fileToReturn = backup;

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        await tester.tap(find.text('Pilih Berkas Cadangan (.db)'));
        await settleAsync(
          tester,
          condition: () =>
              find.text('Konfirmasi Pemulihan Database').evaluate().isNotEmpty,
        );

        expect(find.text('Konfirmasi Pemulihan Database'), findsOneWidget);

        // Tekan Pulihkan Database
        await tester.tap(find.text('Pulihkan Database'));
        await settleAsync(
          tester,
          condition: () =>
              find.text('Pemulihan Berhasil!').evaluate().isNotEmpty,
          maxSteps: 40,
        );

        expect(find.text('Pemulihan Berhasil!'), findsOneWidget);

        // Tutup dialog sukses
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Pemulihan Berhasil!'), findsNothing);
      },
    );

    testWidgets(
      '7. Menekan tombol download mengunduh berkas ke folder Download dan memunculkan notifikasi',
      (tester) async {
        // Buat backup valid terlebih dahulu
        await tester.runAsync(
          () => service.createBackup(customName: 'Backup-To-Download'),
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

        // Tekan tombol download
        await tester.tap(find.byIcon(Icons.file_download_outlined));
        await settleAsync(
          tester,
          condition: () => find
              .textContaining('berhasil diunduh ke folder Download')
              .evaluate()
              .isNotEmpty,
        );

        expect(fakeFileManager.downloadCalled, isTrue);
        expect(
          find.textContaining('berhasil diunduh ke folder Download'),
          findsOneWidget,
        );
      },
    );
  });
}
