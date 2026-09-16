import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/backup/services/external_file_picker.dart';

void main() {
  group('ExternalFilePicker Tests', () {
    test(
      '1. Pengguna membatalkan picker menghasilkan null tanpa error',
      () async {
        final picker = FakeExternalFilePicker(fileToReturn: null);

        final result = await picker.pickDatabaseFile();
        expect(result, isNull);
        expect(picker.wasCalled, isTrue);
      },
    );

    test(
      '2. Pengguna memilih file .db eksternal mengembalikan File yang dituju',
      () async {
        final tempFile = File(
          '${Directory.systemTemp.path}/test_external_backup.db',
        );
        await tempFile.writeAsString('SQLite test');

        try {
          final picker = FakeExternalFilePicker(fileToReturn: tempFile);
          final result = await picker.pickDatabaseFile();

          expect(result, isNotNull);
          expect(result!.path, tempFile.path);
          expect(picker.wasCalled, isTrue);
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      },
    );
  });
}
