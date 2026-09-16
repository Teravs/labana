import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/reports/models/report_models.dart';

void main() {
  group('ReportSummary Tests', () {
    test('Formatters menghasilkan representasi Rupiah dan teks yang benar', () {
      const summary = ReportSummary(
        totalOmzet: 125000,
        totalHpp: 33500,
        totalProfit: 91500,
        transactionCount: 15,
        productsSold: 25.0,
      );

      expect(summary.formattedTotalOmzet, 'Rp125.000');
      expect(summary.formattedTotalHpp, 'Rp33.500');
      expect(summary.formattedTotalProfit, 'Rp91.500');
      expect(summary.formattedProductsSold, '25');
      expect(summary.formattedProfitMargin, '73%');
    });

    test('Profit margin 0% ketika omzet 0', () {
      const summary = ReportSummary();
      expect(summary.profitMarginPercent, 0.0);
      expect(summary.formattedProfitMargin, '0%');
    });

    test('Desimal kuantitas diformat dengan koma tanpa trailing zero', () {
      const summary = ReportSummary(productsSold: 12.5);
      expect(summary.formattedProductsSold, '12,5');

      const summary2 = ReportSummary(productsSold: 12.0);
      expect(summary2.formattedProductsSold, '12');
    });

    test('fromMap mengonversi data SQLite Map dengan benar', () {
      final map = {
        'total_omzet': 200000,
        'total_hpp': 60000,
        'total_profit': 140000,
        'transaction_count': 10,
        'products_sold': 30.5,
      };

      final summary = ReportSummary.fromMap(map);
      expect(summary.totalOmzet, 200000);
      expect(summary.totalHpp, 60000);
      expect(summary.totalProfit, 140000);
      expect(summary.transactionCount, 10);
      expect(summary.productsSold, 30.5);
    });
  });

  group('ReportProductStat Tests', () {
    test('fromMap dan formatters bekerja sesuai standar', () {
      final map = {
        'product_id': 1,
        'product_name': 'Es Teh Manis',
        'total_quantity': 20.0,
        'total_omzet': 100000,
        'total_hpp': 26800,
        'total_profit': 73200,
      };

      final stat = ReportProductStat.fromMap(map);
      expect(stat.productId, 1);
      expect(stat.productName, 'Es Teh Manis');
      expect(stat.formattedQuantity, '20');
      expect(stat.formattedOmzet, 'Rp100.000');
      expect(stat.formattedHpp, 'Rp26.800');
      expect(stat.formattedProfit, 'Rp73.200');
    });
  });

  group('DailyReportStat Tests', () {
    test('Formatters dan tanggal kalender bekerja dengan benar', () {
      final map = {
        'date_str': '2026-09-14',
        'total_omzet': 50000,
        'total_hpp': 15000,
        'total_profit': 35000,
        'transaction_count': 5,
        'products_sold': 10.0,
      };

      final stat = DailyReportStat.fromMap(map);
      expect(stat.formattedDateDisplay, 'Sen, 14 Sep');
      expect(stat.formattedShortDate, '14 Sep');
      expect(stat.formattedOmzet, 'Rp50.000');
      expect(stat.formattedHpp, 'Rp15.000');
      expect(stat.formattedProfit, 'Rp35.000');
      expect(stat.formattedProductsSold, '10');
    });
  });

  group('PaymentMethodStat Tests', () {
    test('Label bahasa Indonesia dan format Rupiah bekerja', () {
      final cash = PaymentMethodStat.fromMap({
        'payment_method': 'cash',
        'transaction_count': 10,
        'total_amount': 50000,
      });
      expect(cash.paymentMethodLabel, 'Tunai');
      expect(cash.formattedTotalAmount, 'Rp50.000');

      final qris = PaymentMethodStat.fromMap({
        'payment_method': 'qris',
        'transaction_count': 5,
        'total_amount': 30000,
      });
      expect(qris.paymentMethodLabel, 'QRIS');

      final transfer = PaymentMethodStat.fromMap({
        'payment_method': 'transfer',
        'transaction_count': 2,
        'total_amount': 20000,
      });
      expect(transfer.paymentMethodLabel, 'Transfer');
    });
  });

  group('ReportData Tests', () {
    test('isEmpty true saat transactionCount 0', () {
      final empty = ReportData.empty(
        periodType: ReportPeriodType.daily,
        startDate: '2026-09-16',
        endDate: '2026-09-16',
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.summary.totalOmzet, 0);
      expect(empty.products, isEmpty);
      expect(empty.dailyBreakdown, isEmpty);
    });
  });
}

