import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/ingredients/models/ingredient_price.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/processed_ingredients/models/processed_ingredient.dart';
import 'package:labana/features/processed_ingredients/services/processed_ingredient_calculator.dart';

void main() {
  group('ProcessedIngredientCalculator Tests', () {
    const calculationDate = '2026-03-15';

    test('Kasus 1: Sirup Gula Sederhana (Simple Sugar Syrup)', () {
      // Gula Pasir: 500 g, harga Rp 15.000 / 1000 g
      final gulaPrice = IngredientPrice(
        id: 1,
        ingredientId: 10,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 15000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      final gulaComp = ProcessedComponent(
        id: 1,
        processedIngredientId: 100,
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 10,
        quantity: 500,
        unit: 'g',
      );

      // Air: biaya Rp 0 (biaya lainnya)
      final airComp = ProcessedComponent(
        id: 2,
        processedIngredientId: 100,
        componentType: ProcessedComponent.typeOther,
        otherCost: 0,
      );

      final sirupGula = ProcessedIngredient(
        id: 100,
        name: 'Sirup Gula',
        resultQuantity: 750,
        resultUnit: 'ml',
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: sirupGula,
            components: [gulaComp, airComp],
            pricesByIngredientId: {
              10: [gulaPrice],
            },
            ingredientNamesById: {10: 'Gula Pasir'},
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      expect(result.warnings, isEmpty);
      // Biaya gula: 500 * (15000 / 1000) = 7500
      expect(result.componentResults[0].calculatedCost, 7500.0);
      expect(result.componentResults[0].isResolvable, isTrue);
      // Biaya air: 0
      expect(result.componentResults[1].calculatedCost, 0.0);
      // Total: 7500
      expect(result.totalCost, 7500.0);
      // Biaya per ml: 7500 / 750 = 10.0 / ml
      expect(result.costPerResultUnit, 10.0);
    });

    test(
      'Kasus 2: Milk Base (Campuran Susu, Kental Manis, dan Biaya Listrik/Gas)',
      () {
        // Susu UHT: Rp 18.000 / 1000 ml
        final susuPrice = IngredientPrice(
          id: 1,
          ingredientId: 20,
          purchaseQuantity: 1,
          purchaseUnit: 'liter',
          baseQuantity: 1000,
          baseUnit: 'ml',
          price: 18000,
          isDefault: true,
          effectiveFrom: '2026-01-01',
        );

        // Kental Manis: Rp 12.000 / 300 ml
        final skmPrice = IngredientPrice(
          id: 2,
          ingredientId: 21,
          purchaseQuantity: 300,
          purchaseUnit: 'ml',
          baseQuantity: 300,
          baseUnit: 'ml',
          price: 12000,
          isDefault: true,
          effectiveFrom: '2026-01-01',
        );

        final susuComp = ProcessedComponent(
          id: 1,
          processedIngredientId: 200,
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: 20,
          quantity: 1000,
          unit: 'ml',
        );

        final skmComp = ProcessedComponent(
          id: 2,
          processedIngredientId: 200,
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: 21,
          quantity: 200,
          unit: 'ml',
        );

        final gasComp = ProcessedComponent(
          id: 3,
          processedIngredientId: 200,
          componentType: ProcessedComponent.typeOther,
          otherCost: 2000,
        );

        final milkBase = ProcessedIngredient(
          id: 200,
          name: 'Milk Base',
          resultQuantity: 1100,
          resultUnit: 'ml',
        );

        final result =
            ProcessedIngredientCalculator.calculateProcessedIngredientCost(
              processedIngredient: milkBase,
              components: [susuComp, skmComp, gasComp],
              pricesByIngredientId: {
                20: [susuPrice],
                21: [skmPrice],
              },
              ingredientNamesById: {20: 'Susu UHT', 21: 'Kental Manis'},
              calculationDate: calculationDate,
            );

        expect(result.hasUnresolvedCost, isFalse);
        // Susu: 1000 * (18000 / 1000) = 18000
        expect(result.componentResults[0].calculatedCost, 18000.0);
        // SKM: 200 * (12000 / 300) = 8000
        expect(result.componentResults[1].calculatedCost, 8000.0);
        // Biaya Lainnya (Gas): 2000
        expect(result.componentResults[2].calculatedCost, 2000.0);
        // Total: 18000 + 8000 + 2000 = 28000
        expect(result.totalCost, 28000.0);
        // Cost per ml: 28000 / 1100 = 25.4545...
        expect(result.costPerResultUnit, closeTo(28000 / 1100, 0.0001));
      },
    );

    test('Kasus 3: Pemilihan harga historis & penanganan harga belum aktif', () {
      final oldPrice = IngredientPrice(
        id: 1,
        ingredientId: 30,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 10000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      final newPrice = IngredientPrice(
        id: 2,
        ingredientId: 30,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 15000,
        isDefault: true,
        effectiveFrom: '2026-06-01',
      );

      final comp = ProcessedComponent(
        id: 1,
        processedIngredientId: 300,
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 30,
        quantity: 500,
        unit: 'g',
      );

      // Tanggal sebelum harga pertama berlaku (2025-12-31) -> belum ada harga aktif
      final resPre = ProcessedIngredientCalculator.calculateComponentCost(
        component: comp,
        ingredientPrices: [oldPrice, newPrice],
        calculationDate: '2025-12-31',
      );
      expect(resPre.isResolvable, isFalse);
      expect(resPre.calculatedCost, 0.0);
      expect(resPre.errorMessage, contains('Belum ada harga aktif'));

      // Tanggal di antara oldPrice dan newPrice (2026-03-01) -> pakai oldPrice
      final resMid = ProcessedIngredientCalculator.calculateComponentCost(
        component: comp,
        ingredientPrices: [oldPrice, newPrice],
        calculationDate: '2026-03-01',
      );
      expect(resMid.isResolvable, isTrue);
      expect(resMid.resolvedPrice?.id, 1);
      expect(resMid.calculatedCost, 500 * 10.0); // 5000

      // Tanggal setelah newPrice berlaku (2026-07-01) -> pakai newPrice
      final resPost = ProcessedIngredientCalculator.calculateComponentCost(
        component: comp,
        ingredientPrices: [oldPrice, newPrice],
        calculationDate: '2026-07-01',
      );
      expect(resPost.isResolvable, isTrue);
      expect(resPost.resolvedPrice?.id, 2);
      expect(resPost.calculatedCost, 500 * 15.0); // 7500
    });

    test('Kasus 4: Penanganan satuan tidak kompatibel', () {
      // Bahan dibeli dalam gram/kg
      final priceKg = IngredientPrice(
        id: 1,
        ingredientId: 40,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 20000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      // Komponen mencoba menggunakan ml (volume vs berat tanpa konversi densitas)
      final compMl = ProcessedComponent(
        id: 1,
        processedIngredientId: 400,
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 40,
        quantity: 100,
        unit: 'ml',
      );

      final res = ProcessedIngredientCalculator.calculateComponentCost(
        component: compMl,
        ingredientPrices: [priceKg],
        calculationDate: '2026-03-01',
      );

      expect(res.isResolvable, isFalse);
      expect(res.calculatedCost, 0.0);
      expect(res.errorMessage, contains('tidak kompatibel'));
    });

    test('Kasus 5: Komponen biaya lainnya saja (Other Cost Only)', () {
      final comp = ProcessedComponent(
        id: 1,
        processedIngredientId: 500,
        componentType: ProcessedComponent.typeOther,
        otherCost: 5000,
      );

      final proc = ProcessedIngredient(
        id: 500,
        name: 'Es Batu Kristal Olahan',
        resultQuantity: 10,
        resultUnit: 'kg',
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: proc,
            components: [comp],
            pricesByIngredientId: {},
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      expect(result.totalCost, 5000.0);
      expect(result.costPerResultUnit, 500.0);
    });

    test(
      'Resolusi harga deterministik: Memprioritaskan default jika ada beberapa format aktif',
      () {
        final formatKgDefault = IngredientPrice(
          id: 1,
          ingredientId: 50,
          purchaseQuantity: 1,
          purchaseUnit: 'kg',
          baseQuantity: 1000,
          baseUnit: 'g',
          price: 20000, // Rp 20/g
          isDefault: true,
          effectiveFrom: '2026-01-01',
        );

        final formatGram = IngredientPrice(
          id: 2,
          ingredientId: 50,
          purchaseQuantity: 500,
          purchaseUnit: 'g',
          baseQuantity: 500,
          baseUnit: 'g',
          price: 12000, // Rp 24/g
          isDefault: false,
          effectiveFrom: '2026-01-01',
        );

        final comp = ProcessedComponent(
          id: 1,
          processedIngredientId: 600,
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: 50,
          quantity: 250,
          unit: 'g',
        );

        final res = ProcessedIngredientCalculator.calculateComponentCost(
          component: comp,
          ingredientPrices: [formatKgDefault, formatGram],
          calculationDate: calculationDate,
        );

        expect(res.isResolvable, isTrue);
        // Format default (id 1) harus dipilih
        expect(res.resolvedPrice?.id, 1);
        expect(res.calculatedCost, 250 * 20.0);
      },
    );

    test(
      'Resolusi harga deterministik: Memilih unit yang cocok jika tidak ada yang default',
      () {
        final formatLiter = IngredientPrice(
          id: 1,
          ingredientId: 60,
          purchaseQuantity: 1,
          purchaseUnit: 'liter',
          baseQuantity: 1000,
          baseUnit: 'ml',
          price: 15000,
          isDefault: false,
          effectiveFrom: '2026-01-01',
        );

        final formatMl = IngredientPrice(
          id: 2,
          ingredientId: 60,
          purchaseQuantity: 250,
          purchaseUnit: 'ml',
          baseQuantity: 250,
          baseUnit: 'ml',
          price: 5000,
          isDefault: false,
          effectiveFrom: '2026-01-01',
        );

        final comp = ProcessedComponent(
          id: 1,
          processedIngredientId: 700,
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: 60,
          quantity: 100,
          unit: 'ml',
        );

        final res = ProcessedIngredientCalculator.calculateComponentCost(
          component: comp,
          ingredientPrices: [formatLiter, formatMl],
          calculationDate: calculationDate,
        );

        expect(res.isResolvable, isTrue);
        // Format ml (id 2) cocok secara persis dengan unit komponen
        expect(res.resolvedPrice?.id, 2);
      },
    );
  });
}
