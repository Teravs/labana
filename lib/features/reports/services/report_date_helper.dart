import '../models/report_models.dart';

/// Helper penanggalan untuk laporan penjualan (Harian, Mingguan, Bulanan)
/// dengan standar waktu lokal perangkat dan konvensi bahasa Indonesia.
class ReportDateHelper {
  ReportDateHelper._();

  static const List<String> monthNamesFull = [
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

  static const List<String> monthNamesShort = [
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

  static const List<String> dayNamesFull = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Mengonversi [DateTime] menjadi string tanggal lokal `YYYY-MM-DD`.
  static String formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Mem-parsing string `YYYY-MM-DD` menjadi [DateTime] waktu lokal (jam 00:00:00).
  static DateTime parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      final y = int.tryParse(parts[0]) ?? 2026;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return DateTime(y, m, d);
    }
    return DateTime.parse(dateStr);
  }

  /// Mengambil rentang tanggal mingguan (Senin s/d Minggu) yang memuat [date].
  static ({DateTime start, DateTime end}) getWeekRange(DateTime date) {
    // Di Dart: 1 = Senin, ..., 7 = Minggu
    final cleanDate = DateTime(date.year, date.month, date.day);
    final monday = cleanDate.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return (start: monday, end: sunday);
  }

  /// Mengambil rentang tanggal bulanan (Hari ke-1 s/d Hari Terakhir) untuk [year] dan [month].
  ///
  /// Menangani kabisat (*leap year*) dan jumlah hari 28, 29, 30, 31 secara otomatis.
  static ({DateTime start, DateTime end}) getMonthRange(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    // Hari ke-0 pada bulan berikutnya mengembalikan hari terakhir bulan ini
    final lastDay = DateTime(year, month + 1, 0);
    return (start: firstDay, end: lastDay);
  }

  /// Menghasilkan daftar seluruh tanggal berurutan dalam rentang [start] s/d [end] inklusif.
  static List<DateTime> getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(cleanEnd)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  /// Mengembalikan tanggal acuan untuk periode sebelumnya.
  static DateTime getPreviousPeriod(
    ReportPeriodType type,
    DateTime referenceDate,
  ) {
    final clean = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    switch (type) {
      case ReportPeriodType.daily:
        return clean.subtract(const Duration(days: 1));
      case ReportPeriodType.weekly:
        return clean.subtract(const Duration(days: 7));
      case ReportPeriodType.monthly:
        return DateTime(clean.year, clean.month - 1, 1);
    }
  }

  /// Mengembalikan tanggal acuan untuk periode berikutnya.
  static DateTime getNextPeriod(ReportPeriodType type, DateTime referenceDate) {
    final clean = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    switch (type) {
      case ReportPeriodType.daily:
        return clean.add(const Duration(days: 1));
      case ReportPeriodType.weekly:
        return clean.add(const Duration(days: 7));
      case ReportPeriodType.monthly:
        return DateTime(clean.year, clean.month + 1, 1);
    }
  }

  /// Menghasilkan pasangan rentang string `YYYY-MM-DD` untuk tipe periode yang dipilih.
  static ({String startDate, String endDate}) getPeriodRangeStrings(
    ReportPeriodType type,
    DateTime referenceDate,
  ) {
    switch (type) {
      case ReportPeriodType.daily:
        final dateStr = formatDate(referenceDate);
        return (startDate: dateStr, endDate: dateStr);
      case ReportPeriodType.weekly:
        final range = getWeekRange(referenceDate);
        return (
          startDate: formatDate(range.start),
          endDate: formatDate(range.end),
        );
      case ReportPeriodType.monthly:
        final range = getMonthRange(referenceDate.year, referenceDate.month);
        return (
          startDate: formatDate(range.start),
          endDate: formatDate(range.end),
        );
    }
  }

  /// Format label tampilan periode untuk bar navigasi.
  ///
  /// Contoh:
  /// - Daily: `"15 September 2026"`
  /// - Weekly (bulan sama): `"14–20 Sep 2026"`
  /// - Weekly (lintas bulan): `"28 Sep – 4 Okt 2026"`
  /// - Weekly (lintas tahun): `"28 Des 2026 – 3 Jan 2027"`
  /// - Monthly: `"September 2026"`
  static String formatPeriodLabel(
    ReportPeriodType type,
    DateTime referenceDate,
  ) {
    switch (type) {
      case ReportPeriodType.daily:
        final day = referenceDate.day;
        final month = monthNamesFull[referenceDate.month - 1];
        final year = referenceDate.year;
        return '$day $month $year';

      case ReportPeriodType.weekly:
        final range = getWeekRange(referenceDate);
        final start = range.start;
        final end = range.end;

        final startMonth = monthNamesShort[start.month - 1];
        final endMonth = monthNamesShort[end.month - 1];

        if (start.year != end.year) {
          return '${start.day} $startMonth ${start.year} – ${end.day} $endMonth ${end.year}';
        } else if (start.month != end.month) {
          return '${start.day} $startMonth – ${end.day} $endMonth ${end.year}';
        } else {
          return '${start.day}–${end.day} $endMonth ${end.year}';
        }

      case ReportPeriodType.monthly:
        final month = monthNamesFull[referenceDate.month - 1];
        final year = referenceDate.year;
        return '$month $year';
    }
  }
}
