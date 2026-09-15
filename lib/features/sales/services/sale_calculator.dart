import 'package:sqflite/sqflite.dart';

import '../../products/data/product_price_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/recipe_version_repository.dart';
import '../../products/errors/hpp_exceptions.dart';
import '../../products/models/product.dart';
import '../../products/services/hpp_engine.dart';
import '../errors/sale_exceptions.dart';
import '../models/sale_item.dart';

/// Ringkasan akumulasi total omzet, HPP, dan laba transaksi.
class SaleTotals {
  final int totalAmount;
  final int totalHpp;
  final int totalProfit;

  const SaleTotals({
    required this.totalAmount,
    required this.totalHpp,
    required this.totalProfit,
  });
}

/// Representasi produk pada Product Picker lengkap dengan status evaluasi HPP & harga.
class ProductPickerItem {
  final Product product;
  final int? sellingPrice;
  final int? hppPerUnit;
  final int? profitPerUnit;
  final bool isValid;
  final String? errorMessage;

  const ProductPickerItem({
    required this.product,
    this.sellingPrice,
    this.hppPerUnit,
    this.profitPerUnit,
    required this.isValid,
    this.errorMessage,
  });
}

/// Service kalkulator transaksi penjualan yang mengintegrasikan [HppEngine],
/// resolusi harga jual efektif, resolusi versi resep efektif, dan validasi produk.
class SaleCalculator {
  final HppEngine _hppEngine;
  final ProductRepository _productRepo;
  final RecipeVersionRepository _recipeVersionRepo;
  final ProductPriceRepository _priceRepo;

  SaleCalculator({
    HppEngine? hppEngine,
    ProductRepository? productRepo,
    RecipeVersionRepository? recipeVersionRepo,
    ProductPriceRepository? priceRepo,
  }) : _hppEngine = hppEngine ?? HppEngine(),
       _productRepo = productRepo ?? ProductRepository(),
       _recipeVersionRepo = recipeVersionRepo ?? RecipeVersionRepository(),
       _priceRepo = priceRepo ?? ProductPriceRepository();

