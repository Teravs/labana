import '../../../core/utils/currency_formatter.dart';

/// Model data untuk tabel `recipe_items`.
///
/// Mewakili satu baris komponen dalam suatu versi resep (`RecipeVersion`).
/// Mendukung 3 jenis komponen:
/// 1. `ingredient`: bahan mentah (`ingredient_id`, `quantity`, `unit`).
/// 2. `processed`: bahan olahan (`processed_ingredient_id`, `quantity`, `unit`).
/// 3. `other`: biaya pelengkap/operasional nominal (`other_cost`).
class RecipeItem {
  static const String typeIngredient = 'ingredient';
  static const String typeProcessed = 'processed';
  static const String typeOther = 'other';

  final int? id;
  final int recipeVersionId;
  final String componentType;
  final int? ingredientId;
  final int? processedIngredientId;
  final double? quantity;
  final String? unit;
  final int? otherCost;
  final String createdAt;

  // Metadata hasil JOIN (transient, hanya untuk tampilan UI, tidak disimpan ke DB)
  final String? ingredientName;
  final String? processedIngredientName;
  final String? label;

  const RecipeItem({
    this.id,
    required this.recipeVersionId,
    required this.componentType,
    this.ingredientId,
    this.processedIngredientId,
    this.quantity,
    this.unit,
    this.otherCost,
    required this.createdAt,
    this.ingredientName,
    this.processedIngredientName,
    this.label,
  });

  /// Helper untuk memeriksa apakah komponen merupakan bahan mentah.
  bool get isIngredient => componentType == typeIngredient;

  /// Helper untuk memeriksa apakah komponen merupakan bahan olahan.
  bool get isProcessed => componentType == typeProcessed;

  /// Helper untuk memeriksa apakah komponen merupakan biaya lainnya.
  bool get isOther => componentType == typeOther;

  /// Format kuantitas pemakaian (misal 5 g, 30 ml).
  String get formattedQuantity {
    if (quantity == null) return '-';
    final qty = quantity!;
    final str = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    return unit != null ? '$str $unit' : str;
  }

  /// Format biaya nominal jika komponen bertipe other (misal "Rp500").
  String get formattedOtherCost {
    if (otherCost == null) return '-';
    return CurrencyFormatter.formatRupiah(otherCost!);
  }

  /// Nama tampilan komponen untuk kebutuhan UI.
  String get displayName {
    if (isIngredient) {
      return ingredientName ?? 'Bahan Mentah';
    }
    if (isProcessed) {
      return processedIngredientName ?? 'Bahan Olahan';
    }
    return label ?? 'Biaya Lainnya';
  }

  /// Membuat instance [RecipeItem] dari Map SQLite.
  factory RecipeItem.fromMap(Map<String, dynamic> map) {
    return RecipeItem(
      id: map['id'] as int?,
      recipeVersionId: map['recipe_version_id'] as int,
      componentType: map['component_type'] as String,
      ingredientId: map['ingredient_id'] as int?,
      processedIngredientId: map['processed_ingredient_id'] as int?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      otherCost: map['other_cost'] as int?,
      createdAt: map['created_at'] as String,
      ingredientName: map['ingredient_name'] as String?,
      processedIngredientName: map['processed_ingredient_name'] as String?,
      label: map['label'] as String?,
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'recipe_version_id': recipeVersionId,
      'component_type': componentType,
      'ingredient_id': ingredientId,
      'processed_ingredient_id': processedIngredientId,
      'quantity': quantity,
      'unit': unit,
      'other_cost': otherCost,
      'created_at': createdAt,
    };
    if (componentType == typeOther && label != null) {
      map['label'] = label;
    }
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  RecipeItem copyWith({
    int? id,
    int? recipeVersionId,
    String? componentType,
    int? ingredientId,
    int? processedIngredientId,
    double? quantity,
    String? unit,
    int? otherCost,
    String? createdAt,
    String? ingredientName,
    String? processedIngredientName,
    String? label,
  }) {
    return RecipeItem(
      id: id ?? this.id,
      recipeVersionId: recipeVersionId ?? this.recipeVersionId,
      componentType: componentType ?? this.componentType,
      ingredientId: ingredientId ?? this.ingredientId,
      processedIngredientId:
          processedIngredientId ?? this.processedIngredientId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      otherCost: otherCost ?? this.otherCost,
      createdAt: createdAt ?? this.createdAt,
      ingredientName: ingredientName ?? this.ingredientName,
      processedIngredientName:
          processedIngredientName ?? this.processedIngredientName,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          recipeVersionId == other.recipeVersionId &&
          componentType == other.componentType &&
          ingredientId == other.ingredientId &&
          processedIngredientId == other.processedIngredientId &&
          quantity == other.quantity &&
          unit == other.unit &&
          otherCost == other.otherCost &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      recipeVersionId.hashCode ^
      componentType.hashCode ^
      ingredientId.hashCode ^
      processedIngredientId.hashCode ^
      quantity.hashCode ^
      unit.hashCode ^
      otherCost.hashCode ^
      createdAt.hashCode;
}
