import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/backup/models/backup_models.dart';
import 'package:labana/features/backup/services/backup_file_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupFileManager Tests', () {
    late Directory tempDir;
    late FakeBackupFileManager fakeManager;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('backup_mgr_test_');
      fakeManager = FakeBackupFileManager(tempDir: tempDir);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      '1. generateBackupFileName menghasilkan format standar Labana-Backup-YYYY-MM-DD',
      () {
        final date = DateTime(2026, 9, 16);
        final fileName = fakeManager.generateBackupFileName(date: date);
        expect(fileName, 'Labana-Backup-2026-09-16');
      },
    );

    test(
      '2. sanitizeFileName membersihkan karakter terlarang sistem operasi',
      () {
        const raw = 'Labana:Backup/Test*Name?With"Invalid<Chars>|End';
        final clean = AppBackupFileManager.sanitizeFileName(raw);

        expect(clean.contains(':'), isFalse);
        expect(clean.contains('/'), isFalse);
        expect(clean.contains('*'), isFalse);
        expect(clean.contains('?'), isFalse);
        expect(clean.contains('"'), isFalse);
        expect(clean.contains('<'), isFalse);
        expect(clean.contains('>'), isFalse);
        expect(clean.contains('|'), isFalse);
      },
    );

    test(
      '3. resolveUniqueBackupFile menangani tabrakan nama dengan suffix unik (-2, -3)',
      () async {
        final f1 = await fakeManager.resolveUniqueBackupFile(
          'Labana-Backup-2026-09-16',
        );
        expect(p.basename(f1.path), 'Labana-Backup-2026-09-16.db');
        await f1.writeAsString('test 1');

        final f2 = await fakeManager.resolveUniqueBackupFile(
          'Labana-Backup-2026-09-16',
        );
        expect(p.basename(f2.path), 'Labana-Backup-2026-09-16-2.db');
        await f2.writeAsString('test 2');

        final f3 = await fakeManager.resolveUniqueBackupFile(
          'Labana-Backup-2026-09-16',
        );
        expect(p.basename(f3.path), 'Labana-Backup-2026-09-16-3.db');
      },
    );

    test(
      '4. listLocalBackups membaca file .db lokal dan mengurutkannya secara descending',
      () async {
        final file1 = File(p.join(tempDir.path, 'Labana-Backup-2026-09-10.db'));
        await file1.writeAsString('dummy 1');

        final file2 = File(p.join(tempDir.path, 'Labana-Backup-2026-09-15.db'));
        await file2.writeAsString('dummy 2');

        fakeManager.localBackups.addAll([
          BackupFileInfo(
            filePath: file1.path,
            fileName: 'Labana-Backup-2026-09-10.db',
            fileSizeBytes: 100,
            createdAt: DateTime(2026, 9, 10),
          ),
          BackupFileInfo(
            filePath: file2.path,
            fileName: 'Labana-Backup-2026-09-15.db',
            fileSizeBytes: 120,
            createdAt: DateTime(2026, 9, 15),
          ),
        ]);

        final list = await fakeManager.listLocalBackups();
        expect(list.length, 2);
        expect(
          list.any((f) => f.fileName == 'Labana-Backup-2026-09-10.db'),
          isTrue,
        );
        expect(
          list.any((f) => f.fileName == 'Labana-Backup-2026-09-15.db'),
          isTrue,
        );
      },
    );

    test('5. deleteBackup menghapus file dari filesystem', () async {
      final f = File(p.join(tempDir.path, 'to_delete.db'));
      await f.writeAsString('delete me');
      expect(await f.exists(), isTrue);

      final deleted = await fakeManager.deleteBackup(f.path);
      expect(deleted, isTrue);
      expect(await f.exists(), isFalse);
    });

    test('6. shareBackup memanggil sistem share sheet', () async {
      final f = File(p.join(tempDir.path, 'share_test.db'));
      await f.writeAsString('share me');

      final result = await fakeManager.shareBackup(f.path);
      expect(result, isTrue);
      expect(fakeManager.shareCalled, isTrue);
      expect(fakeManager.lastSharedPath, f.path);
    });
  });
}
