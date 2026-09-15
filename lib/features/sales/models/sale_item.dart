import '../../../core/utils/currency_formatter.dart';

/// Model representasi item komponen transaksi penjualan (`sale_items`).
///
/// Menyimpan snapshot historis permanen saat transaksi disimpan:
/// nama produk, harga jual satuan, HPP satuan, subtotal, total HPP, dan total laba.
class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final int recipeVersionId;
  final String productName;
  final double quantity;
  final int sellingPrice;
  final int hppPerUnit;
  final int subtotal;
  final int totalHpp;
  final int totalProfit;
  final String createdAt;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.recipeVersionId,
    required this.productName,
    required this.quantity,
    required this.sellingPrice,
    required this.hppPerUnit,
    required this.subtotal,
    required this.totalHpp,
    required this.totalProfit,
    required this.createdAt,
  });

  /// Laba per unit porsi: `sellingPrice - hppPerUnit`.
  int get profitPerUnit => sellingPrice - hppPerUnit;

  /// Format kuantitas pemakaian porsi (misal "2", "1.5").
  String get formattedQuantity {
    return quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toString();
  }

  /// Format harga jual satuan (misal "Rp5.000").
  String get formattedSellingPrice =>
      CurrencyFormatter.formatRupiah(sellingPrice);

  /// Format HPP satuan (misal "Rp1.340").
  String get formattedHppPerUnit => CurrencyFormatter.formatRupiah(hppPerUnit);

  /// Format subtotal omzet item (misal "Rp10.000").
  String get formattedSubtotal => CurrencyFormatter.formatRupiah(subtotal);

  /// Format total HPP item (misal "Rp2.680").
  String get formattedTotalHpp => CurrencyFormatter.formatRupiah(totalHpp);

  /// Format total laba item (misal "Rp7.320").
  String get formattedTotalProfit =>
      CurrencyFormatter.formatRupiah(totalProfit);

  /// Membuat instance [SaleItem] dari Map SQLite.
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int,
      recipeVersionId: map['recipe_version_id'] as int,
      productName: map['product_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toInt(),
      hppPerUnit: (map['hpp_per_unit'] as num).toInt(),
      subtotal: (map['subtotal'] as num).toInt(),
      totalHpp: (map['total_hpp'] as num).toInt(),
      totalProfit: (map['total_profit'] as num).toInt(),
      createdAt: map['created_at'] as String,
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'product_id': productId,
      'recipe_version_id': recipeVersionId,
      'product_name': productName,
      'quantity': quantity,
      'selling_price': sellingPrice,
      'hpp_per_unit': hppPerUnit,
      'subtotal': subtotal,
      'total_hpp': totalHpp,
      'total_profit': totalProfit,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    if (saleId != null) {
      map['sale_id'] = saleId;
    }
    return map;
  }

  /// Membuat salinan objek dengan modifikasi field tertentu.
  SaleItem copyWith({
    int? id,
    int? saleId,
    int? productId,
    int? recipeVersionId,
    String? productName,
    double? quantity,
    int? sellingPrice,
    int? hppPerUnit,
    int? subtotal,
    int? totalHpp,
    int? totalProfit,
    String? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      recipeVersionId: recipeVersionId ?? this.recipeVersionId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      hppPerUnit: hppPerUnit ?? this.hppPerUnit,
      subtotal: subtotal ?? this.subtotal,
      totalHpp: totalHpp ?? this.totalHpp,
      totalProfit: totalProfit ?? this.totalProfit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
