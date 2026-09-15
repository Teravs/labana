import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_price_repository.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/ingredients/models/ingredient.dart';
import 'package:labana/features/ingredients/models/ingredient_price.dart';
import 'package:labana/features/processed_ingredients/data/processed_ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/processed_ingredients/models/processed_ingredient.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/services/recipe_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late IngredientRepository ingredientRepo;
  late IngredientPriceRepository priceRepo;
  late ProcessedIngredientRepository processedRepo;

  late Ingredient gula;
  late Ingredient teh;
  late ProcessedIngredient syrup;

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
    ingredientRepo = IngredientRepository();
    priceRepo = IngredientPriceRepository();
    processedRepo = ProcessedIngredientRepository();

    // Setup data dasar
    gula = await ingredientRepo.create('Gula Pasir');
    await priceRepo.createPrice(
      ingredientId: gula.id!,
      price: 15000,
      purchaseQuantity: 1,
      purchaseUnit: 'kg',
      effectiveFrom: '2026-09-01',
      isDefault: true,
    );

    teh = await ingredientRepo.create('Teh');
    await priceRepo.createPrice(
      ingredientId: teh.id!,
      price: 10000,
      purchaseQuantity: 100,
      purchaseUnit: 'g',
      effectiveFrom: '2026-09-01',
      isDefault: true,
    );

    // Setup processed ingredient: Simple Syrup (500 g gula + 1000 air = 750 ml)
    // Biaya gula = 500 * (15000 / 1000) = 7500. Total = 7500 + 1000 = 8500.
    // Cost per ml = 8500 / 750 = 11.3333...
    syrup = await processedRepo.create(
      name: 'Simple Syrup',
      resultQuantity: 750,
      resultUnit: 'ml',
      components: [
        ProcessedComponent(
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: gula.id,
          quantity: 500,
          unit: 'g',
        ),
        const ProcessedComponent(
          componentType: ProcessedComponent.typeOther,
          otherCost: 1000,
        ),
      ],
    );
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('RecipeCalculator Tests', () {
    test('24. ingredient-only recipe: Teh 5g', () async {
      final prices = await priceRepo.getPrices(teh.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {teh.id!: prices};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-15T00:00:00Z',
          ingredientName: 'Teh',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
      );

      // 5g @ Rp100/g = Rp500
      expect(result.hppTotal, 500);
      expect(result.hasUnresolvedCost, false);
      expect(result.itemResults.first.calculatedCost, 500.0);
    });

    test('25. processed-only recipe: Simple Syrup 30 ml', () async {
      final gulaPrices = await priceRepo.getPrices(gula.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {gula.id!: gulaPrices};
      final procMap = {syrup.id!: syrup};
      final syrupComponents = await processedRepo.getComponents(syrup.id!);
      final procCompMap = {syrup.id!: syrupComponents};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeProcessed,
          processedIngredientId: syrup.id,
          quantity: 30,
          unit: 'ml',
          createdAt: '2026-09-15T00:00:00Z',
          processedIngredientName: 'Simple Syrup',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
        allProcessedIngredients: procMap,
        allProcessedComponents: procCompMap,
      );

      // 30 ml * (8500 / 750) = 340.0
      expect(result.hppTotal, 340);
      expect(result.itemResults.first.calculatedCost, closeTo(340.0, 0.01));
    });

    test('26. mixed ingredient + processed: Teh 5g + Syrup 30 ml', () async {
      final gulaPrices = await priceRepo.getPrices(gula.id!);
      final tehPrices = await priceRepo.getPrices(teh.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {
        gula.id!: gulaPrices,
        teh.id!: tehPrices,
      };
      final procMap = {syrup.id!: syrup};
      final syrupComponents = await processedRepo.getComponents(syrup.id!);
      final procCompMap = {syrup.id!: syrupComponents};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-15T00:00:00Z',
        ),
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeProcessed,
          processedIngredientId: syrup.id,
          quantity: 30,
          unit: 'ml',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
        allProcessedIngredients: procMap,
        allProcessedComponents: procCompMap,
      );

      // 500 + 340 = 840
      expect(result.hppTotal, 840);
    });

    test('27. other cost: Cup & Straw Rp500', () {
      final items = [
        const RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeOther,
          otherCost: 500,
          createdAt: '2026-09-15T00:00:00Z',
          label: 'Cup & Straw',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
      );

      expect(result.hppTotal, 500);
      expect(result.itemResults.first.calculatedCost, 500.0);
    });

    test('28. mixed + other: Teh 5g + Syrup 30ml + Cup Rp500', () async {
      final gulaPrices = await priceRepo.getPrices(gula.id!);
      final tehPrices = await priceRepo.getPrices(teh.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {
        gula.id!: gulaPrices,
        teh.id!: tehPrices,
      };
      final procMap = {syrup.id!: syrup};
      final syrupComponents = await processedRepo.getComponents(syrup.id!);
      final procCompMap = {syrup.id!: syrupComponents};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-15T00:00:00Z',
        ),
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeProcessed,
          processedIngredientId: syrup.id,
          quantity: 30,
          unit: 'ml',
          createdAt: '2026-09-15T00:00:00Z',
        ),
        const RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeOther,
          otherCost: 500,
          createdAt: '2026-09-15T00:00:00Z',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
        allProcessedIngredients: procMap,
        allProcessedComponents: procCompMap,
      );

      // 500 + 340 + 500 = 1340
      expect(result.hppTotal, 1340);
    });

    test('29. unit conversion: Gula Pasir 0.05 kg (50g)', () async {
      final gulaPrices = await priceRepo.getPrices(gula.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {gula.id!: gulaPrices};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeIngredient,
          ingredientId: gula.id,
          quantity: 0.05,
          unit: 'kg',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      ];

      final result = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
      );

      // 0.05 kg = 50 g @ Rp15/g = Rp750
      expect(result.hppTotal, 750);
    });

    test('31. historical effective price is used', () async {
      // Tambah harga baru teh efektif 2026-10-01 (naik jadi Rp15.000 / 100g)
      await priceRepo.createPrice(
        ingredientId: teh.id!,
        price: 15000,
        purchaseQuantity: 100,
        purchaseUnit: 'g',
        effectiveFrom: '2026-10-01',
      );

      final tehPrices = await priceRepo.getPrices(teh.id!);
      final Map<int, List<IngredientPrice>> pricesMap = {teh.id!: tehPrices};

      final items = [
        RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      ];

      // Kalkulasi untuk resep tanggal 2026-09-15 harus menggunakan harga lama (Rp10.000 / 100g = Rp500)
      final septResult = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-09-15',
        ingredientPricesMap: pricesMap,
      );
      expect(septResult.hppTotal, 500);

      // Kalkulasi untuk resep tanggal 2026-10-05 harus menggunakan harga baru (Rp15.000 / 100g = Rp750)
      final octResult = RecipeCalculator.calculateRecipeCost(
        items: items,
        calculationDate: '2026-10-05',
        ingredientPricesMap: pricesMap,
      );
      expect(octResult.hppTotal, 750);
    });

    test('32. profit preview and warning when selling price < HPP', () {
      final profit = RecipeCalculator.calculateProfit(
        sellingPrice: 5000,
        hppTotal: 2100,
      );
      expect(profit, 2900);
      expect(
        RecipeCalculator.isSellingBelowHpp(
          sellingPrice: 5000,
          hppTotal: 2100,
        ),
        false,
      );

      // Warning when sellingPrice < HPP
      expect(
        RecipeCalculator.isSellingBelowHpp(
          sellingPrice: 2000,
          hppTotal: 2100,
        ),
        true,
      );
    });
  });
}

