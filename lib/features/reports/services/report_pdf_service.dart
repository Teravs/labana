import 'dart:io';

import '../models/report_models.dart';
import 'pdf_file_storage.dart';
import 'pdf_report_generator.dart';

/// Hasil operasi ekspor laporan PDF.
class PdfExportResult {
  final File file;
  final bool isShared;

  const PdfExportResult({required this.file, required this.isShared});

  String get fileName => file.path.split(Platform.pathSeparator).last;
}

/// Exception domain saat proses pembuatan atau penyimpanan PDF mengalami kendala.
class PdfExportException implements Exception {
  final String message;
  const PdfExportException(this.message);

  @override
  String toString() => message;
}

/// Service orkestrasi pembuatan, penyimpanan, dan pembagian laporan PDF.
class ReportPdfService {
  final PdfReportGenerator _generator;
  final PdfFileStorage _storage;

  const ReportPdfService({
    PdfReportGenerator? generator,
    PdfFileStorage? storage,
  }) : _generator = generator ?? const PdfReportGenerator(),
       _storage = storage ?? const AppPdfFileStorage();

  /// Menghasilkan file PDF dari [ReportData], menyimpannya ke direktori aplikasi,
  /// dan membuka lembar berbagi sistem (*share sheet*).
  Future<PdfExportResult> exportAndShareReport(
    ReportData data, {
    String? subject,
  }) async {
    try {
      // 1. Generate PDF bytes murni
      final bytes = await _generator.generateReportPdf(data);
      if (bytes.isEmpty) {
        throw const PdfExportException('Gagal menghasilkan dokumen PDF (data kosong).');
      }

      // 2. Simpan ke direktori dokumen aplikasi
      final baseName = AppPdfFileStorage.generateBaseFileName(data);
      final savedFile = await _storage.savePdfFile(
        baseName: baseName,
        bytes: bytes,
      );

      // 3. Buka menu bagikan sistem operasi
      final isShared = await _storage.sharePdfFile(
        savedFile.path,
        subject: subject ?? 'Laporan Penjualan Labana - ${data.startDate}',
      );

      return PdfExportResult(file: savedFile, isShared: isShared);
    } on PdfExportException {
      rethrow;
    } catch (e) {
      throw PdfExportException('Gagal membuat laporan PDF: ${e.toString()}');
    }
  }

  /// Hanya mengekspor dan menyimpan file PDF tanpa membuka lembar berbagi.
  Future<File> exportReportOnly(ReportData data) async {
    try {
      final bytes = await _generator.generateReportPdf(data);
      final baseName = AppPdfFileStorage.generateBaseFileName(data);
      return await _storage.savePdfFile(baseName: baseName, bytes: bytes);
    } catch (e) {
      throw PdfExportException('Gagal menyimpan laporan PDF: ${e.toString()}');
    }
  }
}

