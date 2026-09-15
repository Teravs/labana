import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../errors/sale_exceptions.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/transaction_number_generator.dart';

/// Repository untuk pengelolaan transaksi penjualan (`sales` & `sale_items`).
class SaleRepository {
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

    if (executor is Transaction) {
      return await executeInTxn(executor);
    }

    final db = await _db;
    return await db.transaction((txn) async => await executeInTxn(txn));
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

    if (executor is Transaction) {
      return await executeInTxn(executor);
    }

    final db = await _db;
    return await db.transaction((txn) async => await executeInTxn(txn));
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
      return;
    }

    final db = await _db;
    await db.transaction((txn) async => await executeInTxn(txn));
  }
}
