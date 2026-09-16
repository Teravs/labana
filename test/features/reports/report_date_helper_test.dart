import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/reports/models/report_models.dart';
import 'package:labana/features/reports/services/report_date_helper.dart';

void main() {
  group('ReportDateHelper Tests', () {
    test('formatDate menghasilkan format YYYY-MM-DD', () {
      final dt = DateTime(2026, 9, 16, 14, 30);
      expect(ReportDateHelper.formatDate(dt), '2026-09-16');
    });

    test('parseDate mengurai string YYYY-MM-DD dengan benar', () {
      final dt = ReportDateHelper.parseDate('2026-09-16');
      expect(dt.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 16);
    });

    test('getWeekRange menghasilkan Senin s/d Minggu yang memuat tanggal acuan', () {
      // Rabu, 16 September 2026
      final wednesday = DateTime(2026, 9, 16);
      final range = ReportDateHelper.getWeekRange(wednesday);

      expect(range.start.year, 2026);
      expect(range.start.month, 9);
      expect(range.start.day, 14); // Senin
      expect(range.start.weekday, DateTime.monday);

      expect(range.end.year, 2026);
      expect(range.end.month, 9);
      expect(range.end.day, 20); // Minggu
      expect(range.end.weekday, DateTime.sunday);
    });

    test('getWeekRange pada hari Senin menghasilkan awal minggu hari itu sendiri', () {
      final monday = DateTime(2026, 9, 14);
      final range = ReportDateHelper.getWeekRange(monday);

      expect(range.start.day, 14);
      expect(range.end.day, 20);
    });

    test('getWeekRange pada hari Minggu menghasilkan akhir minggu hari itu sendiri', () {
      final sunday = DateTime(2026, 9, 20);
      final range = ReportDateHelper.getWeekRange(sunday);

      expect(range.start.day, 14);
      expect(range.end.day, 20);
    });

    test('getMonthRange menghasilkan hari pertama dan terakhir bulan dengan tepat', () {
      // September (30 hari)
      final sep = ReportDateHelper.getMonthRange(2026, 9);
      expect(sep.start.day, 1);
      expect(sep.end.day, 30);

      // Oktober (31 hari)
      final okt = ReportDateHelper.getMonthRange(2026, 10);
      expect(okt.start.day, 1);
      expect(okt.end.day, 31);

      // Februari tahun bukan kabisat (2025: 28 hari)
      final feb2025 = ReportDateHelper.getMonthRange(2025, 2);
      expect(feb2025.start.day, 1);
      expect(feb2025.end.day, 28);

      // Februari tahun kabisat (2024: 29 hari)
      final feb2024 = ReportDateHelper.getMonthRange(2024, 2);
      expect(feb2024.start.day, 1);
      expect(feb2024.end.day, 29);
    });

    test('getDaysInRange mengembalikan seluruh tanggal inklusif', () {
      final start = DateTime(2026, 9, 14);
      final end = DateTime(2026, 9, 20);
      final days = ReportDateHelper.getDaysInRange(start, end);

      expect(days.length, 7);
      expect(days.first.day, 14);
      expect(days.last.day, 20);
    });

    test('getPreviousPeriod dan getNextPeriod bekerja pada setiap tipe periode', () {
      final base = DateTime(2026, 9, 16);

      // Daily: mundur/maju 1 hari
      expect(
        ReportDateHelper.getPreviousPeriod(ReportPeriodType.daily, base).day,
        15,
      );
      expect(
        ReportDateHelper.getNextPeriod(ReportPeriodType.daily, base).day,
        17,
      );

      // Weekly: mundur/maju 7 hari
      expect(
        ReportDateHelper.getPreviousPeriod(ReportPeriodType.weekly, base).day,
        9,
      );
      expect(
        ReportDateHelper.getNextPeriod(ReportPeriodType.weekly, base).day,
        23,
      );

      // Monthly: mundur/maju 1 bulan
      expect(
        ReportDateHelper.getPreviousPeriod(ReportPeriodType.monthly, base).month,
        8,
      );
      expect(
        ReportDateHelper.getNextPeriod(ReportPeriodType.monthly, base).month,
        10,
      );
    });

    test('formatPeriodLabel memformat label bahasa Indonesia dengan benar', () {
      final dt = DateTime(2026, 9, 16);

      // Daily
      expect(
        ReportDateHelper.formatPeriodLabel(ReportPeriodType.daily, dt),
        '16 September 2026',
      );

      // Weekly dalam bulan yang sama
      expect(
        ReportDateHelper.formatPeriodLabel(ReportPeriodType.weekly, dt),
        '14–20 Sep 2026',
      );

      // Weekly lintas bulan
      final crossMonth = DateTime(2026, 9, 30); // Rabu
      expect(
        ReportDateHelper.formatPeriodLabel(ReportPeriodType.weekly, crossMonth),
        '28 Sep – 4 Okt 2026',
      );

      // Weekly lintas tahun
      final crossYear = DateTime(2026, 12, 31); // Kamis
      expect(
        ReportDateHelper.formatPeriodLabel(ReportPeriodType.weekly, crossYear),
        '28 Des 2026 – 3 Jan 2027',
      );

      // Monthly
      expect(
        ReportDateHelper.formatPeriodLabel(ReportPeriodType.monthly, dt),
        'September 2026',
      );
    });
  });
}

