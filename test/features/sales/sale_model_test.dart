import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';

void main() {
  group('SaleItem Model Tests', () {
    test('1. fromMap & toMap serialization', () {
      final map = {
        'id': 1,
        'sale_id': 10,
        'product_id': 5,
        'recipe_version_id': 2,
        'product_name': 'Es Teh Manis',
        'quantity': 2.0,
        'selling_price': 5000,
        'hpp_per_unit': 1340,
        'subtotal': 10000,
        'total_hpp': 2680,
        'total_profit': 7320,
        'created_at': '2026-09-15T13:25:00Z',
      };

      final item = SaleItem.fromMap(map);

      expect(item.id, 1);
      expect(item.saleId, 10);
      expect(item.productId, 5);
      expect(item.recipeVersionId, 2);
      expect(item.productName, 'Es Teh Manis');
      expect(item.quantity, 2.0);
      expect(item.sellingPrice, 5000);
      expect(item.hppPerUnit, 1340);
      expect(item.subtotal, 10000);
      expect(item.totalHpp, 2680);
      expect(item.totalProfit, 7320);
      expect(item.createdAt, '2026-09-15T13:25:00Z');

      final toMapResult = item.toMap();
      expect(toMapResult['product_name'], 'Es Teh Manis');
      expect(toMapResult['quantity'], 2.0);
      expect(toMapResult['subtotal'], 10000);
    });

    test('2. Helpers & Formatting', () {
      const item = SaleItem(
        id: 1,
        saleId: 10,
        productId: 5,
        recipeVersionId: 2,
        productName: 'Es Teh Manis',
        quantity: 2.5,
        sellingPrice: 5000,
        hppPerUnit: 1340,
        subtotal: 12500,
        totalHpp: 3350,
        totalProfit: 9150,
        createdAt: '2026-09-15T13:25:00Z',
      );

      expect(item.profitPerUnit, 3660);
      expect(item.formattedQuantity, '2.5');
      expect(item.formattedSellingPrice, 'Rp5.000');
      expect(item.formattedHppPerUnit, 'Rp1.340');
      expect(item.formattedSubtotal, 'Rp12.500');
      expect(item.formattedTotalHpp, 'Rp3.350');
      expect(item.formattedTotalProfit, 'Rp9.150');

      final wholeQtyItem = item.copyWith(quantity: 3.0);
      expect(wholeQtyItem.formattedQuantity, '3');
    });
  });

  group('Sale Model Tests', () {
    test('3. fromMap & toMap serialization', () {
      final map = {
        'id': 1,
        'transaction_number': 'TRX-20260915-001',
        'transaction_date': '2026-09-15 13:25:00',
        'payment_method': 'cash',
        'total_amount': 15000,
        'total_hpp': 4530,
        'total_profit': 10470,
        'created_at': '2026-09-15T13:25:00Z',
        'updated_at': '2026-09-15T13:25:00Z',
        'item_count': 3,
      };

      final sale = Sale.fromMap(map);

      expect(sale.id, 1);
      expect(sale.transactionNumber, 'TRX-20260915-001');
      expect(sale.transactionDate, '2026-09-15 13:25:00');
      expect(sale.paymentMethod, 'cash');
      expect(sale.totalAmount, 15000);
      expect(sale.totalHpp, 4530);
      expect(sale.totalProfit, 10470);
      expect(sale.itemCount, 3);

      final toMapResult = sale.toMap();
      expect(toMapResult['transaction_number'], 'TRX-20260915-001');
      expect(toMapResult['total_amount'], 15000);
    });

    test('4. Payment method labels & helpers', () {
      const saleCash = Sale(
        transactionNumber: 'TRX-1',
        transactionDate: '2026-09-15 13:25:00',
        paymentMethod: Sale.paymentCash,
        totalAmount: 10000,
        totalHpp: 3000,
        totalProfit: 7000,
        createdAt: '',
        updatedAt: '',
      );
      expect(saleCash.paymentMethodLabel, 'Tunai');

      final saleQris = saleCash.copyWith(paymentMethod: Sale.paymentQris);
      expect(saleQris.paymentMethodLabel, 'QRIS');

      final saleTransfer = saleCash.copyWith(
        paymentMethod: Sale.paymentTransfer,
      );
      expect(saleTransfer.paymentMethodLabel, 'Transfer');

      expect(Sale.methodCodeFromLabel('Tunai'), Sale.paymentCash);
      expect(Sale.methodCodeFromLabel('QRIS'), Sale.paymentQris);
      expect(Sale.methodCodeFromLabel('Transfer'), Sale.paymentTransfer);
    });

    test('5. Date & Time formatting helpers', () {
      const sale = Sale(
        transactionNumber: 'TRX-20260915-001',
        transactionDate: '2026-09-15 13:25:00',
        paymentMethod: Sale.paymentCash,
        totalAmount: 15000,
        totalHpp: 4530,
        totalProfit: 10470,
        createdAt: '',
        updatedAt: '',
      );

      expect(sale.dateOnly, '2026-09-15');
      expect(sale.formattedDateTime, '15 Sep 2026 • 13:25');
      expect(sale.formattedDateFull, '15 September 2026');
      expect(sale.formattedTime, '13:25');
      expect(sale.formattedTotalAmount, 'Rp15.000');
      expect(sale.formattedTotalHpp, 'Rp4.530');
      expect(sale.formattedTotalProfit, 'Rp10.470');
    });
  });
}
