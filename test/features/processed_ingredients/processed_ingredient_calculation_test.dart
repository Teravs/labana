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

    test('Tahap 7 - Kasus 6: Simple nested processed ingredient', () {
      // Child (id: 100): 500 g bahan seharga Rp10.000, hasil 1000 ml (cost: Rp10/ml)
      final rawPrice = IngredientPrice(
        id: 1,
        ingredientId: 1,
        purchaseQuantity: 500,
        purchaseUnit: 'g',
        baseQuantity: 500,
        baseUnit: 'g',
        price: 10000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      final child = const ProcessedIngredient(
        id: 100,
        name: 'Simple Syrup',
        resultQuantity: 1000,
        resultUnit: 'ml',
      );

      final childComp = const ProcessedComponent(
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 1,
        quantity: 500,
        unit: 'g',
      );

      // Parent (id: 200): Sweet Drink, menggunakan 100 ml Simple Syrup
      final parent = const ProcessedIngredient(
        id: 200,
        name: 'Sweet Drink',
        resultQuantity: 500,
        resultUnit: 'ml',
      );

      final parentComp = const ProcessedComponent(
        componentType: ProcessedComponent.typeProcessed,
        childProcessedId: 100,
        quantity: 100,
        unit: 'ml',
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: parent,
            components: [parentComp],
            pricesByIngredientId: {
              1: [rawPrice],
            },
            processedIngredientsById: {100: child},
            processedComponentsById: {
              100: [childComp],
            },
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      // Kontribusi child: 100 ml * (Rp10.000 / 1000 ml) = Rp1.000
      expect(result.componentResults[0].calculatedCost, 1000.0);
      expect(result.totalCost, 1000.0);
      // Cost per ml parent: 1000 / 500 = Rp2/ml
      expect(result.costPerResultUnit, 2.0);
    });

    test('Tahap 7 - Kasus 7: Nested + raw ingredient', () {
      final gulaPrice = IngredientPrice(
        id: 1,
        ingredientId: 1,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 15000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      final tehPrice = IngredientPrice(
        id: 2,
        ingredientId: 2,
        purchaseQuantity: 100,
        purchaseUnit: 'g',
        baseQuantity: 100,
        baseUnit: 'g',
        price: 20000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      // Child: Sirup Gula (500 g gula = Rp7.500, hasil 750 ml -> Rp10/ml)
      final childSirup = const ProcessedIngredient(
        id: 100,
        name: 'Sirup Gula',
        resultQuantity: 750,
        resultUnit: 'ml',
      );
      final childCompGula = const ProcessedComponent(
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 1,
        quantity: 500,
        unit: 'g',
      );

      // Parent: Es Teh Manis (100 ml sirup + 10 g teh)
      final parentEsTeh = const ProcessedIngredient(
        id: 200,
        name: 'Es Teh Manis',
        resultQuantity: 400,
        resultUnit: 'ml',
      );
      final compSirup = const ProcessedComponent(
        componentType: ProcessedComponent.typeProcessed,
        childProcessedId: 100,
        quantity: 100,
        unit: 'ml',
      );
      final compTeh = const ProcessedComponent(
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 2,
        quantity: 10,
        unit: 'g',
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: parentEsTeh,
            components: [compSirup, compTeh],
            pricesByIngredientId: {
              1: [gulaPrice],
              2: [tehPrice],
            },
            processedIngredientsById: {100: childSirup},
            processedComponentsById: {
              100: [childCompGula],
            },
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      // Sirup: 100 ml * 10 = Rp1.000
      expect(result.componentResults[0].calculatedCost, 1000.0);
      // Teh: 10 g * (20000 / 100) = Rp2.000
      expect(result.componentResults[1].calculatedCost, 2000.0);
      // Total: Rp3.000
      expect(result.totalCost, 3000.0);
      // Cost per ml: 3000 / 400 = 7.5
      expect(result.costPerResultUnit, 7.5);
    });

    test('Tahap 7 - Kasus 8: Nested + other cost', () {
      final rawPrice = IngredientPrice(
        id: 1,
        ingredientId: 1,
        purchaseQuantity: 1000,
        purchaseUnit: 'ml',
        baseQuantity: 1000,
        baseUnit: 'ml',
        price: 10000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      final child = const ProcessedIngredient(
        id: 100,
        name: 'Sari Buah',
        resultQuantity: 1000,
        resultUnit: 'ml',
      );
      final childComp = const ProcessedComponent(
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 1,
        quantity: 1000,
        unit: 'ml',
      );

      final parent = const ProcessedIngredient(
        id: 200,
        name: 'Minuman Buah Cup',
        resultQuantity: 1,
        resultUnit: 'pcs',
      );
      final compChild = const ProcessedComponent(
        componentType: ProcessedComponent.typeProcessed,
        childProcessedId: 100,
        quantity: 200,
        unit: 'ml',
      );
      final compOther = const ProcessedComponent(
        componentType: ProcessedComponent.typeOther,
        otherCost: 1500,
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: parent,
            components: [compChild, compOther],
            pricesByIngredientId: {
              1: [rawPrice],
            },
            processedIngredientsById: {100: child},
            processedComponentsById: {
              100: [childComp],
            },
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      // 200 ml * 10 = 2000
      expect(result.componentResults[0].calculatedCost, 2000.0);
      // Biaya cup / operasional = 1500
      expect(result.componentResults[1].calculatedCost, 1500.0);
      expect(result.totalCost, 3500.0);
      expect(result.costPerResultUnit, 3500.0);
    });

    test('Tahap 7 - Kasus 9: Multi-level nested (A -> B -> C -> raw)', () {
      final rawPrice = IngredientPrice(
        id: 1,
        ingredientId: 1,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        baseQuantity: 1000,
        baseUnit: 'g',
        price: 20000,
        isDefault: true,
        effectiveFrom: '2026-01-01',
      );

      // C: Olahan C (500 g raw = Rp10.000, hasil 1000 ml -> Rp10/ml)
      final c = const ProcessedIngredient(
        id: 1,
        name: 'Olahan C',
        resultQuantity: 1000,
        resultUnit: 'ml',
      );
      final compC = const ProcessedComponent(
        componentType: ProcessedComponent.typeIngredient,
        ingredientId: 1,
        quantity: 500,
        unit: 'g',
      );

      // B: Olahan B (200 ml C = Rp2.000, other = Rp500 -> total Rp2.500, hasil 500 ml -> Rp5/ml)
      final b = const ProcessedIngredient(
        id: 2,
        name: 'Olahan B',
        resultQuantity: 500,
        resultUnit: 'ml',
      );
      final compB1 = const ProcessedComponent(
        componentType: ProcessedComponent.typeProcessed,
        childProcessedId: 1,
        quantity: 200,
        unit: 'ml',
      );
      final compB2 = const ProcessedComponent(
        componentType: ProcessedComponent.typeOther,
        otherCost: 500,
      );

      // A: Olahan A (100 ml B -> 100 * Rp5 = Rp500, hasil 250 ml -> Rp2/ml)
      final a = const ProcessedIngredient(
        id: 3,
        name: 'Olahan A',
        resultQuantity: 250,
        resultUnit: 'ml',
      );
      final compA = const ProcessedComponent(
        componentType: ProcessedComponent.typeProcessed,
        childProcessedId: 2,
        quantity: 100,
        unit: 'ml',
      );

      final result =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: a,
            components: [compA],
            pricesByIngredientId: {
              1: [rawPrice],
            },
            processedIngredientsById: {1: c, 2: b, 3: a},
            processedComponentsById: {
              1: [compC],
              2: [compB1, compB2],
              3: [compA],
            },
            calculationDate: calculationDate,
          );

      expect(result.hasUnresolvedCost, isFalse);
      expect(result.totalCost, 500.0);
      expect(result.costPerResultUnit, 2.0);
    });

    test(
      'Tahap 7 - Kasus 10: Konversi satuan hasil child (1 liter) ke pemakaian parent (250 ml)',
      () {
        final child = const ProcessedIngredient(
          id: 10,
          name: 'Sirup 1 Liter',
          resultQuantity: 1,
          resultUnit: 'liter', // Child menghasilkan 1 liter seharga Rp20.000
        );

        final childCostResult = ProcessedIngredientCostResult(
          processedIngredient: child,
          componentResults: [],
          totalCost: 20000.0,
          costPerResultUnit: 20000.0, // Rp20.000 per liter (atau Rp20 per ml)
          hasUnresolvedCost: false,
          warnings: [],
        );

        final parentComp = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 10,
          quantity: 250,
          unit: 'ml',
        );

        final res = ProcessedIngredientCalculator.calculateComponentCost(
          component: parentComp,
          childProcessedIngredient: child,
          childCostResult: childCostResult,
          calculationDate: calculationDate,
        );

        expect(res.isResolvable, isTrue);
        // 1 liter = 1000 ml, cost = Rp20/ml. Pemakaian 250 ml = Rp5.000
        expect(res.calculatedCost, 5000.0);
      },
    );

    test(
      'Tahap 7 - Kasus 11: Satuan inkompatibel antara parent (gram) dan child (ml)',
      () {
        final child = const ProcessedIngredient(
          id: 10,
          name: 'Sirup Cair',
          resultQuantity: 500,
          resultUnit: 'ml',
        );

        final childCostResult = ProcessedIngredientCostResult(
          processedIngredient: child,
          componentResults: [],
          totalCost: 10000.0,
          costPerResultUnit: 20.0,
          hasUnresolvedCost: false,
          warnings: [],
        );

        final parentComp = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 10,
          quantity: 100,
          unit: 'g', // Gram tidak kompatibel dengan ml
        );

        final res = ProcessedIngredientCalculator.calculateComponentCost(
          component: parentComp,
          childProcessedIngredient: child,
          childCostResult: childCostResult,
          calculationDate: calculationDate,
        );

        expect(res.isResolvable, isFalse);
        expect(res.errorMessage, contains('tidak cocok dengan satuan hasil'));
      },
    );

    test(
      'Tahap 7 - Kasus 12: Diamond DAG (A -> B dan A -> C, keduanya memakai D)',
      () {
        // D: Bahan Olahan Dasar (Rp1.000 / 100 ml = Rp10/ml)
        final d = const ProcessedIngredient(
          id: 4,
          name: 'Olahan D',
          resultQuantity: 100,
          resultUnit: 'ml',
        );
        final compD = const ProcessedComponent(
          componentType: ProcessedComponent.typeOther,
          otherCost: 1000,
        );

        // B: menggunakan 20 ml D = Rp200
        final b = const ProcessedIngredient(
          id: 2,
          name: 'Olahan B',
          resultQuantity: 50,
          resultUnit: 'ml',
        );
        final compB = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 4,
          quantity: 20,
          unit: 'ml',
        );

        // C: menggunakan 30 ml D = Rp300
        final c = const ProcessedIngredient(
          id: 3,
          name: 'Olahan C',
          resultQuantity: 50,
          resultUnit: 'ml',
        );
        final compC = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 4,
          quantity: 30,
          unit: 'ml',
        );

        // A: menggunakan B (50 ml = Rp200) dan C (50 ml = Rp300)
        final a = const ProcessedIngredient(
          id: 1,
          name: 'Olahan A',
          resultQuantity: 100,
          resultUnit: 'ml',
        );
        final compA1 = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 2,
          quantity: 50,
          unit: 'ml',
        );
        final compA2 = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 3,
          quantity: 50,
          unit: 'ml',
        );

        final result =
            ProcessedIngredientCalculator.calculateProcessedIngredientCost(
              processedIngredient: a,
              components: [compA1, compA2],
              pricesByIngredientId: {},
              processedIngredientsById: {1: a, 2: b, 3: c, 4: d},
              processedComponentsById: {
                1: [compA1, compA2],
                2: [compB],
                3: [compC],
                4: [compD],
              },
              calculationDate: calculationDate,
            );

        expect(result.hasUnresolvedCost, isFalse);
        // B kontribusi Rp200, C kontribusi Rp300 -> Total Rp500
        expect(result.totalCost, 500.0);
      },
    );

    test(
      'Tahap 7 - Kasus 13: Circular data safety (tidak hang, memutus siklus secara aman)',
      () {
        // Data abnormal di mana A -> B dan B -> A
        final a = const ProcessedIngredient(
          id: 1,
          name: 'Olahan A',
          resultQuantity: 100,
          resultUnit: 'ml',
        );
        final b = const ProcessedIngredient(
          id: 2,
          name: 'Olahan B',
          resultQuantity: 100,
          resultUnit: 'ml',
        );

        final compA = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 2,
          quantity: 10,
          unit: 'ml',
        );
        final compB = const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 1,
          quantity: 10,
          unit: 'ml',
        );

        final result =
            ProcessedIngredientCalculator.calculateProcessedIngredientCost(
              processedIngredient: a,
              components: [compA],
              pricesByIngredientId: {},
              processedIngredientsById: {1: a, 2: b},
              processedComponentsById: {
                1: [compA],
                2: [compB],
              },
              calculationDate: calculationDate,
            );

        // Harus segera kembali tanpa timeout/hang dan menandai hasUnresolvedCost = true
        expect(result.hasUnresolvedCost, isTrue);
        expect(result.warnings, isNotEmpty);
      },
    );
  });
}
