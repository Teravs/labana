import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/report_models.dart';
import '../services/report_date_helper.dart';

/// Repository untuk kueri dan agregasi data laporan penjualan (Harian, Mingguan, Bulanan).
///
/// **Prinsip Utama Data**:
/// - Menggunakan snapshot transaksi dari tabel `sales` dan `sale_items`.
/// - Tidak pernah menghitung ulang formula HPP atau harga master terkini.
/// - Tidak ada modul inventori / stok tracking.
class ReportRepository {
  final DatabaseHelper _dbHelper;

  ReportRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Mengambil ringkasan data laporan finansial (omzet, hpp, profit, jumlah transaksi, produk terjual)
  /// untuk rentang tanggal [startDate] s/d [endDate] (`YYYY-MM-DD`).
  Future<ReportSummary> getReportSummary(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(s.total_amount), 0) AS total_omzet,
        COALESCE(SUM(s.total_hpp), 0) AS total_hpp,
        COALESCE(SUM(s.total_profit), 0) AS total_profit,
        COUNT(s.id) AS transaction_count,
        COALESCE((
          SELECT SUM(si.quantity)
          FROM ${TableNames.saleItems} si
          INNER JOIN ${TableNames.sales} s2 ON si.sale_id = s2.id
          WHERE substr(s2.transaction_date, 1, 10) >= ?
            AND substr(s2.transaction_date, 1, 10) <= ?
        ), 0.0) AS products_sold
      FROM ${TableNames.sales} s
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
    ''',
      [startDate, endDate, startDate, endDate],
    );

    if (results.isEmpty) {
      return const ReportSummary();
    }

    return ReportSummary.fromMap(results.first);
  }

  /// Mengambil daftar breakdown seluruh produk yang terjual dalam periode [startDate] s/d [endDate].
  ///
  /// Diurutkan secara deterministik berdasarkan kuantitas terbanyak:
  /// `ORDER BY total_quantity DESC, si.product_id ASC`.
  Future<List<ReportProductStat>> getProductBreakdown(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        si.product_id,
        MAX(si.product_name) AS product_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.subtotal) AS total_omzet,
        SUM(si.total_hpp) AS total_hpp,
        SUM(si.total_profit) AS total_profit
      FROM ${TableNames.saleItems} si
      INNER JOIN ${TableNames.sales} s ON si.sale_id = s.id
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
      GROUP BY si.product_id
      ORDER BY total_quantity DESC, si.product_id ASC
    ''',
      [startDate, endDate],
    );

    return results.map((row) => ReportProductStat.fromMap(row)).toList();
  }

  /// Mengambil satu produk terlaris berdasarkan kuantitas terjual dengan tie-breaker deterministik.
  Future<ReportProductStat?> getTopSellingProduct(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        si.product_id,
        MAX(si.product_name) AS product_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.subtotal) AS total_omzet,
        SUM(si.total_hpp) AS total_hpp,
        SUM(si.total_profit) AS total_profit
      FROM ${TableNames.saleItems} si
      INNER JOIN ${TableNames.sales} s ON si.sale_id = s.id
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
      GROUP BY si.product_id
      ORDER BY total_quantity DESC, si.product_id ASC
      LIMIT 1
    ''',
      [startDate, endDate],
    );

    if (results.isEmpty) return null;
    return ReportProductStat.fromMap(results.first);
  }

  /// Mengambil satu produk dengan total laba tertinggi dengan tie-breaker deterministik.
  Future<ReportProductStat?> getHighestProfitProduct(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        si.product_id,
        MAX(si.product_name) AS product_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.subtotal) AS total_omzet,
        SUM(si.total_hpp) AS total_hpp,
        SUM(si.total_profit) AS total_profit
      FROM ${TableNames.saleItems} si
      INNER JOIN ${TableNames.sales} s ON si.sale_id = s.id
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
      GROUP BY si.product_id
      ORDER BY total_profit DESC, si.product_id ASC
      LIMIT 1
    ''',
      [startDate, endDate],
    );

    if (results.isEmpty) return null;
    return ReportProductStat.fromMap(results.first);
  }

  /// Mengambil agregasi performa per hari dalam rentang [startDate] s/d [endDate].
  ///
  /// **Timeline Lengkap**:
  /// Mengisi seluruh tanggal dalam rentang kalender sehingga hari tanpa transaksi
  /// tetap ditampilkan sebagai `Rp0` tanpa menghilangkan tanggal tersebut dari urutan.
  Future<List<DailyReportStat>> getDailyBreakdown(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        substr(s.transaction_date, 1, 10) AS date_str,
        COALESCE(SUM(s.total_amount), 0) AS total_omzet,
        COALESCE(SUM(s.total_hpp), 0) AS total_hpp,
        COALESCE(SUM(s.total_profit), 0) AS total_profit,
        COUNT(s.id) AS transaction_count,
        COALESCE((
          SELECT SUM(si.quantity)
          FROM ${TableNames.saleItems} si
          INNER JOIN ${TableNames.sales} s2 ON si.sale_id = s2.id
          WHERE substr(s2.transaction_date, 1, 10) = substr(s.transaction_date, 1, 10)
        ), 0.0) AS products_sold
      FROM ${TableNames.sales} s
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
      GROUP BY substr(s.transaction_date, 1, 10)
      ORDER BY date_str ASC
    ''',
      [startDate, endDate],
    );

    final mapByDate = <String, DailyReportStat>{};
    for (final row in results) {
      final stat = DailyReportStat.fromMap(row);
      if (stat.dateStr.isNotEmpty) {
        mapByDate[stat.dateStr] = stat;
      }
    }

    // Bangun daftar tanggal lengkap tanpa jeda
    final startDt = ReportDateHelper.parseDate(startDate);
    final endDt = ReportDateHelper.parseDate(endDate);
    final allDays = ReportDateHelper.getDaysInRange(startDt, endDt);

    final completeTimeline = <DailyReportStat>[];
    for (final day in allDays) {
      final dayStr = ReportDateHelper.formatDate(day);
      if (mapByDate.containsKey(dayStr)) {
        completeTimeline.add(mapByDate[dayStr]!);
      } else {
        completeTimeline.add(DailyReportStat(dateStr: dayStr));
      }
    }

    return completeTimeline;
  }

  /// Mengambil breakdown transaksi berdasarkan metode pembayaran (Tunai, QRIS, Transfer).
  Future<List<PaymentMethodStat>> getPaymentMethodBreakdown(
    String startDate,
    String endDate, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        s.payment_method,
        COUNT(s.id) AS transaction_count,
        COALESCE(SUM(s.total_amount), 0) AS total_amount
      FROM ${TableNames.sales} s
      WHERE substr(s.transaction_date, 1, 10) >= ?
        AND substr(s.transaction_date, 1, 10) <= ?
      GROUP BY s.payment_method
      ORDER BY total_amount DESC
    ''',
      [startDate, endDate],
    );

    return results.map((row) => PaymentMethodStat.fromMap(row)).toList();
  }

  /// Facade untuk memuat seluruh payload data laporan untuk periode yang dipilih
  /// secara paralel menggunakan `Future.wait`.
  Future<ReportData> getReportData({
    required ReportPeriodType periodType,
    required DateTime referenceDate,
    DatabaseExecutor? executor,
  }) async {
    final range = ReportDateHelper.getPeriodRangeStrings(
      periodType,
      referenceDate,
    );
    final startDate = range.startDate;
    final endDate = range.endDate;

    final summaryFuture = getReportSummary(
      startDate,
      endDate,
      executor: executor,
    );
    final productsFuture = getProductBreakdown(
      startDate,
      endDate,
      executor: executor,
    );
    final topSellingFuture = getTopSellingProduct(
      startDate,
      endDate,
      executor: executor,
    );
    final highestProfitFuture = getHighestProfitProduct(
      startDate,
      endDate,
      executor: executor,
    );
    final paymentMethodsFuture = getPaymentMethodBreakdown(
      startDate,
      endDate,
      executor: executor,
    );

    // Kueri breakdown harian hanya untuk periode mingguan dan bulanan
    final dailyFuture =
        (periodType == ReportPeriodType.daily)
            ? Future.value(<DailyReportStat>[])
            : getDailyBreakdown(startDate, endDate, executor: executor);

    final results = await Future.wait([
      summaryFuture,
      productsFuture,
      topSellingFuture,
      highestProfitFuture,
      dailyFuture,
      paymentMethodsFuture,
    ]);

    final summary = results[0] as ReportSummary;
    final products = results[1] as List<ReportProductStat>;
    final topSelling = results[2] as ReportProductStat?;
    final highestProfit = results[3] as ReportProductStat?;
    final dailyBreakdown = results[4] as List<DailyReportStat>;
    final paymentMethods = results[5] as List<PaymentMethodStat>;

    return ReportData(
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
      summary: summary,
      products: products,
      topSelling: topSelling,
      highestProfit: highestProfit,
      dailyBreakdown: dailyBreakdown,
      paymentMethods: paymentMethods,
    );
  }
}

