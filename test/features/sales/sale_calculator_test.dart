import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_price_repository.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/ingredients/models/ingredient.dart';
import 'package:labana/features/products/data/product_price_repository.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/data/recipe_item_repository.dart';
import 'package:labana/features/products/data/recipe_version_repository.dart';
import 'package:labana/features/products/models/product.dart';
import 'package:labana/features/products/models/product_price.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/models/recipe_version.dart';
import 'package:labana/features/products/services/hpp_engine.dart';
import 'package:labana/features/sales/errors/sale_exceptions.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/features/sales/services/sale_calculator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late RecipeVersionRepository recipeVersionRepo;
  late RecipeItemRepository recipeItemRepo;
  late ProductPriceRepository productPriceRepo;
  late IngredientRepository ingredientRepo;
  late IngredientPriceRepository ingredientPriceRepo;
  late HppEngine hppEngine;
  late SaleCalculator saleCalculator;

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
      ingredientRepo: ingredientRepo,
    );

    saleCalculator = SaleCalculator(
      hppEngine: hppEngine,
      productRepo: productRepo,
      recipeVersionRepo: recipeVersionRepo,
      priceRepo: productPriceRepo,
    );
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('SaleCalculator Tests', () {
    late Product activeProduct;
    late Ingredient teh;

    setUp(() async {
      // 1. Buat bahan mentah: Teh Melati (Rp100/g) per 2026-09-01
      teh = await ingredientRepo.create('Teh Melati');
      await ingredientPriceRepo.createPrice(
        ingredientId: teh.id!,
        purchaseQuantity: 100,
        purchaseUnit: 'g',
        price: 10000,
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );

      // 2. Buat produk aktif: Es Teh Manis
      activeProduct = await productRepo.create('Es Teh Manis');

      // Resep v1: Teh 5g (@ Rp100 = Rp500) + Biaya Lainnya Cup Rp500 = HPP Rp1.000
      final v1 = await recipeVersionRepo.create(
        RecipeVersion(
          productId: activeProduct.id!,
          versionNumber: 1,
          effectiveFrom: '2026-09-01',
          hppTotal: 1000,
          status: 'active',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      await recipeItemRepo.createMany([
        RecipeItem(
          recipeVersionId: v1.id!,
          componentType: RecipeItem.typeIngredient,
          ingredientId: teh.id!,
          quantity: 5,
          unit: 'g',
          createdAt: '2026-09-01T00:00:00Z',
        ),
        const RecipeItem(
          recipeVersionId: 1,
          componentType: RecipeItem.typeOther,
          otherCost: 500,
          label: 'Cup & Straw',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      ]);

      // Harga jual: Rp5.000 per 2026-09-01
      await productPriceRepo.create(
        ProductPrice(
          productId: activeProduct.id!,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
    });

    test(
      '1. Normal item calculation: Qty 2 -> Subtotal Rp10.000, Total HPP Rp2.000, Profit Rp8.000',
      () async {
        final item = await saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-05 13:00:00',
          quantity: 2,
          isNewItem: true,
        );

        expect(item.productName, 'Es Teh Manis');
        expect(item.quantity, 2);
        expect(item.sellingPrice, 5000);
        expect(item.hppPerUnit, 1000);
        expect(item.subtotal, 10000);
        expect(item.totalHpp, 2000);
        expect(item.totalProfit, 8000);
      },
    );

    test(
      '2. Decimal quantity calculation: Qty 1.5 -> Subtotal Rp7.500, Total HPP Rp1.500, Profit Rp6.000',
      () async {
        final item = await saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-05 13:00:00',
          quantity: 1.5,
          isNewItem: true,
        );

        expect(item.quantity, 1.5);
        expect(item.subtotal, 7500);
        expect(item.totalHpp, 1500);
        expect(item.totalProfit, 6000);
      },
    );

    test(
      '3. Historical date calculation uses transaction date, NOT current/latest date',
      () async {
        // Pada 2026-09-10, harga teh naik menjadi Rp200/g
        await ingredientPriceRepo.createPrice(
          ingredientId: teh.id!,
          purchaseQuantity: 100,
          purchaseUnit: 'g',
          price: 20000,
          effectiveFrom: '2026-09-10',
          isDefault: true,
        );

        // Transaksi bertanggal 2026-09-05 (sebelum kenaikan harga): HPP per unit harus tetap Rp1.000
        final itemBefore = await saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-05 10:00:00',
          quantity: 1,
        );
        expect(itemBefore.hppPerUnit, 1000);
        expect(itemBefore.totalProfit, 4000);

        // Transaksi bertanggal 2026-09-12 (setelah kenaikan harga): Teh 5g @ Rp200 = 1000 + Cup 500 = Rp1.500
        final itemAfter = await saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-12 10:00:00',
          quantity: 1,
        );
        expect(itemAfter.hppPerUnit, 1500);
        expect(itemAfter.totalProfit, 3500);
      },
    );

    test(
      '4. Inactive product handling: rejected as NEW item, allowed as EXISTING item',
      () async {
        // Nonaktifkan produk
        await productRepo.deactivate(activeProduct.id!);

        // A. Menambahkan sebagai new item harus DITOLAK
        expect(
          () => saleCalculator.calculateItem(
            productId: activeProduct.id!,
            transactionDate: '2026-09-05 10:00:00',
            quantity: 1,
            isNewItem: true,
          ),
          throwsA(isA<SaleValidationException>()),
        );

        // B. Mengedit sebagai existing item pada transaksi lama harus DIIZINKAN
        final existingItem = await saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-05 10:00:00',
          quantity: 3,
          isNewItem: false,
          existingProductIds: {activeProduct.id!},
        );

        expect(existingItem.quantity, 3);
        expect(existingItem.subtotal, 15000);
        expect(existingItem.totalHpp, 3000);
        expect(existingItem.totalProfit, 12000);
      },
    );

    test(
      '5. Missing price or recipe on transaction date throws HistoricalCalculationException',
      () async {
        // Tanggal sebelum resep pertama berlaku (2026-08-31)
        expect(
          () => saleCalculator.calculateItem(
            productId: activeProduct.id!,
            transactionDate: '2026-08-31 10:00:00',
            quantity: 1,
          ),
          throwsA(isA<HistoricalCalculationException>()),
        );
      },
    );

    test('6. Quantity <= 0 throws SaleValidationException', () async {
      expect(
        () => saleCalculator.calculateItem(
          productId: activeProduct.id!,
          transactionDate: '2026-09-05 10:00:00',
          quantity: 0,
        ),
        throwsA(isA<SaleValidationException>()),
      );
    });

    test('7. calculateTotals sums item rounded amounts consistently', () {
      final items = [
        const SaleItem(
          productId: 1,
          recipeVersionId: 1,
          productName: 'A',
          quantity: 2,
          sellingPrice: 5000,
          hppPerUnit: 1340,
          subtotal: 10000,
          totalHpp: 2680,
          totalProfit: 7320,
          createdAt: '',
        ),
        const SaleItem(
          productId: 2,
          recipeVersionId: 1,
          productName: 'B',
          quantity: 1,
          sellingPrice: 6000,
          hppPerUnit: 1850,
          subtotal: 6000,
          totalHpp: 1850,
          totalProfit: 4150,
          createdAt: '',
        ),
      ];

      final totals = saleCalculator.calculateTotals(items);

      expect(totals.totalAmount, 16000);
      expect(totals.totalHpp, 4530);
      expect(totals.totalProfit, 11470);
      expect(totals.totalProfit, totals.totalAmount - totals.totalHpp);
    });

    test(
      '8. getAvailableProductsForPicker only returns active products with evaluated values',
      () async {
        final pickerItems = await saleCalculator.getAvailableProductsForPicker(
          transactionDate: '2026-09-05',
        );

        expect(pickerItems.length, 1);
        final item = pickerItems.first;
        expect(item.product.id, activeProduct.id);
        expect(item.isValid, isTrue);
        expect(item.sellingPrice, 5000);
        expect(item.hppPerUnit, 1000);
        expect(item.profitPerUnit, 4000);
      },
    );
  });
}
