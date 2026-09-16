import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../home/models/dashboard_summary.dart';
import '../errors/sale_exceptions.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/transaction_number_generator.dart';

/// Repository untuk pengelolaan transaksi penjualan (`sales` & `sale_items`).
class SaleRepository {
  /// Notifier global untuk memberi tahu listener bahwa data penjualan berubah (create/update/delete).
  static final ValueNotifier<int> salesChangeNotifier = ValueNotifier<int>(0);

  final DatabaseHelper _dbHelper;
  final TransactionNumberGenerator _generator;

  SaleRepository({
    DatabaseHelper? dbHelper,
    TransactionNumberGenerator? generator,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _generator = generator ?? TransactionNumberGenerator(dbHelper: dbHelper);

  Future<Database> get _db async => await _dbHelper.database;

  /// Mengambil semua transaksi penjualan beserta jumlah itemnya,
  /// terurut dari yang terbaru (`transaction_date DESC, id DESC`).
  Future<List<Sale>> getAll({DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;

    // Gunakan query LEFT JOIN dengan GROUP BY untuk menyertakan item_count secara efisien
    final results = await exec.rawQuery('''
      SELECT s.*, COUNT(si.id) AS item_count
      FROM ${TableNames.sales} s
      LEFT JOIN ${TableNames.saleItems} si ON s.id = si.sale_id
      GROUP BY s.id
      ORDER BY s.transaction_date DESC, s.id DESC
    ''');

    return results.map((row) => Sale.fromMap(row)).toList();
  }

  /// Mengambil satu transaksi penjualan berdasarkan [id] lengkap dengan seluruh [SaleItem] snapshot-nya.
  Future<Sale?> getById(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;

    final saleResults = await exec.query(
      TableNames.sales,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (saleResults.isEmpty) return null;

    final itemResults = await exec.query(
      TableNames.saleItems,
      where: 'sale_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );

    final items = itemResults.map((row) => SaleItem.fromMap(row)).toList();
    return Sale.fromMap(saleResults.first, items: items);
  }

  /// Menyimpan transaksi penjualan baru beserta item-itemnya secara atomik dalam satu blok transaksi SQLite.
  ///
  /// Menangani potensi tabrakan *UNIQUE constraint* pada `transaction_number` dengan mekanisme *retry* otomatis.
  Future<Sale> createSaleWithItems({
    required Sale sale,
    required List<SaleItem> items,
    DatabaseExecutor? executor,
  }) async {
    if (items.isEmpty) {
      throw const SaleValidationException(
        'Transaksi harus memiliki minimal 1 produk.',
      );
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw const SaleValidationException(
          'Kuantitas porsi setiap item harus lebih besar dari 0.',
        );
      }
    }

    Future<Sale> executeInTxn(Transaction txn) async {
      int insertedSaleId = 0;
      String finalTransactionNumber = sale.transactionNumber;
      const maxRetries = 5;
      var inserted = false;

      // Mekanisme retry jika terjadi unique constraint collision pada transaction_number
      for (var attempt = 0; attempt < maxRetries; attempt++) {
        try {
          if (finalTransactionNumber.isEmpty || attempt > 0) {
            finalTransactionNumber = await _generator.generate(
              sale.transactionDate,
              executor: txn,
              offset: attempt,
            );
          }

          final saleMap = sale.toMap();
          saleMap['transaction_number'] = finalTransactionNumber;

          insertedSaleId = await txn.insert(
            TableNames.sales,
            saleMap,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          inserted = true;
          break;
        } on DatabaseException catch (e) {
          if (e.isUniqueConstraintError()) {
            // Collision terdeteksi, coba lagi dengan sequence berikutnya
            continue;
          }
          rethrow;
        }
      }

      if (!inserted) {
        throw const TransactionNumberGenerationException(
          'Gagal menghasilkan nomor transaksi unik setelah beberapa percobaan.',
        );
      }

      final savedItems = <SaleItem>[];
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['sale_id'] = insertedSaleId;

        final itemId = await txn.insert(
          TableNames.saleItems,
          itemMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        savedItems.add(item.copyWith(id: itemId, saleId: insertedSaleId));
      }

      return sale.copyWith(
        id: insertedSaleId,
        transactionNumber: finalTransactionNumber,
        items: savedItems,
        itemCount: savedItems.length,
      );
    }

    final Sale result;
    if (executor is Transaction) {
      result = await executeInTxn(executor);
    } else {
      final db = await _db;
      result = await db.transaction((txn) async => await executeInTxn(txn));
    }
    salesChangeNotifier.value++;
    return result;
  }

  /// Memperbarui transaksi penjualan beserta item-itemnya secara atomik.
  ///
  /// **PENTING**:
  /// - `transaction_number` asli SELALU dipertahankan (tidak pernah berubah meskipun tanggal diedit).
  /// - Item lama dihapus dan digantikan item baru yang telah dihitung ulang.
  Future<Sale> updateSaleWithItems({
    required Sale sale,
    required List<SaleItem> items,
    DatabaseExecutor? executor,
  }) async {
    if (sale.id == null) {
      throw const SaleValidationException(
        'ID transaksi diperlukan untuk memperbarui transaksi.',
      );
    }

    if (items.isEmpty) {
      throw const SaleValidationException(
        'Transaksi harus memiliki minimal 1 produk.',
      );
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw const SaleValidationException(
          'Kuantitas porsi setiap item harus lebih besar dari 0.',
        );
      }
    }

    Future<Sale> executeInTxn(Transaction txn) async {
      final existing = await txn.query(
        TableNames.sales,
        where: 'id = ?',
        whereArgs: [sale.id],
        limit: 1,
      );

      if (existing.isEmpty) {
        throw SaleNotFoundException(sale.id!);
      }

      // Pertahankan nomor transaksi yang tersimpan di database
      final preservedTrxNumber = existing.first['transaction_number'] as String;

      final saleMap = sale.toMap();
      saleMap['transaction_number'] = preservedTrxNumber;
      saleMap['updated_at'] = DateTime.now().toIso8601String();

      await txn.update(
        TableNames.sales,
        saleMap,
        where: 'id = ?',
        whereArgs: [sale.id],
      );

      // Hapus sale_items lama
      await txn.delete(
        TableNames.saleItems,
        where: 'sale_id = ?',
        whereArgs: [sale.id],
      );

      // Simpan sale_items baru
      final savedItems = <SaleItem>[];
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['sale_id'] = sale.id;

        final itemId = await txn.insert(
          TableNames.saleItems,
          itemMap,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        savedItems.add(item.copyWith(id: itemId, saleId: sale.id));
      }

      return sale.copyWith(
        transactionNumber: preservedTrxNumber,
        items: savedItems,
        itemCount: savedItems.length,
      );
    }

    final Sale result;
    if (executor is Transaction) {
      result = await executeInTxn(executor);
    } else {
      final db = await _db;
      result = await db.transaction((txn) async => await executeInTxn(txn));
    }
    salesChangeNotifier.value++;
    return result;
  }

  /// Menghapus transaksi penjualan berdasarkan [id].
  ///
  /// Baris `sale_items` terkait otomatis terhapus melalui `ON DELETE CASCADE`.
  Future<void> deleteSale(int id, {DatabaseExecutor? executor}) async {
    Future<void> executeInTxn(Transaction txn) async {
      final existing = await txn.query(
        TableNames.sales,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (existing.isEmpty) {
        throw SaleNotFoundException(id);
      }

      await txn.delete(TableNames.sales, where: 'id = ?', whereArgs: [id]);
    }

    if (executor is Transaction) {
      await executeInTxn(executor);
    } else {
      final db = await _db;
      await db.transaction((txn) async => await executeInTxn(txn));
    }
    salesChangeNotifier.value++;
  }

  /// Memformat objek [DateTime] menjadi string tanggal lokal `YYYY-MM-DD`.
  static String formatLocalDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Mengambil ringkasan data harian (omzet, hpp, profit, jumlah transaksi, produk terjual).
  ///
  /// Menggunakan snapshot transaksi dari `sales` dan `sale_items`.
  Future<DashboardSummary> getDailySummary(
    String dateStr, {
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
          WHERE substr(s2.transaction_date, 1, 10) = ?
        ), 0.0) AS products_sold
      FROM ${TableNames.sales} s
      WHERE substr(s.transaction_date, 1, 10) = ?
    ''',
      [dateStr, dateStr],
    );

    if (results.isEmpty) {
      return const DashboardSummary();
    }

    return DashboardSummary.fromMap(results.first);
  }

  /// Mengambil produk terlaris pada tanggal tertentu berdasarkan total kuantitas terjual.
  ///
  /// Menggunakan tie-breaker deterministik `ORDER BY total_quantity DESC, si.product_id ASC`.
  Future<DashboardProductStat?> getDailyTopSellingProduct(
    String dateStr, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        si.product_id,
        MAX(si.product_name) AS product_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.total_profit) AS total_profit
      FROM ${TableNames.saleItems} si
      INNER JOIN ${TableNames.sales} s ON si.sale_id = s.id
      WHERE substr(s.transaction_date, 1, 10) = ?
      GROUP BY si.product_id
      ORDER BY total_quantity DESC, si.product_id ASC
      LIMIT 1
    ''',
      [dateStr],
    );

    if (results.isEmpty) return null;

    return DashboardProductStat.fromMap(results.first);
  }

  /// Mengambil produk dengan total laba tertinggi pada tanggal tertentu.
  ///
  /// Menggunakan tie-breaker deterministik `ORDER BY total_profit DESC, si.product_id ASC`.
  Future<DashboardProductStat?> getDailyHighestProfitProduct(
    String dateStr, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;

    final results = await exec.rawQuery(
      '''
      SELECT 
        si.product_id,
        MAX(si.product_name) AS product_name,
        SUM(si.quantity) AS total_quantity,
        SUM(si.total_profit) AS total_profit
      FROM ${TableNames.saleItems} si
      INNER JOIN ${TableNames.sales} s ON si.sale_id = s.id
      WHERE substr(s.transaction_date, 1, 10) = ?
      GROUP BY si.product_id
      ORDER BY total_profit DESC, si.product_id ASC
      LIMIT 1
    ''',
      [dateStr],
    );

    if (results.isEmpty) return null;

    return DashboardProductStat.fromMap(results.first);
  }

  /// Helper untuk mengambil ringkasan hari ini (default waktu lokal perangkat).
  Future<DashboardSummary> getTodaySummary({
    String? dateStr,
    DatabaseExecutor? executor,
  }) async {
    final targetDate = dateStr ?? formatLocalDate(DateTime.now());
    return getDailySummary(targetDate, executor: executor);
  }

  /// Helper untuk mengambil produk terlaris hari ini (default waktu lokal perangkat).
  Future<DashboardProductStat?> getTodayTopSellingProduct({
    String? dateStr,
    DatabaseExecutor? executor,
  }) async {
    final targetDate = dateStr ?? formatLocalDate(DateTime.now());
    return getDailyTopSellingProduct(targetDate, executor: executor);
  }

  /// Helper untuk mengambil produk laba tertinggi hari ini (default waktu lokal perangkat).
  Future<DashboardProductStat?> getTodayHighestProfitProduct({
    String? dateStr,
    DatabaseExecutor? executor,
  }) async {
    final targetDate = dateStr ?? formatLocalDate(DateTime.now());
    return getDailyHighestProfitProduct(targetDate, executor: executor);
  }

  /// Helper untuk memuat seluruh payload data dashboard hari ini dalam satu panggilan.
  Future<DashboardData> getTodayDashboardData({
    String? dateStr,
    DatabaseExecutor? executor,
  }) async {
    final targetDate = dateStr ?? formatLocalDate(DateTime.now());
    final summary = await getDailySummary(targetDate, executor: executor);
    final topSelling = await getDailyTopSellingProduct(
      targetDate,
      executor: executor,
    );
    final highestProfit = await getDailyHighestProfitProduct(
      targetDate,
      executor: executor,
    );
    return DashboardData(
      date: targetDate,
      summary: summary,
      topSelling: topSelling,
      highestProfit: highestProfit,
    );
  }
}
