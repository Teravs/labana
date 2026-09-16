import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/reports/models/report_models.dart';
import 'package:labana/features/reports/services/pdf_file_storage.dart';
import 'package:labana/features/reports/services/report_pdf_service.dart';

void main() {
  group('PdfFileStorage & Filename Sanitization Tests', () {
    test(
      'generateBaseFileName menghasilkan format nama yang sesuai periode',
      () {
        final daily = ReportData.empty(
          periodType: ReportPeriodType.daily,
          startDate: '2026-09-15',
          endDate: '2026-09-15',
        );
        expect(
          AppPdfFileStorage.generateBaseFileName(daily),
          'Laporan-Labana-2026-09-15',
        );

        final weekly = ReportData.empty(
          periodType: ReportPeriodType.weekly,
          startDate: '2026-09-14',
          endDate: '2026-09-20',
        );
        expect(
          AppPdfFileStorage.generateBaseFileName(weekly),
          'Laporan-Labana-Mingguan-2026-09-14-sd-2026-09-20',
        );

        final monthly = ReportData.empty(
          periodType: ReportPeriodType.monthly,
          startDate: '2026-09-01',
          endDate: '2026-09-30',
        );
        expect(
          AppPdfFileStorage.generateBaseFileName(monthly),
          'Laporan-Labana-Bulanan-2026-09',
        );
      },
    );

    test('sanitizeFileName membersihkan karakter terlarang filesystem', () {
      const unsafe = 'Laporan/Labana:Periode*2026?Test"1<2>3|File';
      final clean = AppPdfFileStorage.sanitizeFileName(unsafe);

      expect(clean.contains('/'), isFalse);
      expect(clean.contains('\\'), isFalse);
      expect(clean.contains(':'), isFalse);
      expect(clean.contains('*'), isFalse);
      expect(clean.contains('?'), isFalse);
      expect(clean.contains('"'), isFalse);
      expect(clean.contains('<'), isFalse);
      expect(clean.contains('>'), isFalse);
      expect(clean.contains('|'), isFalse);
    });

    test(
      'Collision handling: file dengan nama sama menghasilkan suffix unik (-2, -3)',
      () async {
        final storage = FakePdfFileStorage();

        final f1 = await storage.savePdfFile(
          baseName: 'Laporan-Labana-2026-09-15',
          bytes: Uint8List.fromList([1, 2, 3]),
        );
        expect(f1.path, endsWith('Laporan-Labana-2026-09-15.pdf'));

        final f2 = await storage.savePdfFile(
          baseName: 'Laporan-Labana-2026-09-15',
          bytes: Uint8List.fromList([4, 5, 6]),
        );
        expect(f2.path, endsWith('Laporan-Labana-2026-09-15-2.pdf'));

        final f3 = await storage.savePdfFile(
          baseName: 'Laporan-Labana-2026-09-15',
          bytes: Uint8List.fromList([7, 8, 9]),
        );
        expect(f3.path, endsWith('Laporan-Labana-2026-09-15-3.pdf'));
      },
    );
  });

  group('ReportPdfService Tests', () {
    late FakePdfFileStorage fakeStorage;
    late ReportPdfService service;

    setUp(() {
      fakeStorage = FakePdfFileStorage();
      service = ReportPdfService(storage: fakeStorage);
    });

    test(
      'exportAndShareReport berhasil mengorkestrasi generate, save, dan share',
      () async {
        final sampleData = ReportData.empty(
          periodType: ReportPeriodType.daily,
          startDate: '2026-09-16',
          endDate: '2026-09-16',
        );

        final result = await service.exportAndShareReport(sampleData);

        expect(result.file.path, contains('Laporan-Labana-2026-09-16.pdf'));
        expect(result.isShared, isTrue);
        expect(fakeStorage.storedFiles.length, 1);
        expect(fakeStorage.sharedFiles.length, 1);
      },
    );

    test(
      'exportAndShareReport melempar PdfExportException saat disk error disimulasikan',
      () async {
        fakeStorage.simulateSaveError = true;

        final sampleData = ReportData.empty(
          periodType: ReportPeriodType.daily,
          startDate: '2026-09-16',
          endDate: '2026-09-16',
        );

        expect(
          () async => await service.exportAndShareReport(sampleData),
          throwsA(isA<PdfExportException>()),
        );
      },
    );

    test('exportReportOnly menyimpan file tanpa memicu share sheet', () async {
      final sampleData = ReportData.empty(
        periodType: ReportPeriodType.daily,
        startDate: '2026-09-16',
        endDate: '2026-09-16',
      );

      final file = await service.exportReportOnly(sampleData);

      expect(file.path, contains('Laporan-Labana-2026-09-16.pdf'));
      expect(fakeStorage.storedFiles.length, 1);
      expect(fakeStorage.sharedFiles, isEmpty);
    });
  });
}
