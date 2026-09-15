import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/utils/currency_formatter.dart';
import 'package:labana/core/utils/unit_converter.dart';

void main() {
  group('UnitConverter Tests', () {
    test('Konversi 1 kg -> 1000 g', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
      );
      expect(result.baseQuantity, 1000.0);
      expect(result.baseUnit, 'g');
    });

    test('Konversi 500 g -> 500 g', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 500.0,
        purchaseUnit: 'g',
      );
      expect(result.baseQuantity, 500.0);
      expect(result.baseUnit, 'g');
    });

    test('Konversi 1 liter -> 1000 ml', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 1.0,
        purchaseUnit: 'liter',
      );
      expect(result.baseQuantity, 1000.0);
      expect(result.baseUnit, 'ml');
    });

    test('Konversi 250 ml -> 250 ml', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 250.0,
        purchaseUnit: 'ml',
      );
      expect(result.baseQuantity, 250.0);
      expect(result.baseUnit, 'ml');
    });

    test('Konversi 10 pcs -> 10 pcs', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 10.0,
        purchaseUnit: 'pcs',
      );
      expect(result.baseQuantity, 10.0);
      expect(result.baseUnit, 'pcs');
    });

    test('Konversi 1 pack x 50 -> 50 pcs', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 1.0,
        purchaseUnit: 'pack',
        packageQuantity: 50.0,
      );
      expect(result.baseQuantity, 50.0);
      expect(result.baseUnit, 'pcs');
    });

    test('Konversi 2 pack x 25 -> 50 pcs', () {
      final result = UnitConverter.convert(
        purchaseQuantity: 2.0,
        purchaseUnit: 'pack',
        packageQuantity: 25.0,
      );
      expect(result.baseQuantity, 50.0);
      expect(result.baseUnit, 'pcs');
    });

    test('Pack tanpa package_quantity melempar UnitConversionException', () {
      expect(
        () =>
            UnitConverter.convert(purchaseQuantity: 1.0, purchaseUnit: 'pack'),
        throwsA(isA<UnitConversionException>()),
      );

      expect(
        () => UnitConverter.convert(
          purchaseQuantity: 1.0,
          purchaseUnit: 'pack',
          packageQuantity: 0,
        ),
        throwsA(isA<UnitConversionException>()),
      );
    });

    test('Purchase quantity <= 0 melempar UnitConversionException', () {
      expect(
        () => UnitConverter.convert(purchaseQuantity: 0, purchaseUnit: 'kg'),
        throwsA(isA<UnitConversionException>()),
      );

      expect(
        () => UnitConverter.convert(purchaseQuantity: -1.5, purchaseUnit: 'g'),
        throwsA(isA<UnitConversionException>()),
      );
    });

    test('Validasi inkompatibilitas kategori satuan', () {
      expect(UnitConverter.isCompatible('kg', 'ml'), isFalse);
      expect(UnitConverter.isCompatible('kg', 'pcs'), isFalse);
      expect(UnitConverter.isCompatible('ml', 'pcs'), isFalse);
      expect(UnitConverter.isCompatible('g', 'pcs'), isFalse);
      expect(UnitConverter.isCompatible('liter', 'pcs'), isFalse);

      expect(UnitConverter.isCompatible('kg', 'g'), isTrue);
      expect(UnitConverter.isCompatible('liter', 'ml'), isTrue);
      expect(UnitConverter.isCompatible('pack', 'pcs'), isTrue);

      expect(
        () => UnitConverter.convert(
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          targetBaseUnit: 'ml',
        ),
        throwsA(isA<UnitConversionException>()),
      );
    });
  });

  group('CurrencyFormatter Tests', () {
    test('formatRupiah memformat angka dengan pemisah ribuan titik', () {
      expect(CurrencyFormatter.formatRupiah(20000), 'Rp20.000');
      expect(CurrencyFormatter.formatRupiah(1500), 'Rp1.500');
      expect(CurrencyFormatter.formatRupiah(250000), 'Rp250.000');
      expect(CurrencyFormatter.formatRupiah(0), 'Rp0');
      expect(CurrencyFormatter.formatRupiah(-5000), '-Rp5.000');
    });

    test('formatCostPerBaseUnit memformat harga per satuan dengan rapi', () {
      expect(CurrencyFormatter.formatCostPerBaseUnit(20.0, 'g'), 'Rp20/g');
      expect(CurrencyFormatter.formatCostPerBaseUnit(4.2, 'ml'), 'Rp4,2/ml');
      expect(
        CurrencyFormatter.formatCostPerBaseUnit(200.0, 'pcs'),
        'Rp200/pcs',
      );
      expect(CurrencyFormatter.formatCostPerBaseUnit(18.0, 'ml'), 'Rp18/ml');
    });
  });
}
