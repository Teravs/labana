/// Model data untuk Bahan Olahan (`processed_ingredients`).
class ProcessedIngredient {
  final int? id;
  final String name;
  final double resultQuantity;
  final String resultUnit; // 'g', 'ml', 'pcs'
  final String status; // 'active', 'inactive'
  final String? createdAt;
  final String? updatedAt;

  const ProcessedIngredient({
    this.id,
    required this.name,
    required this.resultQuantity,
    required this.resultUnit,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isInactive => status == 'inactive';

  /// Format kuantitas hasil produksi (misal 5000 -> "5.000" atau 1.5 -> "1,5")
  String get formattedResultQuantity {
    if (resultQuantity % 1 == 0) {
      final intVal = resultQuantity.toInt();
      final absVal = intVal.abs().toString();
      final buffer = StringBuffer();
      final len = absVal.length;
      for (int i = 0; i < len; i++) {
        if (i > 0 && (len - i) % 3 == 0) buffer.write('.');
        buffer.write(absVal[i]);
      }
      return buffer.toString();
    }
    return resultQuantity.toString().replaceAll('.', ',');
  }

  /// Format hasil lengkap dengan satuan (misal: "5.000 ml")
  String get formattedResult => '$formattedResultQuantity $resultUnit';

  factory ProcessedIngredient.fromMap(Map<String, dynamic> map) {
    return ProcessedIngredient(
      id: map['id'] as int?,
      name: map['name'] as String,
      resultQuantity: (map['result_quantity'] as num).toDouble(),
      resultUnit: map['result_unit'] as String,
      status: map['status'] as String? ?? 'active',
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'result_quantity': resultQuantity,
      'result_unit': resultUnit,
      'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  ProcessedIngredient copyWith({
    int? id,
    String? name,
    double? resultQuantity,
    String? resultUnit,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProcessedIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      resultQuantity: resultQuantity ?? this.resultQuantity,
      resultUnit: resultUnit ?? this.resultUnit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
