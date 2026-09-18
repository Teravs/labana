import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../backup/services/backup_file_manager.dart';
import '../../backup/services/database_backup_service.dart';
import '../../reports/data/report_repository.dart';
import '../../reports/models/report_models.dart';
import '../../reports/services/report_date_helper.dart';
import '../../reports/services/report_pdf_service.dart';
import '../../sales/data/sale_repository.dart';
import '../models/retention_models.dart';

/// Layanan orkestrasi retensi data transaksi bulanan.
///
/// **Prinsip Keamanan & Integritas**:
/// 1. Granular Monthly Retention: Pembersihan dilakukan manual per bulan.
/// 2. Active Month Shield: Bulan berjalan yang sedang aktif tidak dapat dihapus.
/// 3. Download Guard: Transaksi bulan terkait hanya dapat dihapus jika laporan PDF sudah diunduh.
/// 4. Zero Master Data Deletion: HANYA tabel `sales` & `sale_items` yang dihapus. Seluruh
///    master data (Bahan Mentah, Olahan, Resep, Produk, Harga) tetap 100% utuh.
/// 5. Auto Safety Snapshot: Sebelum penghapusan, cadangan lokal dibuat otomatis.
class DataRetentionService {
  final DatabaseHelper _dbHelper;
  final ReportRepository _reportRepository;
  final ReportPdfService _pdfService;
  final BackupFileManager _fileManager;
  final DatabaseBackupService _backupService;

