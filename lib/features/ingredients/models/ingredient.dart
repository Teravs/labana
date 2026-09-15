/// Model data untuk bahan mentah (ingredients).
class Ingredient {
  final int? id;
  final String name;
  final String status;
  final String createdAt;
  final String updatedAt;

  const Ingredient({
    this.id,
    required this.name,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as int?,
      name: map['name'] as String,
      status: (map['status'] as String?) ?? 'active',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  Ingredient copyWith({
    int? id,
    String? name,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Ingredient(id: $id, name: $name, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ingredient &&
        other.id == id &&
        other.name == name &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(id, name, status);
}
