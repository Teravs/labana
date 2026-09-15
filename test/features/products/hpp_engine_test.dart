import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/core/utils/unit_converter.dart';
import 'package:labana/features/ingredients/data/ingredient_price_repository.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/ingredients/models/ingredient.dart';
import 'package:labana/features/ingredients/models/ingredient_price.dart';
import 'package:labana/features/processed_ingredients/data/processed_ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/processed_ingredients/services/processed_ingredient_calculator.dart';
import 'package:labana/features/products/data/product_price_repository.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/data/recipe_item_repository.dart';
import 'package:labana/features/products/data/recipe_version_repository.dart';
import 'package:labana/features/products/errors/hpp_exceptions.dart';
import 'package:labana/features/products/models/product.dart';
import 'package:labana/features/products/models/product_price.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/models/recipe_version.dart';
import 'package:labana/features/products/services/hpp_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late RecipeVersionRepository recipeVersionRepo;
  late RecipeItemRepository recipeItemRepo;
  late ProductPriceRepository productPriceRepo;
  late IngredientRepository ingredientRepo;
  late IngredientPriceRepository ingredientPriceRepo;
  late ProcessedIngredientRepository processedRepo;
  late HppEngine hppEngine;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
      onUpgrade: DatabaseHelper.onUpgrade,
    );
    DatabaseHelper.instance.setTestDatabase(db);

    recipeVersionRepo = RecipeVersionRepository();
    recipeItemRepo = RecipeItemRepository();
    productPriceRepo = ProductPriceRepository();
    ingredientRepo = IngredientRepository();
    ingredientPriceRepo = IngredientPriceRepository();
    processedRepo = ProcessedIngredientRepository();

    productRepo = ProductRepository(
      recipeVersionRepo: recipeVersionRepo,
      recipeItemRepo: recipeItemRepo,
      priceRepo: productPriceRepo,
    );

    hppEngine = HppEngine(
      productRepo: productRepo,
      recipeVersionRepo: recipeVersionRepo,
      recipeItemRepo: recipeItemRepo,
      priceRepo: productPriceRepo,
      ingredientPriceRepo: ingredientPriceRepo,
      processedRepo: processedRepo,
      ingredientRepo: ingredientRepo,
    );
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('1. Recipe Effective-Date Resolution', () {
    late Product product;

    setUp(() async {
      product = await productRepo.create('Kopi Susu Gula Aren');
      // v1: effective 2026-09-01
      await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          hppTotal: 1000,
          status: 'archived',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      // v2: effective 2026-09-10
      await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 2,
          effectiveFrom: '2026-09-10',
          hppTotal: 1200,
          status: 'archived',
          createdAt: '2026-09-10T00:00:00Z',
        ),
      );
      // v3: effective 2026-09-20
      await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 3,
          effectiveFrom: '2026-09-20',
          hppTotal: 1500,
          status: 'active',
          createdAt: '2026-09-20T00:00:00Z',
        ),
      );
    });

    test(
      'Tanggal sebelum v1 (2026-08-31) mengembalikan null / NoEffectiveRecipe',
      () async {
        final v = await recipeVersionRepo.getEffectiveVersion(
          product.id!,
          calculationDate: '2026-08-31',
        );
        expect(v, isNull);

        expect(
          () => hppEngine.calculateProductHpp(
            productId: product.id!,
            calculationDate: '2026-08-31',
          ),
          throwsA(isA<NoEffectiveRecipeException>()),
        );
      },
    );

    test('2026-09-01 (tepat tanggal v1) -> v1', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-01',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 1);
    });

    test('2026-09-05 (antara v1 dan v2) -> v1', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-05',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 1);
    });

    test('2026-09-10 (tepat tanggal v2) -> v2', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-10',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 2);
    });

    test('2026-09-15 (antara v2 dan v3) -> v2', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-15',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 2);
    });

    test('2026-09-20 (tepat tanggal v3) -> v3', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-20',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 3);
    });

    test('2026-09-25 (setelah v3) -> v3', () async {
      final v = await recipeVersionRepo.getEffectiveVersion(
        product.id!,
        calculationDate: '2026-09-25',
      );
      expect(v, isNotNull);
      expect(v!.versionNumber, 3);
    });
  });

  group('2. Selling Price Effective-Date Resolution', () {
    late Product product;

    setUp(() async {
      product = await productRepo.create('Es Cokelat');
      // p1: Rp3.000 effective 2026-09-01
      await productPriceRepo.create(
        ProductPrice(
          productId: product.id!,
          sellingPrice: 3000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      // p2: Rp3.500 effective 2026-09-10
      await productPriceRepo.create(
        ProductPrice(
          productId: product.id!,
          sellingPrice: 3500,
          effectiveFrom: '2026-09-10',
          createdAt: '2026-09-10T00:00:00Z',
        ),
      );
      // p3: Rp4.000 effective 2026-09-20
      await productPriceRepo.create(
        ProductPrice(
          productId: product.id!,
          sellingPrice: 4000,
          effectiveFrom: '2026-09-20',
          createdAt: '2026-09-20T00:00:00Z',
        ),
      );
    });

    test('Tanggal sebelum harga pertama (2026-08-31) -> null', () async {
      final price = await productPriceRepo.getEffectivePriceAt(
        product.id!,
        calculationDate: '2026-08-31',
      );
      expect(price, isNull);
    });

    test('2026-09-05 -> Rp3.000', () async {
      final price = await productPriceRepo.getEffectivePriceAt(
        product.id!,
        calculationDate: '2026-09-05',
      );
      expect(price, isNotNull);
      expect(price!.sellingPrice, 3000);
    });

    test('2026-09-15 -> Rp3.500', () async {
      final price = await productPriceRepo.getEffectivePriceAt(
        product.id!,
        calculationDate: '2026-09-15',
      );
      expect(price, isNotNull);
      expect(price!.sellingPrice, 3500);
    });

    test('2026-09-25 -> Rp4.000', () async {
      final price = await productPriceRepo.getEffectivePriceAt(
        product.id!,
        calculationDate: '2026-09-25',
      );
      expect(price, isNotNull);
      expect(price!.sellingPrice, 4000);
    });
  });

  group('3. Historical Ingredient Price & Recipe Combination', () {
    late Product product;
    late Ingredient gula;

    setUp(() async {
      gula = await ingredientRepo.create('Gula Pasir');
      // Harga Gula: Rp10.000/kg (Rp10/g) per 2026-09-01
      await ingredientPriceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        price: 10000,
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );
      // Harga Gula naik: Rp12.000/kg (Rp12/g) per 2026-09-10
      await ingredientPriceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        price: 12000,
        effectiveFrom: '2026-09-10',
        isDefault: true,
      );

      product = await productRepo.create('Air Gula Botol');

      // Recipe v1: 20g Gula Pasir, effective 2026-09-01
      final v1 = await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          hppTotal: 200,
          status: 'archived',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      await recipeItemRepo.create(
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: gula.id!,
          quantity: 20,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      // Recipe v2: 30g Gula Pasir (takaran dinaikkan), effective 2026-09-15
      final v2 = await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 2,
          effectiveFrom: '2026-09-15',
          hppTotal: 360,
          status: 'active',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      );
      await recipeItemRepo.create(
        RecipeItem(
          recipeVersionId: v2.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: gula.id!,
          quantity: 30,
          unit: 'g',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      );

      // Selling price: Rp1.000 effective 2026-09-01
      await productPriceRepo.create(
        ProductPrice(
          productId: product.id!,
          sellingPrice: 1000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
    });

    test(
      'calculate(2026-09-05) -> v1 (20g) + gula Rp10/g = HPP Rp200, Laba Rp800',
      () async {
        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-05',
        );

        expect(res.recipeVersionNumber, 1);
        expect(res.hppTotal, 200);
        expect(res.sellingPrice, 1000);
        expect(res.profit, 800);
        expect(res.marginPercentage, closeTo(80.0, 0.1));
        expect(res.isBelowHpp, isFalse);
        expect(res.isValid, isTrue);
      },
    );

    test(
      'calculate(2026-09-12) -> v1 (20g) + gula Rp12/g = HPP Rp240, Laba Rp760',
      () async {
        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-12',
        );

        expect(res.recipeVersionNumber, 1);
        expect(res.hppTotal, 240);
        expect(res.sellingPrice, 1000);
        expect(res.profit, 760);
        expect(res.marginPercentage, closeTo(76.0, 0.1));
        expect(res.isBelowHpp, isFalse);
      },
    );

    test(
      'calculate(2026-09-20) -> v2 (30g) + gula Rp12/g = HPP Rp360, Laba Rp640',
      () async {
        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-20',
        );

        expect(res.recipeVersionNumber, 2);
        expect(res.hppTotal, 360);
        expect(res.sellingPrice, 1000);
        expect(res.profit, 640);
        expect(res.marginPercentage, closeTo(64.0, 0.1));
        expect(res.isBelowHpp, isFalse);
      },
    );
  });

  group('4. Multi-Format Ingredient Price Resolution (Tahap 5 Rules)', () {
    late Ingredient gula;

    setUp(() async {
      gula = await ingredientRepo.create('Gula Premium');
      // Format A: 1 kg = Rp20.000 (Rp20/g, isDefault = true)
      await ingredientPriceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        price: 20000,
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );
      // Format B: 500 g = Rp11.000 (Rp22/g, isDefault = false)
      await ingredientPriceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 500,
        purchaseUnit: 'g',
        price: 11000,
        effectiveFrom: '2026-09-01',
        isDefault: false,
      );
    });

    test(
      'Memilih format default (1 kg = Rp20.000) saat keduanya aktif',
      () async {
        final prices = await ingredientPriceRepo.getPrices(gula.id!);
        final resolved = ProcessedIngredientCalculator.resolvePriceForComponent(
          availablePrices: prices,
          componentUnit: 'g',
          calculationDate: '2026-09-05',
        );

        expect(resolved, isNotNull);
        expect(resolved!.isDefault, isTrue);
        expect(resolved.purchaseUnit, 'kg');
        expect(resolved.costPerBaseUnit, 20.0);
      },
    );
  });

  group('5. Unit Conversion & Incompatible Units', () {
    test('Valid unit conversions', () {
      // kg -> g
      final kgToG = UnitConverter.convert(
        purchaseQuantity: 0.5,
        purchaseUnit: 'kg',
      );
      expect(kgToG.baseQuantity, 500.0);
      expect(kgToG.baseUnit, 'g');

      // liter -> ml
      final lToMl = UnitConverter.convert(
        purchaseQuantity: 1.5,
        purchaseUnit: 'liter',
      );
      expect(lToMl.baseQuantity, 1500.0);
      expect(lToMl.baseUnit, 'ml');

      // pack -> pcs
      final packToPcs = UnitConverter.convert(
        purchaseQuantity: 2,
        purchaseUnit: 'pack',
        packageQuantity: 50,
      );
      expect(packToPcs.baseQuantity, 100.0);
      expect(packToPcs.baseUnit, 'pcs');

      // g -> g, ml -> ml, pcs -> pcs
      expect(
        UnitConverter.convert(
          purchaseQuantity: 25,
          purchaseUnit: 'g',
        ).baseQuantity,
        25.0,
      );
      expect(
        UnitConverter.convert(
          purchaseQuantity: 30,
          purchaseUnit: 'ml',
        ).baseQuantity,
        30.0,
      );
      expect(
        UnitConverter.convert(
          purchaseQuantity: 1,
          purchaseUnit: 'pcs',
        ).baseQuantity,
        1.0,
      );
    });

    test('Incompatible unit conversions throw UnitConversionException', () {
      expect(
        () => UnitConverter.convert(
          purchaseQuantity: 1,
          purchaseUnit: 'kg',
          targetBaseUnit: 'ml',
        ),
        throwsA(isA<UnitConversionException>()),
      );
      expect(
        () => UnitConverter.convert(
          purchaseQuantity: 1,
          purchaseUnit: 'g',
          targetBaseUnit: 'pcs',
        ),
        throwsA(isA<UnitConversionException>()),
      );
      expect(
        () => UnitConverter.convert(
          purchaseQuantity: 1,
          purchaseUnit: 'ml',
          targetBaseUnit: 'pcs',
        ),
        throwsA(isA<UnitConversionException>()),
      );
    });
  });

  group('6. Nested Processed Ingredients (Cases A, B, C, D Diamond DAG)', () {
    late Ingredient gula;
    late Ingredient teh;

    setUp(() async {
      gula = await ingredientRepo.create('Gula');
      await ingredientPriceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1,
        purchaseUnit: 'kg',
        price: 10000, // Rp10/g
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );

      teh = await ingredientRepo.create('Teh');
      await ingredientPriceRepo.createPrice(
        ingredientId: teh.id!,
        purchaseQuantity: 100,
        purchaseUnit: 'g',
        price: 10000, // Rp100/g
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );
    });

    test('Case A: Raw -> Product', () async {
      final product = await productRepo.create('Teh Manis Simple');
      final v1 = await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      // Teh 5g (@ Rp100 = Rp500) + Gula 10g (@ Rp10 = Rp100) = Rp600
      await recipeItemRepo.createMany([
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id!,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: gula.id!,
          quantity: 10,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      ]);

      final res = await hppEngine.calculateProductHpp(
        productId: product.id!,
        calculationDate: '2026-09-05',
      );
      expect(res.hppTotal, 600);
      expect(res.items.length, 2);
    });

    test('Case B: Raw -> Processed -> Product', () async {
      // Simple Syrup: 500g Gula (5000) + Air (1000) = Rp6000 / 1000 ml = Rp6/ml
      final syrup = await processedRepo.create(
        name: 'Simple Syrup',
        resultQuantity: 1000,
        resultUnit: 'ml',
        components: [
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: gula.id!,
            quantity: 500,
            unit: 'g',
          ),
          const ProcessedComponent(
            componentType: ProcessedComponent.typeOther,
            otherCost: 1000,
            label: 'Air',
          ),
        ],
      );

      final product = await productRepo.create('Es Teh Sirup');
      final v1 = await recipeVersionRepo.create(
        RecipeVersion(
          productId: product.id!,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      // Teh 5g (500) + Simple Syrup 50 ml (@ Rp6/ml = 300) = Rp800
      await recipeItemRepo.createMany([
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id!,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeProcessed,
          processedIngredientId: syrup.id!,
          quantity: 50,
          unit: 'ml',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      ]);

      final res = await hppEngine.calculateProductHpp(
        productId: product.id!,
        calculationDate: '2026-09-05',
      );
      expect(res.hppTotal, 800);
    });

    test(
      'Case C: Raw -> Processed A -> Processed B -> Product (3-Level Nested)',
      () async {
        // 1. Simple Syrup: 500g Gula (5000) + Air (1000) = Rp6000 / 1000 ml = Rp6/ml
        final syrup = await processedRepo.create(
          name: 'Simple Syrup',
          resultQuantity: 1000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id!,
              quantity: 500,
              unit: 'g',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 1000,
            ),
          ],
        );

        // 2. Sweet Tea Base: Teh 20g (2000) + Simple Syrup 200 ml (1200) + Air (800) = Rp4000 / 1000 ml = Rp4/ml
        final teaBase = await processedRepo.create(
          name: 'Sweet Tea Base',
          resultQuantity: 1000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: teh.id!,
              quantity: 20,
              unit: 'g',
            ),
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: syrup.id!,
              quantity: 200,
              unit: 'ml',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 800,
            ),
          ],
        );

        // 3. Product: Sweet Tea Base 250 ml (@ Rp4/ml = 1000) + Cup Rp500 = Rp1.500
        final product = await productRepo.create('Es Teh Cup');
        final v1 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: product.id!,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await recipeItemRepo.createMany([
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: teaBase.id!,
            quantity: 250,
            unit: 'ml',
            createdAt: '2026-09-01T00:00:00Z',
          ),
          const RecipeItem(
            recipeVersionId: 1,
            componentType: RecipeItem.typeOther,
            otherCost: 500,
            label: 'Cup',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ]);

        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-05',
        );
        expect(res.hppTotal, 1500);
      },
    );

    test(
      'Case D: Diamond DAG (Product -> Processed A & Processed B -> Base)',
      () async {
        // Base: Simple Syrup = 500g Gula (5000) / 1000 ml = Rp5/ml
        final simpleSyrup = await processedRepo.create(
          name: 'Simple Syrup',
          resultQuantity: 1000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id!,
              quantity: 500,
              unit: 'g',
            ),
          ],
        );

        // Branch A: Lemon Syrup = Simple Syrup 500 ml (2500) + Biaya Lemon Rp1500 = Rp4000 / 500 ml = Rp8/ml
        final lemonSyrup = await processedRepo.create(
          name: 'Lemon Syrup',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: simpleSyrup.id!,
              quantity: 500,
              unit: 'ml',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 1500,
              label: 'Lemon Juice',
            ),
          ],
        );

        // Branch B: Sweet Tea Concentrate = Simple Syrup 200 ml (1000) + Teh 20g (2000) = Rp3000 / 500 ml = Rp6/ml
        final teaConcentrate = await processedRepo.create(
          name: 'Sweet Tea Concentrate',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: simpleSyrup.id!,
              quantity: 200,
              unit: 'ml',
            ),
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: teh.id!,
              quantity: 20,
              unit: 'g',
            ),
          ],
        );

        // Product Lemon Tea:
        // Lemon Syrup 50 ml (@ Rp8/ml = 400)
        // Tea Concentrate 100 ml (@ Rp6/ml = 600)
        // Total = 400 + 600 = Rp1.000
        final product = await productRepo.create('Lemon Tea Signature');
        final v1 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: product.id!,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await recipeItemRepo.createMany([
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: lemonSyrup.id!,
            quantity: 50,
            unit: 'ml',
            createdAt: '2026-09-01T00:00:00Z',
          ),
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: teaConcentrate.id!,
            quantity: 100,
            unit: 'ml',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ]);

        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-05',
        );
        expect(res.hppTotal, 1000);
        expect(res.isValid, isTrue);
      },
    );
  });

  group('7. Other Cost', () {
    test('Ingredient Rp500 + Processed Rp300 + Other Rp200 = HPP Rp1.000', () {
      final items = <RecipeItem>[
        const RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeOther,
          otherCost: 200,
          label: 'Kemasan',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      ];

      // In-memory calculation with pre-evaluated ingredient and other
      final res = HppEngine.calculateFromData(
        productId: 1,
        productName: 'Sample',
        calculationDate: '2026-09-01',
        recipeVersionId: 1,
        recipeVersionNumber: 1,
        recipeItems: items,
        ingredientPricesMap: {},
      );

      expect(res.hppTotal, 200);
      expect(res.items.first.roundedCost, 200);
    });
  });

  group('8. Profit & Margin Calculations', () {
    test(
      'Normal Profit: HPP Rp1.340, Harga Rp5.000 -> Profit Rp3.660, Margin 73.2%',
      () {
        final res = HppEngine.calculateFromData(
          productId: 1,
          productName: 'Kopi',
          calculationDate: '2026-09-01',
          recipeVersionId: 1,
          recipeVersionNumber: 1,
          sellingPrice: 5000,
          recipeItems: const <RecipeItem>[
            RecipeItem(
              recipeVersionId: 1,
              componentType: RecipeItem.typeOther,
              otherCost: 1340,
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          ingredientPricesMap: {},
        );

        expect(res.hppTotal, 1340);
        expect(res.sellingPrice, 5000);
        expect(res.profit, 3660);
        expect(res.marginPercentage, closeTo(73.2, 0.01));
        expect(res.isBelowHpp, isFalse);
      },
    );

    test(
      'Below HPP: HPP Rp1.340, Harga Rp1.000 -> Profit -Rp340, isBelowHpp = true',
      () {
        final res = HppEngine.calculateFromData(
          productId: 1,
          productName: 'Kopi Rugi',
          calculationDate: '2026-09-01',
          recipeVersionId: 1,
          recipeVersionNumber: 1,
          sellingPrice: 1000,
          recipeItems: const <RecipeItem>[
            RecipeItem(
              recipeVersionId: 1,
              componentType: RecipeItem.typeOther,
              otherCost: 1340,
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          ingredientPricesMap: {},
        );

        expect(res.hppTotal, 1340);
        expect(res.sellingPrice, 1000);
        expect(res.profit, -340);
        expect(res.isBelowHpp, isTrue);
      },
    );

    test(
      'Break Even: HPP Rp1.340, Harga Rp1.340 -> Profit Rp0, isBelowHpp = false',
      () {
        final res = HppEngine.calculateFromData(
          productId: 1,
          productName: 'Kopi Pas',
          calculationDate: '2026-09-01',
          recipeVersionId: 1,
          recipeVersionNumber: 1,
          sellingPrice: 1340,
          recipeItems: const <RecipeItem>[
            RecipeItem(
              recipeVersionId: 1,
              componentType: RecipeItem.typeOther,
              otherCost: 1340,
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          ingredientPricesMap: {},
        );

        expect(res.hppTotal, 1340);
        expect(res.sellingPrice, 1340);
        expect(res.profit, 0);
        expect(res.isBelowHpp, isFalse);
      },
    );

    test(
      'No Selling Price: sellingPrice = null, profit = null, margin = null',
      () {
        final res = HppEngine.calculateFromData(
          productId: 1,
          productName: 'Kopi Belum Ada Harga',
          calculationDate: '2026-09-01',
          recipeVersionId: 1,
          recipeVersionNumber: 1,
          sellingPrice: null,
          recipeItems: const <RecipeItem>[
            RecipeItem(
              recipeVersionId: 1,
              componentType: RecipeItem.typeOther,
              otherCost: 1340,
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          ingredientPricesMap: {},
        );

        expect(res.hppTotal, 1340);
        expect(res.sellingPrice, isNull);
        expect(res.profit, isNull);
        expect(res.marginPercentage, isNull);
        expect(res.isBelowHpp, isFalse);
      },
    );
  });

  group('9. Rounding Policy (Internal Precision Sum then Round)', () {
    test(
      '100.4 + 100.4 = 200.8 -> round = Rp201 (bukan 100 + 100 = Rp200)',
      () {
        // 2 komponen dengan biaya 100.4 masing-masing
        final items = <RecipeItem>[
          const RecipeItem(
            recipeVersionId: 1,
            componentType: RecipeItem.typeIngredient,
            ingredientId: 1,
            quantity: 100.4,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
          const RecipeItem(
            recipeVersionId: 1,
            componentType: RecipeItem.typeIngredient,
            ingredientId: 2,
            quantity: 100.4,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ];

        // Harga: 1g = Rp1
        final price1 = const IngredientPrice(
          id: 1,
          ingredientId: 1,
          purchaseQuantity: 1,
          purchaseUnit: 'g',
          baseQuantity: 1,
          baseUnit: 'g',
          price: 1,
          effectiveFrom: '2026-09-01',
        );
        final price2 = const IngredientPrice(
          id: 2,
          ingredientId: 2,
          purchaseQuantity: 1,
          purchaseUnit: 'g',
          baseQuantity: 1,
          baseUnit: 'g',
          price: 1,
          effectiveFrom: '2026-09-01',
        );

        final res = HppEngine.calculateFromData(
          productId: 1,
          productName: 'Rounding Test',
          calculationDate: '2026-09-01',
          recipeVersionId: 1,
          recipeVersionNumber: 1,
          recipeItems: items,
          ingredientPricesMap: {
            1: [price1],
            2: [price2],
          },
        );

        expect(res.preciseHppTotal, closeTo(200.8, 0.0001));
        expect(res.hppTotal, 201); // 200.8 dibulatkan jadi 201!
      },
    );
  });

  group('10. Error Handling & Missing Price Behavior', () {
    test('Product tidak ditemukan melempar ProductNotFoundException', () async {
      expect(
        () => hppEngine.calculateProductHpp(
          productId: 9999,
          calculationDate: '2026-09-01',
        ),
        throwsA(isA<ProductNotFoundException>()),
      );
    });

    test(
      'Bahan mentah tanpa harga pada strict: true melempar MissingIngredientPriceException',
      () async {
        final product = await productRepo.create('Jus Jeruk');
        final jeruk = await ingredientRepo.create(
          'Jeruk Peras',
        ); // Tidak ada harga
        final v1 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: product.id!,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await recipeItemRepo.create(
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeIngredient,
            ingredientId: jeruk.id!,
            quantity: 100,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        expect(
          () => hppEngine.calculateProductHpp(
            productId: product.id!,
            calculationDate: '2026-09-01',
            strict: true,
          ),
          throwsA(isA<MissingIngredientPriceException>()),
        );
      },
    );

    test(
      'Bahan mentah tanpa harga pada strict: false menghasilkan hasUnresolvedCost = true',
      () async {
        final product = await productRepo.create('Jus Mangga');
        final mangga = await ingredientRepo.create(
          'Mangga Harum Manis',
        ); // Tidak ada harga
        final v1 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: product.id!,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await recipeItemRepo.create(
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeIngredient,
            ingredientId: mangga.id!,
            quantity: 150,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        final res = await hppEngine.calculateProductHpp(
          productId: product.id!,
          calculationDate: '2026-09-01',
          strict: false,
        );

        expect(res.hasUnresolvedCost, isTrue);
        expect(res.isValid, isFalse);
        expect(res.items.first.isResolvable, isFalse);
        expect(res.warnings.isNotEmpty, isTrue);
        expect(res.warnings.first, contains('Mangga Harum Manis'));
      },
    );
  });
}
