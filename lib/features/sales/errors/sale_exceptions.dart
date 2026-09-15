// Domain exceptions untuk modul Penjualan & Transaksi Labana.

/// Dilempar saat validasi transaksi gagal (misal tidak ada item, kuantitas invalid, atau penambahan produk inactive).
class SaleValidationException implements Exception {
  final String message;
  const SaleValidationException(this.message);

  @override
  String toString() => message;
}

/// Dilempar saat transaksi penjualan dengan ID tertentu tidak ditemukan di database.
class SaleNotFoundException implements Exception {
  final int id;
  const SaleNotFoundException(this.id);

  @override
  String toString() => 'Transaksi penjualan dengan ID $id tidak ditemukan.';
}

/// Dilempar saat kalkulasi historis transaksi gagal karena versi resep, harga jual,
/// atau harga bahan mentah belum tersedia pada tanggal transaksi.
class HistoricalCalculationException implements Exception {
  final String message;
  const HistoricalCalculationException(this.message);

  @override
  String toString() => message;
}

/// Dilempar saat pembuatan nomor transaksi unik gagal setelah percobaan ulang maksimal.
class TransactionNumberGenerationException implements Exception {
  final String message;
  const TransactionNumberGenerationException(this.message);

  @override
  String toString() => message;
}
