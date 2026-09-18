import 'dart:io';
import 'dart:typed_data';

import '../../settings/data/app_settings_repository.dart';
import '../../settings/models/business_profile.dart';
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
  final AppSettingsRepository _settingsRepo;

  ReportPdfService({
    PdfReportGenerator? generator,
    PdfFileStorage? storage,
    AppSettingsRepository? settingsRepo,
  }) : _generator = generator ?? const PdfReportGenerator(),
       _storage = storage ?? const AppPdfFileStorage(),
       _settingsRepo = settingsRepo ?? AppSettingsRepository();

  Future<({BusinessProfile profile, Uint8List? logoBytes})> _resolveBranding() async {
    try {
      final profile = await _settingsRepo.getBusinessProfile();
      Uint8List? logoBytes;
      if (profile.hasCustomLogo && profile.logoPath != null) {
        final file = File(profile.logoPath!);
        if (await file.exists()) {
          logoBytes = await file.readAsBytes();
        }
      }
      return (profile: profile, logoBytes: logoBytes);
    } catch (_) {
      return (profile: const BusinessProfile(), logoBytes: null);
    }
  }

  /// Menghasilkan file PDF dari [ReportData], menyimpannya ke direktori aplikasi,
  /// dan membuka lembar berbagi sistem (*share sheet*).
  Future<PdfExportResult> exportAndShareReport(
    ReportData data, {
    String? subject,
  }) async {
    try {
      final branding = await _resolveBranding();

      // 1. Generate PDF bytes murni
      final bytes = await _generator.generateReportPdf(
        data,
        profile: branding.profile,
        logoBytes: branding.logoBytes,
      );
      if (bytes.isEmpty) {
        throw const PdfExportException(
          'Gagal menghasilkan dokumen PDF (data kosong).',
        );
      }

      // 2. Simpan ke direktori dokumen aplikasi
      final baseName = AppPdfFileStorage.generateBaseFileName(data);
      final savedFile = await _storage.savePdfFile(
        baseName: baseName,
        bytes: bytes,
      );

      // 3. Buka menu bagikan sistem operasi
      final bName = branding.profile.name.isNotEmpty ? branding.profile.name : 'Labana';
      final isShared = await _storage.sharePdfFile(
        savedFile.path,
        subject: subject ?? 'Laporan Penjualan $bName - ${data.startDate}',
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
      final branding = await _resolveBranding();
      final bytes = await _generator.generateReportPdf(
        data,
        profile: branding.profile,
        logoBytes: branding.logoBytes,
      );
      final baseName = AppPdfFileStorage.generateBaseFileName(data);
      return await _storage.savePdfFile(baseName: baseName, bytes: bytes);
    } catch (e) {
      throw PdfExportException('Gagal menyimpan laporan PDF: ${e.toString()}');
    }
  }
}
