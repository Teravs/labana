/// Model data untuk tabel `products`.
///
/// Menyimpan data master produk minuman yang dijual.
class Product {
  final int? id;
  final String name;
  final String status;
  final String createdAt;
  final String updatedAt;

  const Product({
    this.id,
    required this.name,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper untuk status aktif.
  bool get isActive => status == 'active';

  /// Helper untuk status nonaktif.
  bool get isInactive => status == 'inactive';

  /// Membuat instance [Product] dari Map SQLite.
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      status: map['status'] as String? ?? 'active',
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
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

  Product copyWith({
    int? id,
    String? name,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      status.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}

