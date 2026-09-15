import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/products/data/product_price_repository.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/data/recipe_item_repository.dart';
import 'package:labana/features/products/data/recipe_version_repository.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late RecipeVersionRepository recipeVersionRepo;
  late RecipeItemRepository recipeItemRepo;
  late ProductPriceRepository productPriceRepo;
  late IngredientRepository ingredientRepo;

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
    productRepo = ProductRepository(
      recipeVersionRepo: recipeVersionRepo,
      recipeItemRepo: recipeItemRepo,
      priceRepo: productPriceRepo,
    );
    ingredientRepo = IngredientRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('ProductRepository Tests', () {
    test('1. create product', () async {
      final product = await productRepo.create('Es Teh Manis');
      expect(product.id, isNotNull);
      expect(product.name, 'Es Teh Manis');
      expect(product.isActive, true);
    });

    test('2. get product (getAll, getActive, getInactive, getById)', () async {
      final p1 = await productRepo.create('Es Teh');
      final p2 = await productRepo.create('Es Jeruk');
      await productRepo.deactivate(p2.id!);

      final all = await productRepo.getAll();
      expect(all.length, 2);

      final active = await productRepo.getActive();
      expect(active.length, 1);
      expect(active.first.name, 'Es Teh');

      final inactive = await productRepo.getInactive();
      expect(inactive.length, 1);
      expect(inactive.first.name, 'Es Jeruk');

      final byId = await productRepo.getById(p1.id!);
      expect(byId?.name, 'Es Teh');
    });

    test('3. update product name', () async {
      final p = await productRepo.create('Es Teh');
      final updated = await productRepo.update(p.id!, name: 'Es Teh Jumbo');
      expect(updated.name, 'Es Teh Jumbo');

      final fetched = await productRepo.getById(p.id!);
      expect(fetched?.name, 'Es Teh Jumbo');
    });

    test('4. duplicate active name rejected (case-insensitive)', () async {
      await productRepo.create('Es Teh Manis');

      expect(
        () => productRepo.create('es teh manis'),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => productRepo.create('  ES TEH MANIS  '),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      '5. update same product name allowed, but duplicate other active rejected',
      () async {
        final p1 = await productRepo.create('Es Teh');
        final p2 = await productRepo.create('Es Jeruk');

        // Update produk dengan namanya sendiri harus berhasil
        final updatedSelf = await productRepo.update(p1.id!, name: 'Es Teh');
        expect(updatedSelf.name, 'Es Teh');

        // Update produk dengan nama produk aktif lain harus ditolak
        expect(
          () => productRepo.update(p2.id!, name: 'es teh'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('6. deactivate product', () async {
      final p = await productRepo.create('Es Kopi');
      await productRepo.deactivate(p.id!);

      final fetched = await productRepo.getById(p.id!);
      expect(fetched?.isInactive, true);
    });

    test('7. activate product', () async {
      final p = await productRepo.create('Es Kopi');
      await productRepo.deactivate(p.id!);
      await productRepo.activate(p.id!);

      final fetched = await productRepo.getById(p.id!);
      expect(fetched?.isActive, true);
    });

    test('8. activate duplicate rejected', () async {
      final p1 = await productRepo.create('Es Kopi');
      await productRepo.deactivate(p1.id!);

      // Buat produk baru dengan nama sama
      await productRepo.create('Es Kopi');

      // Mengaktifkan p1 harus ditolak karena sudah ada produk aktif bernama 'Es Kopi'
      expect(
        () => productRepo.activate(p1.id!),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Atomic create product with recipe and price', () async {
      final teh = await ingredientRepo.create('Teh');
      final bundle = await productRepo.createProductWithRecipeAndPrice(
        name: 'Es Teh Manis',
        recipeItems: [
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeIngredient,
            ingredientId: teh.id,
            quantity: 5,
            unit: 'g',
            createdAt: '2026-09-01T00:00:00Z',
          ),
          const RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeOther,
            otherCost: 200,
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ],
        sellingPrice: 3000,
        effectiveDate: '2026-09-01',
        hppTotal: 700,
      );

      expect(bundle.product.id, isNotNull);
      expect(bundle.product.name, 'Es Teh Manis');
      expect(bundle.recipeVersion.versionNumber, 1);
      expect(bundle.recipeVersion.isActive, true);
      expect(bundle.recipeItems.length, 2);
      expect(bundle.productPrice.sellingPrice, 3000);
      expect(bundle.productPrice.effectiveFrom, '2026-09-01');
    });

    test(
      'Atomic update: no recipe change does NOT create new recipe version',
      () async {
        final teh = await ingredientRepo.create('Teh');
        final initialBundle = await productRepo.createProductWithRecipeAndPrice(
          name: 'Es Teh',
          recipeItems: [
            RecipeItem(
              recipeVersionId: 0,
              componentType: RecipeItem.typeIngredient,
              ingredientId: teh.id,
              quantity: 5,
              unit: 'g',
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          sellingPrice: 3000,
          effectiveDate: '2026-09-01',
          hppTotal: 500,
        );

        // Update hanya nama produk dan resep sama persis
        final updatedBundle = await productRepo.updateProductWithRecipeAndPrice(
          productId: initialBundle.product.id!,
          name: 'Es Teh Original',
          recipeItems: [
            RecipeItem(
              recipeVersionId: 0,
              componentType: RecipeItem.typeIngredient,
              ingredientId: teh.id,
              quantity: 5,
              unit: 'g',
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          effectiveDate: '2026-09-05',
        );

        expect(updatedBundle.product.name, 'Es Teh Original');
        // Resep tidak berubah -> tetap versi 1
        expect(updatedBundle.recipeVersion.versionNumber, 1);
        final allVersions = await recipeVersionRepo.getByProductId(
          initialBundle.product.id!,
        );
        expect(allVersions.length, 1);
      },
    );

    test(
      'Atomic update: recipe change creates new recipe version (v2) and archives v1',
      () async {
        final teh = await ingredientRepo.create('Teh');
        final initialBundle = await productRepo.createProductWithRecipeAndPrice(
          name: 'Es Teh',
          recipeItems: [
            RecipeItem(
              recipeVersionId: 0,
              componentType: RecipeItem.typeIngredient,
              ingredientId: teh.id,
              quantity: 5,
              unit: 'g',
              createdAt: '2026-09-01T00:00:00Z',
            ),
          ],
          sellingPrice: 3000,
          effectiveDate: '2026-09-01',
          hppTotal: 500,
        );

        // Update dengan komposisi resep baru (kuantitas diubah menjadi 7g)
        final updatedBundle = await productRepo.updateProductWithRecipeAndPrice(
          productId: initialBundle.product.id!,
          name: 'Es Teh',
          recipeItems: [
            RecipeItem(
              recipeVersionId: 0,
              componentType: RecipeItem.typeIngredient,
              ingredientId: teh.id,
              quantity: 7,
              unit: 'g',
              createdAt: '2026-09-15T00:00:00Z',
            ),
          ],
          sellingPrice: 3500,
          effectiveDate: '2026-09-15',
          hppTotal: 700,
        );

        expect(updatedBundle.recipeVersion.versionNumber, 2);
        expect(updatedBundle.recipeVersion.isActive, true);

        // Cek bahwa versi 1 sekarang berstatus archived
        final v1 = await recipeVersionRepo.getById(
          initialBundle.recipeVersion.id!,
        );
        expect(v1?.isArchived, true);

        // Cek harga jual baru ditambahkan
        final prices = await productPriceRepo.getByProductId(
          initialBundle.product.id!,
        );
        expect(prices.length, 2);
        expect(prices[0].sellingPrice, 3500);
        expect(prices[1].sellingPrice, 3000);
      },
    );
  });
}
