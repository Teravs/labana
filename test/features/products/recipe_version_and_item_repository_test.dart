import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/data/processed_ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/data/recipe_item_repository.dart';
import 'package:labana/features/products/data/recipe_version_repository.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/models/recipe_version.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late RecipeVersionRepository versionRepo;
  late RecipeItemRepository itemRepo;
  late IngredientRepository ingredientRepo;
  late ProcessedIngredientRepository processedRepo;
  late int productId;

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
    productRepo = ProductRepository();
    versionRepo = RecipeVersionRepository();
    itemRepo = RecipeItemRepository();
    ingredientRepo = IngredientRepository();
    processedRepo = ProcessedIngredientRepository();

    final product = await productRepo.create('Es Teh Manis');
    productId = product.id!;
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('RecipeVersionRepository Tests', () {
    test('15. create first version = v1', () async {
      final nextVer = await versionRepo.getNextVersionNumber(productId);
      expect(nextVer, 1);

      final v1 = await versionRepo.create(
        RecipeVersion(
          productId: productId,
          versionNumber: nextVer,
          effectiveFrom: '2026-09-01',
          hppTotal: 2000,
          status: 'active',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      expect(v1.id, isNotNull);
      expect(v1.versionNumber, 1);
      expect(v1.isActive, true);

      final active = await versionRepo.getActiveVersion(productId);
      expect(active?.id, v1.id);
    });

    test(
      '16 & 17. create second version = v2 and archive old version',
      () async {
        // v1
        final v1 = await versionRepo.create(
          RecipeVersion(
            productId: productId,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            hppTotal: 2000,
            status: 'active',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        // Archive v1
        await versionRepo.archiveActiveVersions(productId);

        // Next version is v2
        final nextVer = await versionRepo.getNextVersionNumber(productId);
        expect(nextVer, 2);

        // v2
        final v2 = await versionRepo.create(
          RecipeVersion(
            productId: productId,
            versionNumber: nextVer,
            effectiveFrom: '2026-09-15',
            hppTotal: 2200,
            status: 'active',
            createdAt: '2026-09-15T00:00:00Z',
          ),
        );

        expect(v2.versionNumber, 2);

        final active = await versionRepo.getActiveVersion(productId);
        expect(active?.id, v2.id);

        final checkV1 = await versionRepo.getById(v1.id!);
        expect(checkV1?.isArchived, true);
      },
    );

    test('18. version history preserved', () async {
      await versionRepo.create(
        RecipeVersion(
          productId: productId,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          hppTotal: 2000,
          status: 'archived',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      await versionRepo.create(
        RecipeVersion(
          productId: productId,
          versionNumber: 2,
          effectiveFrom: '2026-09-15',
          hppTotal: 2200,
          status: 'active',
          createdAt: '2026-09-15T00:00:00Z',
        ),
      );

      final history = await versionRepo.getByProductId(productId);
      expect(history.length, 2);
      expect(history[0].versionNumber, 2);
      expect(history[1].versionNumber, 1);
    });
  });

  group('RecipeItemRepository Tests', () {
    late int versionId;

    setUp(() async {
      final v = await versionRepo.create(
        RecipeVersion(
          productId: productId,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          hppTotal: 2000,
          status: 'active',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      versionId = v.id!;
    });

    test('19. ingredient item valid', () async {
      final teh = await ingredientRepo.create('Teh Celup');
      final item = RecipeItem(
        recipeVersionId: versionId,
        componentType: RecipeItem.typeIngredient,
        ingredientId: teh.id,
        quantity: 1,
        unit: 'pcs',
        createdAt: '2026-09-01T00:00:00Z',
      );

      final created = await itemRepo.create(item);
      expect(created.id, isNotNull);
      expect(created.isIngredient, true);
    });

    test('20. processed item valid', () async {
      final gula = await ingredientRepo.create('Gula Pasir');
      final syrup = await processedRepo.create(
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
        ],
      );

      final item = RecipeItem(
        recipeVersionId: versionId,
        componentType: RecipeItem.typeProcessed,
        processedIngredientId: syrup.id,
        quantity: 30,
        unit: 'ml',
        createdAt: '2026-09-01T00:00:00Z',
      );

      final created = await itemRepo.create(item);
      expect(created.id, isNotNull);
      expect(created.isProcessed, true);
    });

    test('21. other item valid', () async {
      final item = RecipeItem(
        recipeVersionId: versionId,
        componentType: RecipeItem.typeOther,
        otherCost: 500,
        createdAt: '2026-09-01T00:00:00Z',
      );

      final created = await itemRepo.create(item);
      expect(created.id, isNotNull);
      expect(created.isOther, true);
      expect(created.otherCost, 500);
    });

    test('22. invalid component data rejected', () async {
      // Ingredient tanpa ingredient_id
      expect(
        () => RecipeItemRepository.validateItem(
          RecipeItem(
            recipeVersionId: versionId,
            componentType: RecipeItem.typeIngredient,
            quantity: 10,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Ingredient dengan kuantitas <= 0
      expect(
        () => RecipeItemRepository.validateItem(
          RecipeItem(
            recipeVersionId: versionId,
            componentType: RecipeItem.typeIngredient,
            ingredientId: 1,
            quantity: 0,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Processed dengan ingredient_id terisi
      expect(
        () => RecipeItemRepository.validateItem(
          RecipeItem(
            recipeVersionId: versionId,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: 2,
            ingredientId: 1,
            quantity: 10,
            unit: 'ml',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Other dengan otherCost negatif
      expect(
        () => RecipeItemRepository.validateItem(
          RecipeItem(
            recipeVersionId: versionId,
            componentType: RecipeItem.typeOther,
            otherCost: -100,
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('23. delete unsaved recipe item / delete by id', () async {
      final teh = await ingredientRepo.create('Teh');
      final item = await itemRepo.create(
        RecipeItem(
          recipeVersionId: versionId,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      final deletedCount = await itemRepo.delete(item.id!);
      expect(deletedCount, 1);

      final items = await itemRepo.getByRecipeVersionId(versionId);
      expect(items.isEmpty, true);
    });

    test(
      'Historical recipe item preserved even when master ingredient becomes inactive',
      () async {
        final kopi = await ingredientRepo.create('Kopi Hitam');
        await itemRepo.create(
          RecipeItem(
            recipeVersionId: versionId,
            componentType: RecipeItem.typeIngredient,
            ingredientId: kopi.id,
            quantity: 15,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        // Deaktivasi kopi hitam
        await ingredientRepo.deactivate(kopi.id!);

        // Resep historis tetap harus dapat membaca nama 'Kopi Hitam'
        final items = await itemRepo.getByRecipeVersionId(versionId);
        expect(items.length, 1);
        expect(items.first.ingredientName, 'Kopi Hitam');
      },
    );
  });
}
