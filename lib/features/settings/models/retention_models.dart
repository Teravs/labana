/// Model representasi arsip data transaksi per bulan untuk fitur Retensi Data.
class MonthlyArchiveItem {
  final int year;
  final int month;
  final String monthLabel;
  final int transactionCount;
  final double totalOmzet;
  final bool isCurrentMonth;
  final bool isDownloaded;
  final bool needsReDownload;
  final String? downloadedFilePath;

  const MonthlyArchiveItem({
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.transactionCount,
    required this.totalOmzet,
    required this.isCurrentMonth,
    required this.isDownloaded,
    this.needsReDownload = false,
    this.downloadedFilePath,
  });

  /// Status apakah transaksi pada periode ini aman untuk dibersihkan/dihapus.
  bool get canDelete => !isCurrentMonth && isDownloaded && !needsReDownload;

  /// Mengembalikan kunci periode dalam format YYYY-MM (misal: "2026-01").
  String get periodKey =>
      '$year-${month.toString().padLeft(2, '0')}';

  MonthlyArchiveItem copyWith({
    int? year,
    int? month,
    String? monthLabel,
    int? transactionCount,
    double? totalOmzet,
    bool? isCurrentMonth,
    bool? isDownloaded,
    bool? needsReDownload,
    String? downloadedFilePath,
  }) {
    return MonthlyArchiveItem(
      year: year ?? this.year,
      month: month ?? this.month,
      monthLabel: monthLabel ?? this.monthLabel,
      transactionCount: transactionCount ?? this.transactionCount,
      totalOmzet: totalOmzet ?? this.totalOmzet,
      isCurrentMonth: isCurrentMonth ?? this.isCurrentMonth,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      needsReDownload: needsReDownload ?? this.needsReDownload,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
    );
  }
}

/// Exception domain untuk operasi retensi data transaksi.
class RetentionException implements Exception {
  final String message;
  const RetentionException(this.message);

  @override
  String toString() => message;
}
