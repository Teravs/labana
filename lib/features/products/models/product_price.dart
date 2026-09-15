import '../../../core/utils/currency_formatter.dart';

/// Model data untuk tabel `product_prices`.
///
/// Menyimpan riwayat harga jual produk dengan tanggal efektif.
/// Nominal harga jual selalu berupa integer Rupiah (tidak menggunakan double).
class ProductPrice {
  final int? id;
  final int productId;
  final int sellingPrice;
  final String effectiveFrom;
  final String createdAt;

  const ProductPrice({
    this.id,
    required this.productId,
    required this.sellingPrice,
    required this.effectiveFrom,
    required this.createdAt,
  });

  /// Format harga jual ke standar Rupiah (misal "Rp3.000").
  String get formattedSellingPrice => CurrencyFormatter.formatRupiah(sellingPrice);

  /// Membuat instance [ProductPrice] dari Map SQLite.
  factory ProductPrice.fromMap(Map<String, dynamic> map) {
    return ProductPrice(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      sellingPrice: map['selling_price'] as int,
      effectiveFrom: map['effective_from'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'product_id': productId,
      'selling_price': sellingPrice,
      'effective_from': effectiveFrom,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  ProductPrice copyWith({
    int? id,
    int? productId,
    int? sellingPrice,
    String? effectiveFrom,
    String? createdAt,
  }) {
    return ProductPrice(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductPrice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          sellingPrice == other.sellingPrice &&
          effectiveFrom == other.effectiveFrom &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      productId.hashCode ^
      sellingPrice.hashCode ^
      effectiveFrom.hashCode ^
      createdAt.hashCode;
}

