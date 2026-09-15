/// Model data untuk harga pembelian bahan mentah (`ingredient_prices`).
class IngredientPrice {
  final int? id;
  final int ingredientId;
  final double purchaseQuantity;
  final String purchaseUnit;
  final double baseQuantity;
  final String baseUnit;
  final double? packageQuantity;
  final int price;
  final bool isDefault;
  final String effectiveFrom; // Format YYYY-MM-DD
  final String? createdAt;

  const IngredientPrice({
    this.id,
    required this.ingredientId,
    required this.purchaseQuantity,
    required this.purchaseUnit,
    required this.baseQuantity,
    required this.baseUnit,
    this.packageQuantity,
    required this.price,
    this.isDefault = false,
    required this.effectiveFrom,
    this.createdAt,
  });

  /// Biaya per satuan dasar (misal: Rp20/g).
  /// Dihitung secara dinamis tanpa pembulatan prematur.
  double get costPerBaseUnit => baseQuantity > 0 ? price / baseQuantity : 0.0;

  /// Kuantitas pembelian yang diformat ramah pengguna (misal 1 atau 1.5).
  String get formattedPurchaseQuantity => purchaseQuantity % 1 == 0
      ? purchaseQuantity.toInt().toString()
      : purchaseQuantity.toString();

  /// Format kuantitas isi per pack (misal 50).
  String? get formattedPackageQuantity => packageQuantity == null
      ? null
      : (packageQuantity! % 1 == 0
            ? packageQuantity!.toInt().toString()
            : packageQuantity.toString());

  /// Label format pembelian ringkas (misal: "1 kg", "500 g", atau "1 pack (50 pcs)").
  String get formattedPurchaseFormat {
    if (purchaseUnit == 'pack') {
      final isi = formattedPackageQuantity ?? '?';
      return '$formattedPurchaseQuantity pack ($isi pcs)';
    }
    return '$formattedPurchaseQuantity $purchaseUnit';
  }

  /// Membuat instance `IngredientPrice` dari baris data SQLite.
  factory IngredientPrice.fromMap(Map<String, dynamic> map) {
    return IngredientPrice(
      id: map['id'] as int?,
      ingredientId: map['ingredient_id'] as int,
      purchaseQuantity: (map['purchase_quantity'] as num).toDouble(),
      purchaseUnit: map['purchase_unit'] as String,
      baseQuantity: (map['base_quantity'] as num).toDouble(),
      baseUnit: map['base_unit'] as String,
      packageQuantity: map['package_quantity'] != null
          ? (map['package_quantity'] as num).toDouble()
          : null,
      price: map['price'] as int,
      isDefault: (map['is_default'] as int) == 1,
      effectiveFrom: map['effective_from'] as String,
      createdAt: map['created_at'] as String?,
    );
  }

  /// Mengonversi instance `IngredientPrice` ke Map untuk operasi SQLite.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ingredient_id': ingredientId,
      'purchase_quantity': purchaseQuantity,
      'purchase_unit': purchaseUnit,
      'base_quantity': baseQuantity,
      'base_unit': baseUnit,
      'package_quantity': packageQuantity,
      'price': price,
      'is_default': isDefault ? 1 : 0,
      'effective_from': effectiveFrom,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  /// Membuat salinan objek dengan field tertentu yang diperbarui.
  IngredientPrice copyWith({
    int? id,
    int? ingredientId,
    double? purchaseQuantity,
    String? purchaseUnit,
    double? baseQuantity,
    String? baseUnit,
    double? packageQuantity,
    int? price,
    bool? isDefault,
    String? effectiveFrom,
    String? createdAt,
  }) {
    return IngredientPrice(
      id: id ?? this.id,
      ingredientId: ingredientId ?? this.ingredientId,
      purchaseQuantity: purchaseQuantity ?? this.purchaseQuantity,
      purchaseUnit: purchaseUnit ?? this.purchaseUnit,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      baseUnit: baseUnit ?? this.baseUnit,
      packageQuantity: packageQuantity ?? this.packageQuantity,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
