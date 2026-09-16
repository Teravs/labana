import '../../../core/utils/currency_formatter.dart';

/// Model representasi ringkasan finansial dan transaksi harian dashboard.
class DashboardSummary {
  final int totalOmzet;
  final int totalHpp;
  final int totalProfit;
  final int transactionCount;
  final double productsSold;

  const DashboardSummary({
    this.totalOmzet = 0,
    this.totalHpp = 0,
    this.totalProfit = 0,
    this.transactionCount = 0,
    this.productsSold = 0.0,
  });

  /// Format Rupiah total omzet hari ini (misal "Rp10.000" atau "Rp0").
  String get formattedTotalOmzet => CurrencyFormatter.formatRupiah(totalOmzet);

  /// Format Rupiah total modal/HPP hari ini (misal "Rp2.680" atau "Rp0").
  String get formattedTotalHpp => CurrencyFormatter.formatRupiah(totalHpp);

  /// Format Rupiah estimasi laba hari ini (misal "Rp7.320" atau "-Rp5.000").
  String get formattedTotalProfit =>
      CurrencyFormatter.formatRupiah(totalProfit);

  /// Format kuantitas produk terjual tanpa desimal berlebih (misal "12" atau "12,5").
  String get formattedProductsSold {
    if (productsSold % 1 == 0) {
      return productsSold.toInt().toString();
    }
    var str = productsSold.toStringAsFixed(2);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '');
      if (str.endsWith('.')) str = str.substring(0, str.length - 1);
    }
    return str.replaceAll('.', ',');
  }

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalOmzet: (map['total_omzet'] as num?)?.toInt() ?? 0,
      totalHpp: (map['total_hpp'] as num?)?.toInt() ?? 0,
      totalProfit: (map['total_profit'] as num?)?.toInt() ?? 0,
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      productsSold: (map['products_sold'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DashboardSummary copyWith({
    int? totalOmzet,
    int? totalHpp,
    int? totalProfit,
    int? transactionCount,
    double? productsSold,
  }) {
    return DashboardSummary(
      totalOmzet: totalOmzet ?? this.totalOmzet,
      totalHpp: totalHpp ?? this.totalHpp,
      totalProfit: totalProfit ?? this.totalProfit,
      transactionCount: transactionCount ?? this.transactionCount,
      productsSold: productsSold ?? this.productsSold,
    );
  }
}

/// Model statistik performa produk untuk produk terlaris atau laba tertinggi.
class DashboardProductStat {
  final int productId;
  final String productName;
  final double quantity;
  final int profit;

  const DashboardProductStat({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.profit,
  });

  /// Format Rupiah total profit produk (misal "Rp35.000" atau "-Rp5.000").
  String get formattedProfit => CurrencyFormatter.formatRupiah(profit);

  /// Format kuantitas produk terjual (misal "10" atau "2,5").
  String get formattedQuantity {
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    var str = quantity.toStringAsFixed(2);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '');
      if (str.endsWith('.')) str = str.substring(0, str.length - 1);
    }
    return str.replaceAll('.', ',');
  }

  factory DashboardProductStat.fromMap(Map<String, dynamic> map) {
    return DashboardProductStat(
      productId: (map['product_id'] as num).toInt(),
      productName: (map['product_name'] as String?) ?? '',
      quantity: (map['total_quantity'] as num?)?.toDouble() ?? 0.0,
      profit: (map['total_profit'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Agregasi lengkap seluruh data dashboard untuk satu tanggal tertentu.
class DashboardData {
  final String date;
  final DashboardSummary summary;
  final DashboardProductStat? topSelling;
  final DashboardProductStat? highestProfit;

  const DashboardData({
    required this.date,
    required this.summary,
    this.topSelling,
    this.highestProfit,
  });

  /// Menandakan apakah tidak ada transaksi sama sekali pada tanggal ini.
  bool get isEmpty => summary.transactionCount == 0;

  factory DashboardData.empty(String date) {
    return DashboardData(
      date: date,
      summary: const DashboardSummary(),
      topSelling: null,
      highestProfit: null,
    );
  }
}
