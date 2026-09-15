/// Model data untuk Komponen Bahan Olahan (`processed_components`).
class ProcessedComponent {
  static const String typeIngredient = 'ingredient';
  static const String typeOther = 'other';

  final int? id;
  final int? processedIngredientId;
  final String componentType; // 'ingredient' atau 'other'
  final int? ingredientId;
  final int? childProcessedId; // NULL pada Tahap 6
  final double? quantity;
  final String? unit;
  final int? otherCost;
  final String? createdAt;

  // Metadata pembantu untuk tampilan UI dan kalkulasi runtime
  final String? ingredientName;
  final String? label; // Keterangan untuk komponen 'other' pada formulir UI
  final double? calculatedCost;

  const ProcessedComponent({
    this.id,
    this.processedIngredientId,
    required this.componentType,
    this.ingredientId,
    this.childProcessedId,
    this.quantity,
    this.unit,
    this.otherCost,
    this.createdAt,
    this.ingredientName,
    this.label,
    this.calculatedCost,
  });

  bool get isIngredient => componentType == typeIngredient;
  bool get isOther => componentType == typeOther;

  /// Kuantitas penggunaan yang diformat ramah pengguna
  String? get formattedQuantity {
    if (quantity == null) return null;
    if (quantity! % 1 == 0) return quantity!.toInt().toString();
    return quantity.toString().replaceAll('.', ',');
  }

  factory ProcessedComponent.fromMap(Map<String, dynamic> map) {
    return ProcessedComponent(
      id: map['id'] as int?,
      processedIngredientId: map['processed_ingredient_id'] as int?,
      componentType: map['component_type'] as String,
      ingredientId: map['ingredient_id'] as int?,
      childProcessedId: map['child_processed_id'] as int?,
      quantity: map['quantity'] != null
          ? (map['quantity'] as num).toDouble()
          : null,
      unit: map['unit'] as String?,
      otherCost: map['other_cost'] as int?,
      createdAt: map['created_at'] as String?,
      ingredientName: map['ingredient_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (processedIngredientId != null)
        'processed_ingredient_id': processedIngredientId,
      'component_type': componentType,
      'ingredient_id': ingredientId,
      'child_processed_id': childProcessedId,
      'quantity': quantity,
      'unit': unit,
      'other_cost': otherCost,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  ProcessedComponent copyWith({
    int? id,
    int? processedIngredientId,
    String? componentType,
    int? ingredientId,
    int? childProcessedId,
    double? quantity,
    String? unit,
    int? otherCost,
    String? createdAt,
    String? ingredientName,
    String? label,
    double? calculatedCost,
  }) {
    return ProcessedComponent(
      id: id ?? this.id,
      processedIngredientId:
          processedIngredientId ?? this.processedIngredientId,
      componentType: componentType ?? this.componentType,
      ingredientId: ingredientId ?? this.ingredientId,
      childProcessedId: childProcessedId ?? this.childProcessedId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      otherCost: otherCost ?? this.otherCost,
      createdAt: createdAt ?? this.createdAt,
      ingredientName: ingredientName ?? this.ingredientName,
      label: label ?? this.label,
      calculatedCost: calculatedCost ?? this.calculatedCost,
    );
  }
}
