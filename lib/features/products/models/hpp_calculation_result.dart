import '../../../core/utils/currency_formatter.dart';

/// Rincian biaya untuk satu item komponen dalam kalkulasi HPP.
class HppCalculationItem {
  final String componentType; // 'ingredient', 'processed', 'other'
  final int? componentId; // ingredientId atau childProcessedId
  final String label;
  final double? quantity;
  final String? unit;
  final double unitCost; // Biaya per satuan dasar
  final double totalCost; // Biaya kontribusi dengan precision internal (double)
  final int roundedCost; // Biaya kontribusi dibulatkan ke integer Rupiah
  final bool isResolvable;
  final String? errorMessage;
  final int? effectivePriceId;
  final String? effectivePriceDate;

  const HppCalculationItem({
    required this.componentType,
    this.componentId,
    required this.label,
    this.quantity,
    this.unit,
    required this.unitCost,
    required this.totalCost,
    required this.roundedCost,
    required this.isResolvable,
    this.errorMessage,
    this.effectivePriceId,
    this.effectivePriceDate,
  });

  /// Helper untuk memeriksa apakah komponen merupakan bahan mentah.
  bool get isIngredient => componentType == 'ingredient';

  /// Helper untuk memeriksa apakah komponen merupakan bahan olahan.
  bool get isProcessed => componentType == 'processed';

  /// Helper untuk memeriksa apakah komponen merupakan biaya lainnya.
  bool get isOther => componentType == 'other';

  /// Format kuantitas pemakaian ramah pengguna (misal "5 g", "30 ml").
  String get formattedQuantity {
    if (quantity == null || unit == null) return '-';
    final qtyStr =
        quantity! % 1 == 0
            ? quantity!.toInt().toString()
            : quantity!.toString();
    return '$qtyStr $unit';
  }

  /// Format biaya kontribusi ke Rupiah integer.
  String get formattedCost => CurrencyFormatter.formatRupiah(roundedCost);
}

/// Hasil kalkulasi HPP produk yang deterministik dan immutable berbasis tanggal efektif.
///
/// Memisahkan komputasi murni dari persistence/database sehingga dapat digunakan
/// langsung oleh fitur Penjualan maupun preview kalkulasi.
class HppCalculationResult {
  final int productId;
  final String productName;
  final String calculationDate; // Format 'YYYY-MM-DD'

  final int recipeVersionId;
  final int recipeVersionNumber;

  /// Total HPP dalam integer Rupiah (hasil pembulatan dari [preciseHppTotal]).
  final int hppTotal;

  /// Total akumulasi biaya komponen dengan presisi internal (double).
  final double preciseHppTotal;

  /// Harga jual produk yang efektif pada [calculationDate].
  /// Bernilai `null` jika belum ada riwayat harga jual yang berlaku.
  final int? sellingPrice;

  /// Estimasi Laba: `sellingPrice - hppTotal`.
  /// Bernilai `null` jika [sellingPrice] tidak tersedia.
  final int? profit;

  /// Persentase margin laba: `(profit / sellingPrice) * 100`.
  /// Bernilai `null` jika [sellingPrice] tidak tersedia.
  final double? marginPercentage;

  /// Menandakan apakah harga jual berada di bawah HPP (`sellingPrice < hppTotal`).
  final bool isBelowHpp;

  /// Rincian perhitungan untuk setiap item komponen resep.
  final List<HppCalculationItem> items;

  /// Menandakan jika terdapat komponen yang belum memiliki harga atau belum dapat dihitung.
  final bool hasUnresolvedCost;

  /// Daftar pesan peringatan jika terdapat biaya yang belum lengkap.
  final List<String> warnings;

  const HppCalculationResult({
    required this.productId,
    required this.productName,
    required this.calculationDate,
    required this.recipeVersionId,
    required this.recipeVersionNumber,
    required this.hppTotal,
    required this.preciseHppTotal,
    this.sellingPrice,
    this.profit,
    this.marginPercentage,
    required this.isBelowHpp,
    required this.items,
    required this.hasUnresolvedCost,
    required this.warnings,
  });

  /// Menandakan apakah hasil kalkulasi HPP ini valid secara penuh (tidak ada komponen unresolved).
  bool get isValid => !hasUnresolvedCost;

  /// Format HPP total ke standar Rupiah (misal "Rp1.340").
  String get formattedHppTotal => CurrencyFormatter.formatRupiah(hppTotal);

  /// Format harga jual ke standar Rupiah, atau '-' jika belum ditentukan.
  String get formattedSellingPrice =>
      sellingPrice != null ? CurrencyFormatter.formatRupiah(sellingPrice!) : '-';

  /// Format estimasi laba ke standar Rupiah, atau '-' jika harga jual belum ditentukan.
  String get formattedProfit =>
      profit != null ? CurrencyFormatter.formatRupiah(profit!) : '-';

  /// Format persentase margin laba (misal "73.2%"), atau '-' jika harga jual belum ditentukan.
  String get formattedMargin =>
      marginPercentage != null
          ? '${marginPercentage!.toStringAsFixed(1)}%'
          : '-';

  /// Label versi resep (misal "Resep v1").
  String get recipeVersionLabel => 'Resep v$recipeVersionNumber';
}

