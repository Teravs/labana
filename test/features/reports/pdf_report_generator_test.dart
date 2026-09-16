import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/reports/models/report_models.dart';
import 'package:labana/features/reports/services/pdf_report_generator.dart';

void main() {
  const generator = PdfReportGenerator();

  group('PdfReportGenerator Tests', () {
    test('1. Laporan kosong menghasilkan file PDF valid dengan bytes > 0 tanpa melempar exception', () async {
      final emptyData = ReportData.empty(
        periodType: ReportPeriodType.daily,
        startDate: '2026-09-16',
        endDate: '2026-09-16',
      );

      final bytes = await generator.generateReportPdf(emptyData);

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      // Validasi PDF signature (%PDF-)
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('2. Laporan harian dengan data lengkap berhasil digenerate', () async {
      const summary = ReportSummary(
        totalOmzet: 75000,
        totalHpp: 25000,
        totalProfit: 50000,
        transactionCount: 5,
        productsSold: 15.0,
      );

      const p1 = ReportProductStat(
        productId: 1,
        productName: 'Es Teh Manis',
        quantity: 10.0,
        omzet: 50000,
        hpp: 15000,
        profit: 35000,
      );

      const p2 = ReportProductStat(
        productId: 2,
        productName: 'Es Jeruk Segar',
        quantity: 5.0,
        omzet: 25000,
        hpp: 10000,
        profit: 15000,
      );

      const m1 = PaymentMethodStat(
        paymentMethod: 'cash',
        transactionCount: 3,
        totalAmount: 45000,
      );
      const m2 = PaymentMethodStat(
        paymentMethod: 'qris',
        transactionCount: 2,
        totalAmount: 30000,
      );

      const dailyData = ReportData(
        periodType: ReportPeriodType.daily,
        startDate: '2026-09-16',
        endDate: '2026-09-16',
        summary: summary,
        products: [p1, p2],
        topSelling: p1,
        highestProfit: p1,
        dailyBreakdown: [],
        paymentMethods: [m1, m2],
      );

      final bytes = await generator.generateReportPdf(dailyData);

      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('3. Laporan mingguan dengan 7 hari timeline breakdown berhasil digenerate', () async {
      final dailyList = List<DailyReportStat>.generate(7, (i) {
        final day = (14 + i).toString().padLeft(2, '0');
        final hasTrx = i % 2 == 0;
        return DailyReportStat(
          dateStr: '2026-09-$day',
          omzet: hasTrx ? 50000 : 0,
          hpp: hasTrx ? 15000 : 0,
          profit: hasTrx ? 35000 : 0,
          transactionCount: hasTrx ? 3 : 0,
          productsSold: hasTrx ? 8.0 : 0.0,
        );
      });

      final weeklyData = ReportData(
        periodType: ReportPeriodType.weekly,
        startDate: '2026-09-14',
        endDate: '2026-09-20',
        summary: const ReportSummary(
          totalOmzet: 200000,
          totalHpp: 60000,
          totalProfit: 140000,
          transactionCount: 12,
          productsSold: 32.0,
        ),
        products: const [
          ReportProductStat(
            productId: 1,
            productName: 'Es Teh Manis',
            quantity: 32.0,
            omzet: 200000,
            hpp: 60000,
            profit: 140000,
          ),
        ],
        dailyBreakdown: dailyList,
      );

      final bytes = await generator.generateReportPdf(weeklyData);

      expect(bytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('4. Laporan bulanan dengan dataset padat (31 hari + 20 menu) berhasil merender multi-page layout', () async {
      // 31 hari timeline lengkap
      final dailyList = List<DailyReportStat>.generate(31, (i) {
        final day = (1 + i).toString().padLeft(2, '0');
        return DailyReportStat(
          dateStr: '2026-10-$day',
          omzet: 60000 + (i * 2000),
          hpp: 20000 + (i * 500),
          profit: 40000 + (i * 1500),
          transactionCount: 5 + (i % 3),
          productsSold: 12.0 + (i % 5),
        );
      });

      // 20 menu produk untuk memicu perpanjangan halaman ke halaman berikutnya
      final productList = List<ReportProductStat>.generate(20, (i) {
        return ReportProductStat(
          productId: i + 1,
          productName: 'Menu Minuman Segar Spesial Varian ${i + 1}',
          quantity: 15.0 + i,
          omzet: 100000 + (i * 10000),
          hpp: 30000 + (i * 3000),
          profit: 70000 + (i * 7000),
        );
      });

      final monthlyData = ReportData(
        periodType: ReportPeriodType.monthly,
        startDate: '2026-10-01',
        endDate: '2026-10-31',
        summary: const ReportSummary(
          totalOmzet: 2500000,
          totalHpp: 750000,
          totalProfit: 1750000,
          transactionCount: 160,
          productsSold: 420.0,
        ),
        products: productList,
        topSelling: productList.first,
        highestProfit: productList.last,
        dailyBreakdown: dailyList,
        paymentMethods: const [
          PaymentMethodStat(paymentMethod: 'cash', transactionCount: 90, totalAmount: 1400000),
          PaymentMethodStat(paymentMethod: 'qris', transactionCount: 50, totalAmount: 850000),
          PaymentMethodStat(paymentMethod: 'transfer', transactionCount: 20, totalAmount: 250000),
        ],
      );

      final bytes = await generator.generateReportPdf(monthlyData);

      expect(bytes.isNotEmpty, isTrue);
      // Dokumen multi-page dengan banyak tabel memiliki ukuran yang substansial
      expect(bytes.length, greaterThan(10000));
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('5. Nilai profit negatif tetap diformat akurat dengan tanda minus (tidak di-clamp ke 0)', () async {
      const negativeSummary = ReportSummary(
        totalOmzet: 10000,
        totalHpp: 15000,
        totalProfit: -5000,
        transactionCount: 1,
        productsSold: 2.0,
      );

      const p1 = ReportProductStat(
        productId: 1,
        productName: 'Produk Promo Rugi',
        quantity: 2.0,
        omzet: 10000,
        hpp: 15000,
        profit: -5000,
      );

      const data = ReportData(
        periodType: ReportPeriodType.daily,
        startDate: '2026-09-16',
        endDate: '2026-09-16',
        summary: negativeSummary,
        products: [p1],
        topSelling: p1,
        highestProfit: p1,
      );

      final bytes = await generator.generateReportPdf(data);
      expect(bytes.isNotEmpty, isTrue);
      // Generator berhasil menghasilkan binary PDF yang memuat informasi rugi/negatif
      expect(negativeSummary.formattedTotalProfit, '-Rp5.000');
    });
  });
}

