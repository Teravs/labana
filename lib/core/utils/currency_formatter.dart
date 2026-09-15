/// Utility pembantu untuk pemformatan mata uang Rupiah dan harga per satuan dasar.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format angka integer menjadi format Rupiah standar Indonesia.
  /// Contoh: 20000 -> "Rp20.000", 0 -> "Rp0", 1500 -> "Rp1.500".
  static String formatRupiah(int amount) {
    final isNegative = amount < 0;
    final absValue = amount.abs().toString();

    final buffer = StringBuffer();
    final length = absValue.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(absValue[i]);
    }

    final formatted = buffer.toString();
    return isNegative ? '-Rp$formatted' : 'Rp$formatted';
  }

  /// Format biaya per satuan dasar, menjaga presisi desimal tanpa pembulatan prematur.
  /// Contoh:
  /// - (20.0, 'g') -> "Rp20/g"
  /// - (4.2, 'ml') -> "Rp4,2/ml"
  /// - (200.0, 'pcs') -> "Rp200/pcs"
  static String formatCostPerBaseUnit(double cost, String baseUnit) {
    if (cost.isNaN || cost.isInfinite) {
      return 'Rp0/$baseUnit';
    }

    if (cost % 1 == 0) {
      return '${formatRupiah(cost.toInt())}/$baseUnit';
    }

    // Jika ada desimal, format dengan maksimal 2 angka desimal dan gunakan koma
    // Jika angka sangat kecil (< 0.01), tampilkan hingga 4 angka desimal
    final maxDecimals = cost < 0.01 ? 4 : 2;
    var strVal = cost.toStringAsFixed(maxDecimals);

    // Hapus trailing zeros setelah titik
    if (strVal.contains('.')) {
      strVal = strVal.replaceAll(RegExp(r'0+$'), '');
      if (strVal.endsWith('.')) {
        strVal = strVal.substring(0, strVal.length - 1);
      }
    }

    // Pisahkan integer dan pecahan
    final parts = strVal.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    final intFormatted = formatRupiah(intPart);
    final decimalPart = parts.length > 1 ? parts[1] : '';

    if (decimalPart.isEmpty) {
      return '$intFormatted/$baseUnit';
    }

    return '$intFormatted,$decimalPart/$baseUnit';
  }
}
