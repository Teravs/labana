import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/product_price.dart';

/// Repository untuk pengelolaan data tabel `product_prices`.
///
/// Menyimpan riwayat harga jual produk yang bersifat append-only.
class ProductPriceRepository {
  final DatabaseHelper _dbHelper;

  ProductPriceRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Menyimpan riwayat harga jual baru.
  ///
  /// Menolak duplikasi jika `product_id + effective_from` sudah ada.
  Future<ProductPrice> create(
    ProductPrice price, {
    DatabaseExecutor? executor,
  }) async {
    if (price.sellingPrice < 0) {
      throw const ValidationException('Harga jual tidak boleh negatif.');
    }
    if (price.effectiveFrom.trim().isEmpty) {
      throw const ValidationException(
        'Tanggal efektif harga jual wajib diisi.',
      );
    }

    final exec = executor ?? await _db;

    // Cek duplikasi tanggal efektif untuk produk yang sama (append-only strictly enforced)
    final existing = await exec.query(
      TableNames.productPrices,
      where: 'product_id = ? AND effective_from = ?',
      whereArgs: [price.productId, price.effectiveFrom],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw ValidationException(
        'Harga jual untuk tanggal ${price.effectiveFrom} sudah ada.',
      );
    }

    final map = price.toMap();
    final id = await exec.insert(TableNames.productPrices, map);
    return price.copyWith(id: id);
  }

  /// Memperbarui nilai harga jual untuk record yang sudah ada (untuk koreksi input di tanggal yang sama).
  Future<void> updatePrice(
    int id,
    int sellingPrice, {
    DatabaseExecutor? executor,
  }) async {
    if (sellingPrice < 0) {
      throw const ValidationException('Harga jual tidak boleh negatif.');
    }
    final exec = executor ?? await _db;
    await exec.update(
      TableNames.productPrices,
      {'selling_price': sellingPrice},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mengambil semua riwayat harga jual untuk suatu produk,
  /// diurutkan berdasarkan tanggal efektif terbaru.
  Future<List<ProductPrice>> getByProductId(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.productPrices,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'effective_from DESC, id DESC',
    );
    return results.map((m) => ProductPrice.fromMap(m)).toList();
  }

  /// Mengambil harga jual yang efektif pada [effectiveDate].
  ///
  /// Mencari harga dengan `effective_from <= effectiveDate` terbaru.
  /// Mengembalikan `null` jika belum ada harga yang efektif pada tanggal tersebut.
  Future<ProductPrice?> getEffectivePrice(
    int productId, {
    String? effectiveDate,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final date = effectiveDate ?? todayStr;

    final results = await exec.query(
      TableNames.productPrices,
      where: 'product_id = ? AND effective_from <= ?',
      whereArgs: [productId, date],
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ProductPrice.fromMap(results.first);
  }

  /// Mengambil harga jual yang berlaku pada [calculationDate].
  ///
  /// Aturan: `product_prices.effective_from <= calculationDate`
  /// Diurutkan berdasarkan `effective_from DESC, id DESC LIMIT 1`.
  /// Mengembalikan `null` jika belum ada harga yang efektif pada tanggal tersebut.
  Future<ProductPrice?> getEffectivePriceAt(
    int productId, {
    required String calculationDate,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.productPrices,
      where: 'product_id = ? AND effective_from <= ?',
      whereArgs: [productId, calculationDate],
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProductPrice.fromMap(results.first);
  }

  /// Mengambil harga jual paling mutakhir (berdasarkan record terakhir).
  Future<ProductPrice?> getLatestPrice(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.productPrices,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ProductPrice.fromMap(results.first);
  }
}