  /// Menghitung snapshot komponen [SaleItem] untuk [productId] pada tanggal [transactionDate].
  ///
  /// [isNewItem]: Jika `true` atau produk bukan bagian dari [existingProductIds],
  /// maka produk wajib berstatus `active`.
  /// Jika produk merupakan item lama pada transaksi yang sedang diedit (`existingProductIds.contains(productId)`),
  /// produk `inactive` tetap diizinkan untuk dihitung ulang secara historis.
  Future<SaleItem> calculateItem({
    required int productId,
    required String transactionDate,
    required double quantity,
    bool isNewItem = false,
    Set<int> existingProductIds = const {},
    DatabaseExecutor? executor,
  }) async {
    if (quantity <= 0) {
      throw const SaleValidationException(
        'Kuantitas porsi harus lebih besar dari 0.',
      );
    }

    final product = await _productRepo.getById(productId, executor: executor);
    if (product == null) {
      throw SaleValidationException(
        'Produk dengan ID $productId tidak ditemukan.',
      );
    }

    // Aturan Inactive Product:
    // Jika menambah item baru atau produk bukan bagian dari item transaksi lama, produk wajib aktif.
    final isExisting = existingProductIds.contains(productId) && !isNewItem;
    if (!isExisting && !product.isActive) {
      throw SaleValidationException(
        'Produk "${product.name}" berstatus nonaktif dan tidak dapat ditambahkan sebagai item baru.',
      );
    }

    final dateOnly = transactionDate.length >= 10
        ? transactionDate.substring(0, 10)
        : transactionDate;

    // 1. Resolve Versi Resep Efektif
    final recipeVersion = await _recipeVersionRepo.getEffectiveVersion(
      productId,
      calculationDate: dateOnly,
      executor: executor,
    );
    if (recipeVersion == null) {
      throw HistoricalCalculationException(
        'Resep untuk produk "${product.name}" belum tersedia untuk tanggal $dateOnly.',
      );
    }

    // 2. Resolve Harga Jual Efektif
    final productPrice = await _priceRepo.getEffectivePriceAt(
      productId,
      calculationDate: dateOnly,
      executor: executor,
    );
    if (productPrice == null) {
      throw HistoricalCalculationException(
        'Harga jual untuk produk "${product.name}" belum tersedia untuk tanggal $dateOnly.',
      );
    }

    // 3. Hitung HPP melalui HppEngine (strict: true)
    int hppPerUnit;
    try {
      final hppResult = await _hppEngine.calculateProductHpp(
        productId: productId,
        calculationDate: dateOnly,
        strict: true,
        executor: executor,
      );
      hppPerUnit = hppResult.hppTotal;
    } on MissingIngredientPriceException catch (e) {
      throw HistoricalCalculationException(
        'HPP produk "${product.name}" belum dapat dihitung karena ${e.message} pada tanggal $dateOnly.',
      );
    } on NoEffectiveRecipeException {
      throw HistoricalCalculationException(
        'Resep untuk produk "${product.name}" belum berlaku pada tanggal $dateOnly.',
      );
    } catch (e) {
      throw HistoricalCalculationException(
        'Gagal menghitung HPP untuk produk "${product.name}": $e',
      );
    }

    // 4. Perhitungan snapshot nilai
    final subtotal = (quantity * productPrice.sellingPrice).round();
    final totalHpp = (quantity * hppPerUnit).round();
    final totalProfit = subtotal - totalHpp;

    return SaleItem(
      productId: productId,
      recipeVersionId: recipeVersion.id!,
      productName: product.name,
      quantity: quantity,
      sellingPrice: productPrice.sellingPrice,
      hppPerUnit: hppPerUnit,
      subtotal: subtotal,
      totalHpp: totalHpp,
      totalProfit: totalProfit,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Menghitung akumulasi total omzet, HPP, dan laba dari daftar [items].
  SaleTotals calculateTotals(List<SaleItem> items) {
    int totalAmount = 0;
    int totalHpp = 0;

    for (final item in items) {
      totalAmount += item.subtotal;
      totalHpp += item.totalHpp;
    }

    final totalProfit = totalAmount - totalHpp;

    return SaleTotals(
      totalAmount: totalAmount,
      totalHpp: totalHpp,
      totalProfit: totalProfit,
    );
  }

  /// Mengambil daftar produk aktif yang dapat dipilih pada Product Picker,
  /// lengkap dengan evaluasi harga jual efektif, HPP, dan estimasi laba pada [transactionDate].
  Future<List<ProductPickerItem>> getAvailableProductsForPicker({
    required String transactionDate,
    DatabaseExecutor? executor,
  }) async {
    final dateOnly = transactionDate.length >= 10
        ? transactionDate.substring(0, 10)
        : transactionDate;

    // Hanya produk berstatus active
    final activeProducts = await _productRepo.getAll(
      status: 'active',
      executor: executor,
    );
    final pickerItems = <ProductPickerItem>[];

    for (final product in activeProducts) {
      try {
        final recipe = await _recipeVersionRepo.getEffectiveVersion(
          product.id!,
          calculationDate: dateOnly,
          executor: executor,
        );
        if (recipe == null) {
          pickerItems.add(
            ProductPickerItem(
              product: product,
              isValid: false,
              errorMessage: 'Resep belum tersedia untuk tanggal $dateOnly',
            ),
          );
          continue;
        }

        final price = await _priceRepo.getEffectivePriceAt(
          product.id!,
          calculationDate: dateOnly,
          executor: executor,
        );
        if (price == null) {
          pickerItems.add(
            ProductPickerItem(
              product: product,
              isValid: false,
              errorMessage:
                  'Harga jual belum ditentukan untuk tanggal $dateOnly',
            ),
          );
          continue;
        }

        final hppResult = await _hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: dateOnly,
          strict: false,
          executor: executor,
        );

        if (!hppResult.isValid || hppResult.hasUnresolvedCost) {
          final warningMsg = hppResult.warnings.isNotEmpty
              ? hppResult.warnings.first
              : 'Harga bahan belum lengkap untuk tanggal $dateOnly';
          pickerItems.add(
            ProductPickerItem(
              product: product,
              sellingPrice: price.sellingPrice,
              isValid: false,
              errorMessage: warningMsg,
            ),
          );
          continue;
        }

        final hpp = hppResult.hppTotal;
        final profitPerUnit = price.sellingPrice - hpp;

        pickerItems.add(
          ProductPickerItem(
            product: product,
            sellingPrice: price.sellingPrice,
            hppPerUnit: hpp,
            profitPerUnit: profitPerUnit,
            isValid: true,
          ),
        );
      } catch (e) {
        pickerItems.add(
          ProductPickerItem(
            product: product,
            isValid: false,
            errorMessage: 'Kalkulasi HPP gagal: $e',
          ),
        );
      }
    }

    return pickerItems;
  }
}
