import '../../../core/utils/currency_formatter.dart';
import 'sale_item.dart';

/// Model representasi transaksi penjualan (`sales`).
class Sale {
  static const String paymentCash = 'cash';
  static const String paymentQris = 'qris';
  static const String paymentTransfer = 'transfer';

  final int? id;
  final String transactionNumber;
  final String transactionDate;
  final String paymentMethod;
  final int totalAmount;
  final int totalHpp;
  final int totalProfit;
  final String createdAt;
  final String updatedAt;

  /// Transient: daftar item transaksi jika dimuat bersamaan.
  final List<SaleItem>? items;

  /// Transient: jumlah produk/item hasil query agregasi `LEFT JOIN`.
  final int? itemCount;

  const Sale({
    this.id,
    required this.transactionNumber,
    required this.transactionDate,
    this.paymentMethod = paymentCash,
    required this.totalAmount,
    required this.totalHpp,
    required this.totalProfit,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.itemCount,
  });

  /// Mengonversi kode payment_method ke label bahasa Indonesia.
  String get paymentMethodLabel {
    switch (paymentMethod) {
      case paymentQris:
        return 'QRIS';
      case paymentTransfer:
        return 'Transfer';
      case paymentCash:
      default:
        return 'Tunai';
    }
  }

  /// Mengonversi label bahasa Indonesia ke kode payment_method database.
  static String methodCodeFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'qris':
        return paymentQris;
      case 'transfer':
        return paymentTransfer;
      case 'tunai':
      default:
        return paymentCash;
    }
  }

  /// Format total omzet transaksi (misal "Rp15.000").
  String get formattedTotalAmount =>
      CurrencyFormatter.formatRupiah(totalAmount);

  /// Format total HPP transaksi (misal "Rp4.530").
  String get formattedTotalHpp => CurrencyFormatter.formatRupiah(totalHpp);

  /// Format total laba transaksi (misal "Rp10.470" atau "-Rp500").
  String get formattedTotalProfit =>
      CurrencyFormatter.formatRupiah(totalProfit);

  /// Mengambil bagian tanggal saja (`YYYY-MM-DD`).
  String get dateOnly {
    return transactionDate.length >= 10
        ? transactionDate.substring(0, 10)
        : transactionDate;
  }

  /// Format tanggal dan waktu ringkas untuk card daftar (misal "15 Sep 2026 • 13:25").
  String get formattedDateTime {
    try {
      final parsed = DateTime.tryParse(transactionDate.replaceFirst(' ', 'T'));
      if (parsed == null) return transactionDate;
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
      final month = months[parsed.month - 1];
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '${parsed.day} $month ${parsed.year} • $hour:$minute';
    } catch (_) {
      return transactionDate;
    }
  }

  /// Format tanggal lengkap untuk detail screen (misal "15 September 2026").
  String get formattedDateFull {
    try {
      final parsed = DateTime.tryParse(transactionDate.replaceFirst(' ', 'T'));
      if (parsed == null) return transactionDate;
      final months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      final month = months[parsed.month - 1];
      return '${parsed.day} $month ${parsed.year}';
    } catch (_) {
      return transactionDate;
    }
  }

  /// Format waktu saja (misal "13:25").
  String get formattedTime {
    try {
      final parsed = DateTime.tryParse(transactionDate.replaceFirst(' ', 'T'));
      if (parsed == null) return '';
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  /// Membuat instance [Sale] dari Map SQLite.
  factory Sale.fromMap(Map<String, dynamic> map, {List<SaleItem>? items}) {
    return Sale(
      id: map['id'] as int?,
      transactionNumber: map['transaction_number'] as String,
      transactionDate: map['transaction_date'] as String,
      paymentMethod: (map['payment_method'] as String?) ?? paymentCash,
      totalAmount: (map['total_amount'] as num).toInt(),
      totalHpp: (map['total_hpp'] as num).toInt(),
      totalProfit: (map['total_profit'] as num).toInt(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      items: items,
      itemCount: (map['item_count'] as num?)?.toInt(),
    );
  }

  /// Mengonversi ke Map SQLite untuk penyimpanan.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'transaction_number': transactionNumber,
      'transaction_date': transactionDate,
      'payment_method': paymentMethod,
      'total_amount': totalAmount,
      'total_hpp': totalHpp,
      'total_profit': totalProfit,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Membuat salinan objek dengan modifikasi field tertentu.
  Sale copyWith({
    int? id,
    String? transactionNumber,
    String? transactionDate,
    String? paymentMethod,
    int? totalAmount,
    int? totalHpp,
    int? totalProfit,
    String? createdAt,
    String? updatedAt,
    List<SaleItem>? items,
    int? itemCount,
  }) {
    return Sale(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      transactionDate: transactionDate ?? this.transactionDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      totalAmount: totalAmount ?? this.totalAmount,
      totalHpp: totalHpp ?? this.totalHpp,
      totalProfit: totalProfit ?? this.totalProfit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}
