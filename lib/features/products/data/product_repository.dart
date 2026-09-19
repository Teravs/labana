import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/product.dart';
import '../models/product_price.dart';
import '../models/recipe_item.dart';
import '../models/recipe_version.dart';
import 'product_price_repository.dart';
import 'recipe_item_repository.dart';
import 'recipe_version_repository.dart';

/// Bundle hasil penyimpanan lengkap produk beserta resep dan harga jual.
class ProductCompleteBundle {
  final Product product;
  final RecipeVersion recipeVersion;
  final List<RecipeItem> recipeItems;
  final ProductPrice productPrice;

  const ProductCompleteBundle({
    required this.product,
    required this.recipeVersion,
    required this.recipeItems,
    required this.productPrice,
  });
}

/// Repository untuk pengelolaan master data `products` serta transaksi atomik
/// pembuatan dan pengeditan Produk + Resep + Harga Jual.
class ProductRepository {
  final DatabaseHelper _dbHelper;
  final RecipeVersionRepository _recipeVersionRepo;
  final RecipeItemRepository _recipeItemRepo;
  final ProductPriceRepository _priceRepo;

  ProductRepository({
    DatabaseHelper? dbHelper,
    RecipeVersionRepository? recipeVersionRepo,
    RecipeItemRepository? recipeItemRepo,
    ProductPriceRepository? priceRepo,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _recipeVersionRepo = recipeVersionRepo ?? RecipeVersionRepository(),
       _recipeItemRepo = recipeItemRepo ?? RecipeItemRepository(),
       _priceRepo = priceRepo ?? ProductPriceRepository();

  Future<Database> get _db async => await _dbHelper.database;

  /// Mengambil semua produk dengan filter [status] opsional ('active' atau 'inactive').
  Future<List<Product>> getAll({
    String? status,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final where = status != null ? 'status = ?' : null;
    final whereArgs = status != null ? [status] : null;

    final results = await exec.query(
      TableNames.products,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return results.map((m) => Product.fromMap(m)).toList();
  }

  /// Mengambil semua produk yang berstatus `active`.
  Future<List<Product>> getActive({DatabaseExecutor? executor}) async {
    return getAll(status: 'active', executor: executor);
  }

  /// Mengambil semua produk yang berstatus `inactive`.
  Future<List<Product>> getInactive({DatabaseExecutor? executor}) async {
    return getAll(status: 'inactive', executor: executor);
  }

  /// Mengambil produk berdasarkan [id].
  Future<Product?> getById(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.products,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  /// Membuat produk baru sederhana.
  ///
  /// Memvalidasi nama tidak kosong dan tidak ada produk aktif dengan nama yang sama (case-insensitive).
  Future<Product> create(String name, {DatabaseExecutor? executor}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama produk wajib diisi.');
    }

    final exec = executor ?? await _db;

    final existing = await exec.query(
      TableNames.products,
      where: 'LOWER(name) = LOWER(?) AND status = ?',
      whereArgs: [trimmedName, 'active'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException(
        'Produk aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final map = {
      'name': trimmedName,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    };

    final id = await exec.insert(TableNames.products, map);
    return Product(
      id: id,
      name: trimmedName,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Memperbarui nama produk.
  ///
  /// Boleh mempertahankan namanya sendiri, tetapi menolak jika duplikat
  /// dengan produk aktif lainnya.
  Future<Product> update(
    int id, {
    required String name,
    DatabaseExecutor? executor,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama produk wajib diisi.');
    }

    final exec = executor ?? await _db;
    final current = await getById(id, executor: exec);
    if (current == null) {
      throw const ValidationException('Produk tidak ditemukan.');
    }

    final duplicate = await exec.query(
      TableNames.products,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [trimmedName, 'active', id],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      throw const ValidationException(
        'Produk aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await exec.update(
      TableNames.products,
      {'name': trimmedName, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    return current.copyWith(name: trimmedName, updatedAt: now);
  }

  /// Menolak/menonaktifkan produk secara soft (`status = 'inactive'`).
  Future<void> deactivate(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;
    final current = await getById(id, executor: exec);
    if (current == null) {
      throw const ValidationException('Produk tidak ditemukan.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await exec.update(
      TableNames.products,
      {'status': 'inactive', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mengaktifkan kembali produk nonaktif (`status = 'active'`).
  ///
  /// Menolak aktivasi jika sudah ada produk aktif lain dengan nama yang sama.
  Future<void> activate(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;
    final current = await getById(id, executor: exec);
    if (current == null) {
      throw const ValidationException('Produk tidak ditemukan.');
    }

    final duplicate = await exec.query(
      TableNames.products,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [current.name, 'active', id],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      throw const ValidationException(
        'Tidak dapat mengaktifkan produk. Produk aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await exec.update(
      TableNames.products,
      {'status': 'active', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Membuat produk baru beserta versi resep perdana (v1), item komponen resep,
  /// dan harga jual secara atomik dalam satu SQLite transaction.
  ///
  /// Jika satu bagian gagal, seluruh operasi dibatalkan (rollback).
  Future<ProductCompleteBundle> createProductWithRecipeAndPrice({
    required String name,
    required List<RecipeItem> recipeItems,
    required int sellingPrice,
    required String effectiveDate,
    required int hppTotal,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama produk wajib diisi.');
    }
    if (recipeItems.isEmpty) {
      throw const ValidationException(
        'Resep produk minimal harus memiliki 1 komponen.',
      );
    }
    if (sellingPrice < 0) {
      throw const ValidationException('Harga jual tidak boleh negatif.');
    }
    if (effectiveDate.trim().isEmpty) {
      throw const ValidationException('Tanggal efektif wajib diisi.');
    }
    if (hppTotal < 0) {
      throw const ValidationException('HPP total tidak boleh negatif.');
    }

    // Validasi struktur setiap item sebelum memulai transaksi
    for (final item in recipeItems) {
      RecipeItemRepository.validateItem(item);
    }

    return await _dbHelper.transaction<ProductCompleteBundle>((txn) async {
      // 1. Cek duplikasi nama aktif
      final existing = await txn.query(
        TableNames.products,
        where: 'LOWER(name) = LOWER(?) AND status = ?',
        whereArgs: [trimmedName, 'active'],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw const ValidationException(
          'Produk aktif dengan nama tersebut sudah ada.',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // 2. Insert master produk
      final productId = await txn.insert(TableNames.products, {
        'name': trimmedName,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      });

      final createdProduct = Product(
        id: productId,
        name: trimmedName,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      // 3. Insert versi resep perdana (v1, active)
      final recipeVersion = RecipeVersion(
        productId: productId,
        versionNumber: 1,
        effectiveFrom: effectiveDate,
        hppTotal: hppTotal,
        status: 'active',
        createdAt: now,
      );
      final createdVersion = await _recipeVersionRepo.create(
        recipeVersion,
        executor: txn,
      );

      // 4. Insert seluruh item komponen resep (dengan validasi sumber bahan aktif)
      final preparedItems = recipeItems
          .map(
            (item) => item.copyWith(
              recipeVersionId: createdVersion.id,
              createdAt: now,
            ),
          )
          .toList();

      final createdItems = await _recipeItemRepo.createMany(
        preparedItems,
        executor: txn,
        validateActive: true,
      );

      // 5. Insert harga jual awal
      final productPrice = ProductPrice(
        productId: productId,
        sellingPrice: sellingPrice,
        effectiveFrom: effectiveDate,
        createdAt: now,
      );
      final createdPrice = await _priceRepo.create(productPrice, executor: txn);

      return ProductCompleteBundle(
        product: createdProduct,
        recipeVersion: createdVersion,
        recipeItems: createdItems,
        productPrice: createdPrice,
      );
    });
  }

  /// Memperbarui produk beserta resep dan harga jual secara atomik.
  ///
  /// Aturan penting:
  /// - Jika nama produk berubah: update master produk.
  /// - Versi resep baru HANYA dibuat jika resep benar-benar berubah ([recipeItems] tidak null dan berbeda).
  /// - Jika resep berubah: versi aktif lama di-archive, resep baru dibuat sebagai `active` dengan nomor versi `MAX + 1`.
  /// - Harga jual bersifat append-only: hanya dimasukkan ke `product_prices` jika berubah atau ditentukan baru.
  /// - Jika tanggal efektif sama dan harga berbeda dimasukkan, ditolak sebagai duplicate date error.
  Future<ProductCompleteBundle> updateProductWithRecipeAndPrice({
    required int productId,
    required String name,
    List<RecipeItem>? recipeItems,
    int? sellingPrice,
    required String effectiveDate,
    int? hppTotal,
    bool forceNewRecipeVersion = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama produk wajib diisi.');
    }
    if (sellingPrice != null && sellingPrice < 0) {
      throw const ValidationException('Harga jual tidak boleh negatif.');
    }
    if (effectiveDate.trim().isEmpty) {
      throw const ValidationException('Tanggal efektif wajib diisi.');
    }

    if (recipeItems != null) {
      if (recipeItems.isEmpty) {
        throw const ValidationException(
          'Resep produk minimal harus memiliki 1 komponen.',
        );
      }
      for (final item in recipeItems) {
        RecipeItemRepository.validateItem(item);
      }
    }

    return await _dbHelper.transaction<ProductCompleteBundle>((txn) async {
      // 1. Ambil data produk saat ini
      final currentProduct = await getById(productId, executor: txn);
      if (currentProduct == null) {
        throw const ValidationException('Produk tidak ditemukan.');
      }

      // 2. Cek duplikasi nama dengan produk aktif lain
      final duplicate = await txn.query(
        TableNames.products,
        where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
        whereArgs: [trimmedName, 'active', productId],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw const ValidationException(
          'Produk aktif dengan nama tersebut sudah ada.',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // 3. Update master produk jika nama berubah
      await txn.update(
        TableNames.products,
        {'name': trimmedName, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [productId],
      );
      final updatedProduct = currentProduct.copyWith(
        name: trimmedName,
        updatedAt: now,
      );

      // 4. Cek resep aktif saat ini
      final activeVersion = await _recipeVersionRepo.getActiveVersion(
        productId,
        executor: txn,
      );
      final currentItems = activeVersion != null
          ? await _recipeItemRepo.getByRecipeVersionId(
              activeVersion.id!,
              executor: txn,
            )
          : <RecipeItem>[];

      // Tentukan apakah resep mengalami perubahan
      final isRecipeChanged =
          forceNewRecipeVersion ||
          (recipeItems != null &&
              _isRecipeCompositionChanged(currentItems, recipeItems));

      RecipeVersion finalVersion;
      List<RecipeItem> finalItems;

      if (isRecipeChanged && recipeItems != null) {
        // Resep berubah -> arsipkan resep aktif lama
        if (activeVersion != null) {
          await _recipeVersionRepo.archiveActiveVersions(
            productId,
            executor: txn,
          );
        }

        // Buat nomor versi baru MAX + 1
        final nextVersionNumber = await _recipeVersionRepo.getNextVersionNumber(
          productId,
          executor: txn,
        );

        final newVersion = RecipeVersion(
          productId: productId,
          versionNumber: nextVersionNumber,
          effectiveFrom: effectiveDate,
          hppTotal: hppTotal ?? activeVersion?.hppTotal ?? 0,
          status: 'active',
          createdAt: now,
        );
        finalVersion = await _recipeVersionRepo.create(
          newVersion,
          executor: txn,
        );

        // Simpan item-item resep versi baru
        final preparedItems = recipeItems
            .map(
              (item) => item.copyWith(
                recipeVersionId: finalVersion.id,
                createdAt: now,
              ),
            )
            .toList();

        finalItems = await _recipeItemRepo.createMany(
          preparedItems,
          executor: txn,
          validateActive: true,
        );
      } else {
        // Resep tidak berubah -> pertahankan versi resep aktif yang ada
        if (activeVersion == null) {
          throw const ValidationException('Versi resep aktif tidak ditemukan.');
        }
        if (hppTotal != null && activeVersion.hppTotal != hppTotal) {
          await txn.update(
            TableNames.recipeVersions,
            {'hpp_total': hppTotal},
            where: 'id = ?',
            whereArgs: [activeVersion.id],
          );
          finalVersion = activeVersion.copyWith(hppTotal: hppTotal);
        } else {
          finalVersion = activeVersion;
        }
        finalItems = currentItems;
      }

      // 5. Penanganan harga jual (append-only)
      final latestPrice = await _priceRepo.getLatestPrice(
        productId,
        executor: txn,
      );
      ProductPrice finalPrice;

      if (sellingPrice != null &&
          (latestPrice == null || latestPrice.sellingPrice != sellingPrice)) {
        if (latestPrice != null &&
            latestPrice.effectiveFrom == effectiveDate &&
            latestPrice.id != null) {
          // Koreksi harga di hari yang sama: perbarui record harga yang sudah ada
          await _priceRepo.updatePrice(
            latestPrice.id!,
            sellingPrice,
            executor: txn,
          );
          finalPrice = latestPrice.copyWith(sellingPrice: sellingPrice);
        } else {
          // Harga berubah di tanggal berbeda -> insert harga baru dengan effectiveDate
          final newPrice = ProductPrice(
            productId: productId,
            sellingPrice: sellingPrice,
            effectiveFrom: effectiveDate,
            createdAt: now,
          );
          finalPrice = await _priceRepo.create(newPrice, executor: txn);
        }
      } else {
        // Harga tidak berubah -> gunakan record harga yang sudah ada
        if (latestPrice == null) {
          if (sellingPrice != null) {
            final newPrice = ProductPrice(
              productId: productId,
              sellingPrice: sellingPrice,
              effectiveFrom: effectiveDate,
              createdAt: now,
            );
            finalPrice = await _priceRepo.create(newPrice, executor: txn);
          } else {
            throw const ValidationException('Harga jual produk belum diatur.');
          }
        } else {
          finalPrice = latestPrice;
        }
      }

      return ProductCompleteBundle(
        product: updatedProduct,
        recipeVersion: finalVersion,
        recipeItems: finalItems,
        productPrice: finalPrice,
      );
    });
  }

  /// Membandingkan dua daftar item resep untuk mengetahui apakah komposisi berubah.
  static bool _isRecipeCompositionChanged(
    List<RecipeItem> oldItems,
    List<RecipeItem> newItems,
  ) {
    if (oldItems.length != newItems.length) return true;

    // Sort berdasarkan key deterministik agar urutan input tidak memengaruhi hasil
    String sortKey(RecipeItem item) =>
        '${item.componentType}_${item.ingredientId ?? 0}_${item.processedIngredientId ?? 0}_${item.otherCost ?? 0}_${item.quantity ?? 0}_${item.unit ?? ""}_${item.label ?? ""}';

    final sortedOld = List<RecipeItem>.from(oldItems)
      ..sort((a, b) => sortKey(a).compareTo(sortKey(b)));
    final sortedNew = List<RecipeItem>.from(newItems)
      ..sort((a, b) => sortKey(a).compareTo(sortKey(b)));

    for (int i = 0; i < sortedOld.length; i++) {
      final o = sortedOld[i];
      final n = sortedNew[i];

      if (o.componentType != n.componentType) return true;
      if (o.ingredientId != n.ingredientId) return true;
      if (o.processedIngredientId != n.processedIngredientId) return true;
      if (o.quantity != n.quantity) return true;
      if (o.unit != n.unit) return true;
      if (o.otherCost != n.otherCost) return true;
      if (o.label != n.label) return true;
    }

    return false;
  }
}
