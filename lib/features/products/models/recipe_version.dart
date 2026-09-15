import '../../../core/utils/currency_formatter.dart';

/// Model data untuk tabel `recipe_versions`.
///
/// Menyimpan data versi resep untuk suatu produk.
/// Versi resep bersifat historis (append-only saat resep diubah).
class RecipeVersion {
  final int? id;
  final int productId;
  final int versionNumber;
  final String effectiveFrom;
  final int hppTotal;
  final String status;
  final String createdAt;

  const RecipeVersion({
    this.id,
    required this.productId,
    required this.versionNumber,
    required this.effectiveFrom,
    this.hppTotal = 0,
    this.status = 'active',
    required this.createdAt,
  });

  /// Helper untuk status draft.
  bool get isDraft => status == 'draft';

  /// Helper untuk status active.
  bool get isActive => status == 'active';

  /// Helper untuk status archived.
  bool get isArchived => status == 'archived';

  /// Format HPP total ke standar Rupiah (misal "Rp2.100").
  String get formattedHppTotal => CurrencyFormatter.formatRupiah(hppTotal);

  /// Label versi resep (misal "Resep v1", "Resep v2").
  String get versionLabel => 'Resep v$versionNumber';

  /// Membuat instance [RecipeVersion] dari Map SQLite.
  factory RecipeVersion.fromMap(Map<String, dynamic> map) {
    return RecipeVersion(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      versionNumber: map['version_number'] as int,
      effectiveFrom: map['effective_from'] as String,
      hppTotal: map['hpp_total'] as int? ?? 0,
      status: map['status'] as String? ?? 'draft',
      createdAt: map['created_at'] as String,
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'product_id': productId,
      'version_number': versionNumber,
      'effective_from': effectiveFrom,
      'hpp_total': hppTotal,
      'status': status,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  RecipeVersion copyWith({
    int? id,
    int? productId,
    int? versionNumber,
    String? effectiveFrom,
    int? hppTotal,
    String? status,
    String? createdAt,
  }) {
    return RecipeVersion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      versionNumber: versionNumber ?? this.versionNumber,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      hppTotal: hppTotal ?? this.hppTotal,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeVersion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productId == other.productId &&
          versionNumber == other.versionNumber &&
          effectiveFrom == other.effectiveFrom &&
          hppTotal == other.hppTotal &&
          status == other.status &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      productId.hashCode ^
      versionNumber.hashCode ^
      effectiveFrom.hashCode ^
      hppTotal.hashCode ^
      status.hashCode ^
      createdAt.hashCode;
}
