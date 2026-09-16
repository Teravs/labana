import '../../../core/utils/currency_formatter.dart';

/// Jenis periode laporan penjualan.
enum ReportPeriodType {
  daily('Hari'),
  weekly('Minggu'),
  monthly('Bulan');

  final String label;
  const ReportPeriodType(this.label);
}

/// Model ringkasan finansial dan operasional laporan penjualan.
class ReportSummary {
  final int totalOmzet;
  final int totalHpp;
  final int totalProfit;
  final int transactionCount;
  final double productsSold;

  const ReportSummary({
    this.totalOmzet = 0,
    this.totalHpp = 0,
    this.totalProfit = 0,
    this.transactionCount = 0,
    this.productsSold = 0.0,
  });

  /// Format Rupiah total omzet (misal "Rp125.000").
  String get formattedTotalOmzet => CurrencyFormatter.formatRupiah(totalOmzet);

  /// Format Rupiah total modal / HPP (misal "Rp33.500").
  String get formattedTotalHpp => CurrencyFormatter.formatRupiah(totalHpp);

  /// Format Rupiah estimasi laba (misal "Rp91.500" atau "-Rp5.000").
  String get formattedTotalProfit =>
      CurrencyFormatter.formatRupiah(totalProfit);

  /// Format kuantitas produk terjual (misal "25" atau "25,5").
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

  /// Persentase margin laba terhadap total omzet (0.0 - 100.0).
  double get profitMarginPercent {
    if (totalOmzet <= 0) return 0.0;
    return (totalProfit / totalOmzet) * 100;
  }

  /// String persentase margin laba (misal "68%").
  String get formattedProfitMargin =>
      '${profitMarginPercent.toStringAsFixed(0)}%';

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      totalOmzet: (map['total_omzet'] as num?)?.toInt() ?? 0,
      totalHpp: (map['total_hpp'] as num?)?.toInt() ?? 0,
      totalProfit: (map['total_profit'] as num?)?.toInt() ?? 0,
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      productsSold: (map['products_sold'] as num?)?.toDouble() ?? 0.0,
    );
  }

  ReportSummary copyWith({
    int? totalOmzet,
    int? totalHpp,
    int? totalProfit,
    int? transactionCount,
    double? productsSold,
  }) {
    return ReportSummary(
      totalOmzet: totalOmzet ?? this.totalOmzet,
      totalHpp: totalHpp ?? this.totalHpp,
      totalProfit: totalProfit ?? this.totalProfit,
      transactionCount: transactionCount ?? this.transactionCount,
      productsSold: productsSold ?? this.productsSold,
    );
  }
}

/// Model agregasi performa per produk dalam laporan.
class ReportProductStat {
  final int productId;
  final String productName;
  final double quantity;
  final int omzet;
  final int hpp;
  final int profit;

  const ReportProductStat({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.omzet,
    required this.hpp,
    required this.profit,
  });

  /// Format kuantitas terjual (misal "25" atau "2,5").
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

  /// Format Rupiah omzet produk.
  String get formattedOmzet => CurrencyFormatter.formatRupiah(omzet);

  /// Format Rupiah total HPP produk.
  String get formattedHpp => CurrencyFormatter.formatRupiah(hpp);

  /// Format Rupiah total laba produk.
  String get formattedProfit => CurrencyFormatter.formatRupiah(profit);

  factory ReportProductStat.fromMap(Map<String, dynamic> map) {
    return ReportProductStat(
      productId: (map['product_id'] as num).toInt(),
      productName: (map['product_name'] as String?) ?? '',
      quantity: (map['total_quantity'] as num?)?.toDouble() ?? 0.0,
      omzet: (map['total_omzet'] as num?)?.toInt() ?? 0,
      hpp: (map['total_hpp'] as num?)?.toInt() ?? 0,
      profit: (map['total_profit'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model agregasi performa harian untuk breakdown mingguan atau bulanan.
class DailyReportStat {
  final String dateStr;
  final int omzet;
  final int hpp;
  final int profit;
  final int transactionCount;
  final double productsSold;

  const DailyReportStat({
    required this.dateStr,
    this.omzet = 0,
    this.hpp = 0,
    this.profit = 0,
    this.transactionCount = 0,
    this.productsSold = 0.0,
  });

  /// Format Rupiah omzet harian.
  String get formattedOmzet => CurrencyFormatter.formatRupiah(omzet);

  /// Format Rupiah HPP harian.
  String get formattedHpp => CurrencyFormatter.formatRupiah(hpp);

  /// Format Rupiah laba harian.
  String get formattedProfit => CurrencyFormatter.formatRupiah(profit);

  /// Format kuantitas produk terjual harian.
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

  /// Format tanggal singkat untuk timeline (misal: "Sen, 14 Sep" atau "14 Sep").
  String get formattedDateDisplay {
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return dateStr;
      final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final dayName = days[parsed.weekday - 1];
      final monthName = months[parsed.month - 1];
      return '$dayName, ${parsed.day} $monthName';
    } catch (_) {
      return dateStr;
    }
  }

  /// Format tanggal kalender singkat saja (misal "14 Sep").
  String get formattedShortDate {
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return dateStr;
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${parsed.day} ${months[parsed.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  factory DailyReportStat.fromMap(Map<String, dynamic> map) {
    return DailyReportStat(
      dateStr: (map['date_str'] as String?) ?? '',
      omzet: (map['total_omzet'] as num?)?.toInt() ?? 0,
      hpp: (map['total_hpp'] as num?)?.toInt() ?? 0,
      profit: (map['total_profit'] as num?)?.toInt() ?? 0,
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      productsSold: (map['products_sold'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Model agregasi metode pembayaran (Tunai, QRIS, Transfer).
class PaymentMethodStat {
  final String paymentMethod;
  final int transactionCount;
  final int totalAmount;

  const PaymentMethodStat({
    required this.paymentMethod,
    required this.transactionCount,
    required this.totalAmount,
  });

  /// Label bahasa Indonesia metode pembayaran.
  String get paymentMethodLabel {
    switch (paymentMethod.toLowerCase()) {
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'cash':
      default:
        return 'Tunai';
    }
  }

  /// Format Rupiah total omzet per metode pembayaran.
  String get formattedTotalAmount =>
      CurrencyFormatter.formatRupiah(totalAmount);

  factory PaymentMethodStat.fromMap(Map<String, dynamic> map) {
    return PaymentMethodStat(
      paymentMethod: (map['payment_method'] as String?) ?? 'cash',
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Agregasi lengkap seluruh data laporan untuk suatu periode tertentu.
class ReportData {
  final ReportPeriodType periodType;
  final String startDate;
  final String endDate;
  final ReportSummary summary;
  final List<ReportProductStat> products;
  final ReportProductStat? topSelling;
  final ReportProductStat? highestProfit;
  final List<DailyReportStat> dailyBreakdown;
  final List<PaymentMethodStat> paymentMethods;

  const ReportData({
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.summary,
    this.products = const [],
    this.topSelling,
    this.highestProfit,
    this.dailyBreakdown = const [],
    this.paymentMethods = const [],
  });

  /// Menandakan apakah tidak ada transaksi sama sekali pada periode ini.
  bool get isEmpty => summary.transactionCount == 0;

  factory ReportData.empty({
    required ReportPeriodType periodType,
    required String startDate,
    required String endDate,
  }) {
    return ReportData(
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
      summary: const ReportSummary(),
      products: const [],
      topSelling: null,
      highestProfit: null,
      dailyBreakdown: const [],
      paymentMethods: const [],
    );
  }
}

