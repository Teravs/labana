/// Domain exceptions untuk kalkulasi HPP produk pada [HppEngine].
library;

/// Exception yang dilempar saat produk dengan ID tertentu tidak ditemukan di database.
class ProductNotFoundException implements Exception {
  final String message;
  final int? productId;

  const ProductNotFoundException(this.message, {this.productId});

  @override
  String toString() => message;
}

/// Exception yang dilempar saat tidak ada versi resep yang berlaku pada tanggal kalkulasi
/// (`effective_from <= calculationDate`).
class NoEffectiveRecipeException implements Exception {
  final String message;
  final int? productId;
  final String? calculationDate;

  const NoEffectiveRecipeException(
    this.message, {
    this.productId,
    this.calculationDate,
  });

  @override
  String toString() => message;
}

/// Exception yang dilempar saat bahan mentah tidak memiliki riwayat harga yang berlaku
/// pada tanggal kalkulasi (mode `strict: true`).
class MissingIngredientPriceException implements Exception {
  final String message;
  final int? ingredientId;
  final String? ingredientName;
  final String? calculationDate;

  const MissingIngredientPriceException(
    this.message, {
    this.ingredientId,
    this.ingredientName,
    this.calculationDate,
  });

  @override
  String toString() => message;
}