  DataRetentionService({
    DatabaseHelper? dbHelper,
    ReportRepository? reportRepository,
    ReportPdfService? pdfService,
    BackupFileManager? fileManager,
    DatabaseBackupService? backupService,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _reportRepository =
            reportRepository ?? ReportRepository(dbHelper: dbHelper),
        _pdfService = pdfService ?? ReportPdfService(),
        _fileManager = fileManager ?? const AppBackupFileManager(),
        _backupService = backupService ??
            DatabaseBackupService(
              dbHelper: dbHelper,
              fileManager: fileManager,
            );

  BackupFileManager get fileManager => _fileManager;
  DatabaseBackupService get backupService => _backupService;

  /// Mengambil daftar ringkasan arsip transaksi per bulan dari database.
  ///
  /// Diurutkan dari bulan terbaru ke bulan terlama (`year DESC, month DESC`).
  Future<List<MonthlyArchiveItem>> getMonthlyArchives({DateTime? now}) async {
    final currentDt = now ?? DateTime.now();
    final db = await _dbHelper.database;

    final results = await db.rawQuery('''
      SELECT 
        CAST(substr(transaction_date, 1, 4) AS INTEGER) AS year,
        CAST(substr(transaction_date, 6, 2) AS INTEGER) AS month,
        COUNT(id) AS transaction_count,
        COALESCE(SUM(total_amount), 0) AS total_omzet
      FROM ${TableNames.sales}
      WHERE length(transaction_date) >= 7
      GROUP BY year, month
      ORDER BY year DESC, month DESC
    ''');

    final archives = await db.query(
      TableNames.reportArchives,
      columns: ['period_start', 'file_path'],
      where: "report_type = 'monthly'",
    );

    final downloadedMap = <String, String>{};
    for (final a in archives) {
      final periodStart = a['period_start'] as String?;
      final filePath = a['file_path'] as String?;
      if (periodStart != null && periodStart.length >= 7 && filePath != null) {
        final key = periodStart.substring(0, 7);
        downloadedMap[key] = filePath;
      }
    }

    return results.map((row) {
      final year = (row['year'] as num).toInt();
      final month = (row['month'] as num).toInt();
      final count = (row['transaction_count'] as num).toInt();
      final omzet = (row['total_omzet'] as num).toDouble();
      final periodKey = '$year-${month.toString().padLeft(2, '0')}';
      final isCurrent = (year == currentDt.year && month == currentDt.month);
      final monthName = (month >= 1 && month <= 12)
          ? ReportDateHelper.monthNamesFull[month - 1]
          : 'Bulan $month';
      final label = '$monthName $year';
      final downloadedPath = downloadedMap[periodKey];

      return MonthlyArchiveItem(
        year: year,
        month: month,
        monthLabel: label,
        transactionCount: count,
        totalOmzet: omzet,
        isCurrentMonth: isCurrent,
        isDownloaded: downloadedPath != null,
        downloadedFilePath: downloadedPath,
      );
    }).toList();
  }

  /// Mengecek apakah laporan bulanan untuk [year] dan [month] sudah pernah diunduh/diekspor.
  Future<bool> isMonthReportDownloaded(int year, int month) async {
    final periodKey = '$year-${month.toString().padLeft(2, '0')}';
    final db = await _dbHelper.database;
    final results = await db.query(
      TableNames.reportArchives,
      columns: ['id'],
      where: "report_type = 'monthly' AND substr(period_start, 1, 7) = ?",
      whereArgs: [periodKey],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Menghasilkan file PDF laporan penjualan bulanan, menyimpannya ke folder Download / berkas,
  /// dan mencatatnya ke dalam tabel `report_archives`.
  Future<File> downloadMonthlyReport({
    required int year,
    required int month,
    bool saveToPublicDownloads = true,
  }) async {
    final refDate = DateTime(year, month, 1);
    final reportData = await _reportRepository.getReportData(
      periodType: ReportPeriodType.monthly,
      referenceDate: refDate,
    );

    // 1. Export file PDF
    final exportedFile = await _pdfService.exportReportOnly(reportData);

    // 2. Salin / unduh ke folder Download publik jika diaktifkan
    File finalFile = exportedFile;
    if (saveToPublicDownloads) {
      try {
        final downloadedPath = await savePdfToDownloads(exportedFile);
        if (downloadedPath != null && downloadedPath.isNotEmpty) {
          finalFile = File(downloadedPath);
        }
      } catch (_) {
        // Fallback tetap menggunakan exportedFile jika folder publik tidak dapat diakses
      }
    }

    // 3. Catat ke tabel report_archives
    final range = ReportDateHelper.getMonthRange(year, month);
    final startDate = ReportDateHelper.formatDate(range.start);
    final endDate = ReportDateHelper.formatDate(range.end);
    final fileName = p.basename(finalFile.path);

    final db = await _dbHelper.database;
    await db.insert(TableNames.reportArchives, {
      'report_type': 'monthly',
      'period_start': startDate,
      'period_end': endDate,
      'file_name': fileName,
      'file_path': finalFile.path,
      'created_at': DateTime.now().toIso8601String(),
    });

    return finalFile;
  }

  /// Menyimpan berkas PDF ke folder Download publik perangkat.
  Future<String?> savePdfToDownloads(File sourceFile) async {
    return await _fileManager.downloadBackupToDownloads(sourceFile.path);
  }

  /// Menghapus seluruh transaksi penjualan (`sales` & `sale_items`) pada bulan dan tahun target.
  ///
  /// **Proteksi Mutlak**:
  /// - Menolak jika [year] dan [month] adalah bulan berjalan yang sedang aktif.
  /// - Menolak jika laporan bulanan belum diunduh.
  /// - Membuat cadangan pengaman pra-retensi otomatis.
  /// - HANYA menghapus dari `sale_items` dan `sales`. Seluruh master data resep, bahan,
  ///   dan produk DIJAMIN TETAP UTUH.
  /// - Menjalankan VACUUM untuk mengklaim ruang penyimpanan disk.
  Future<int> deleteMonthlyTransactions({
    required int year,
    required int month,
    bool createSafetyBackup = true,
    DateTime? now,
  }) async {
    final currentDt = now ?? DateTime.now();
    if (year == currentDt.year && month == currentDt.month) {
      throw const RetentionException(
        'Bulan berjalan yang sedang aktif dilindungi dan tidak dapat dihapus.',
      );
    }

    final periodKey = '$year-${month.toString().padLeft(2, '0')}';
    final isDownloaded = await isMonthReportDownloaded(year, month);
    if (!isDownloaded) {
      throw RetentionException(
        'Laporan bulanan periode $periodKey belum diunduh. '
        'Unduh laporan terlebih dahulu sebelum melakukan pembersihan.',
      );
    }

    // 1. Cadangan Pengaman Otomatis Pra-Retensi
    if (createSafetyBackup) {
      try {
        await _backupService.createBackup(
          customName: 'Labana-PreRetention-$periodKey',
        );
      } catch (e) {
        throw RetentionException(
          'Gagal membuat cadangan pengaman pra-retensi: $e. Pembersihan dibatalkan.',
        );
      }
    }

    // 2. Penghapusan Atomik Hanya pada Tabel Penjualan
    final db = await _dbHelper.database;
    int deletedSalesCount = 0;

    await db.transaction((txn) async {
      // Hapus seluruh sale_items yang terasosiasi dengan sales bulan ini
      await txn.rawDelete('''
        DELETE FROM ${TableNames.saleItems}
        WHERE sale_id IN (
          SELECT id FROM ${TableNames.sales}
          WHERE substr(transaction_date, 1, 7) = ?
        )
      ''', [periodKey]);

      // Hapus data sales bulan ini
      deletedSalesCount = await txn.rawDelete('''
        DELETE FROM ${TableNames.sales}
        WHERE substr(transaction_date, 1, 7) = ?
      ''', [periodKey]);
    });

    // 3. Reklamasi Ruang Penyimpanan Disk (VACUUM)
    try {
      await _dbHelper.checkpoint();
      await db.execute('VACUUM;');
    } catch (_) {
      // Abaikan jika pada database in-memory unit test
    }

    // 4. Beri tahu seluruh modul aplikasi bahwa data penjualan telah berubah
    SaleRepository.salesChangeNotifier.value++;

    return deletedSalesCount;
  }
}

