import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/report_models.dart';

/// Kontrak abstraksi penyimpanan dan pembagian file PDF laporan.
abstract class PdfFileStorage {
  /// Menyimpan bytes PDF ke filesystem lokal dengan nama file yang aman dan bebas tabrakan.
  Future<File> savePdfFile({
    required String baseName,
    required Uint8List bytes,
  });

  /// Membuka lembar berbagi sistem (*system share sheet*) untuk membagikan file PDF.
  Future<bool> sharePdfFile(String filePath, {String? subject});
}

/// Implementasi produksi penyimpanan PDF dan pembagian file via [path_provider] dan [share_plus].
///
/// Menggunakan [getApplicationDocumentsDirectory] sebagai lokasi utama penyimpanan agar file
/// laporan tersimpan aman di direktori aplikasi pengguna.
class AppPdfFileStorage implements PdfFileStorage {
  const AppPdfFileStorage();

  @override
  Future<File> savePdfFile({
    required String baseName,
    required Uint8List bytes,
  }) async {
    final sanitizedBase = sanitizeFileName(baseName);
    final directory = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(directory.path, 'reports'));

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Resolusi nama unik jika file sudah ada (Laporan-Labana.pdf -> Laporan-Labana-2.pdf)
    var finalPath = p.join(targetDir.path, '$sanitizedBase.pdf');
    var file = File(finalPath);
    var counter = 2;

    while (await file.exists()) {
      finalPath = p.join(targetDir.path, '$sanitizedBase-$counter.pdf');
      file = File(finalPath);
      counter++;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<bool> sharePdfFile(String filePath, {String? subject}) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final xFile = XFile(filePath, mimeType: 'application/pdf');
    final result = await Share.shareXFiles(
      [xFile],
      subject: subject ?? 'Laporan Penjualan Labana',
    );

    // Pada Android/iOS Share.shareXFiles mengembalikan status ShareResult
    return result.status != ShareResultStatus.unavailable;
  }

  /// Membersihkan nama file dari karakter terlarang sistem operasi.
  static String sanitizeFileName(String name) {
    // Larang: / \ : * ? " < > |
    final invalidChars = RegExp(r'[\\/:*?"<>|]');
    var clean = name.replaceAll(invalidChars, '-');
    // Hilangkan spasi ganda atau karakter titik di awal/akhir
    clean = clean.replaceAll(RegExp(r'\s+'), '-');
    clean = clean.replaceAll(RegExp(r'-+'), '-');
    clean = clean.trim();
    if (clean.isEmpty) clean = 'Laporan-Labana';
    return clean;
  }

  /// Menghasilkan nama file dasar yang representatif sesuai [ReportData].
  static String generateBaseFileName(ReportData data) {
    switch (data.periodType) {
      case ReportPeriodType.daily:
        return 'Laporan-Labana-${data.startDate}';
      case ReportPeriodType.weekly:
        return 'Laporan-Labana-Mingguan-${data.startDate}-sd-${data.endDate}';
      case ReportPeriodType.monthly:
        final monthStr =
            data.startDate.length >= 7
                ? data.startDate.substring(0, 7)
                : data.startDate;
        return 'Laporan-Labana-Bulanan-$monthStr';
    }
  }
}

/// Implementasi tiruan (*fake*) penyimpanan PDF untuk widget test dan unit test.
///
/// Berjalan cepat di memori tanpa bergantung pada plugin native OS Android/iOS.
class FakePdfFileStorage implements PdfFileStorage {
  final Map<String, Uint8List> storedFiles = {};
  final List<String> sharedFiles = [];
  bool simulateSaveError = false;
  bool simulateShareError = false;

  @override
  Future<File> savePdfFile({
    required String baseName,
    required Uint8List bytes,
  }) async {
    if (simulateSaveError) {
      throw const FileSystemException('Simulated disk error during save');
    }
    final sanitized = AppPdfFileStorage.sanitizeFileName(baseName);
    var finalName = '$sanitized.pdf';
    var counter = 2;
    while (storedFiles.containsKey(finalName)) {
      finalName = '$sanitized-$counter.pdf';
      counter++;
    }

    storedFiles[finalName] = bytes;
    // Kembalikan File dummy path
    return File('/fake/documents/reports/$finalName');
  }

  @override
  Future<bool> sharePdfFile(String filePath, {String? subject}) async {
    if (simulateShareError) return false;
    sharedFiles.add(filePath);
    return true;
  }
}

