import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/home/presentation/screens/home_screen.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/features/settings/data/app_settings_repository.dart';
import 'package:labana/features/settings/models/business_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database testDb;
  late SaleRepository saleRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    testDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
      onUpgrade: DatabaseHelper.onUpgrade,
    );
    DatabaseHelper.instance.setTestDatabase(testDb);
    saleRepo = SaleRepository();
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  // Helper untuk membuat dummy product di master data
  Future<int> insertMasterProduct(String name) async {
    return await testDb.insert(TableNames.products, {
      'name': name,
      'status': 'active',
      'created_at': '2026-09-01 08:00:00',
      'updated_at': '2026-09-01 08:00:00',
    });
  }

  // Helper untuk membuat dummy recipe_version di master data
  Future<int> insertMasterRecipeVersion(
    int productId,
    int hppTotal, {
    int versionNumber = 1,
  }) async {
    return await testDb.insert(TableNames.recipeVersions, {
      'product_id': productId,
      'version_number': versionNumber,
      'effective_from': '2026-09-01',
      'hpp_total': hppTotal,
      'status': 'active',
      'created_at': '2026-09-01 08:00:00',
    });
  }

  group('Dashboard Summary Aggregation Tests', () {
    test('1. Empty database: semua metrik bernilai 0', () async {
      final summary = await saleRepo.getDailySummary('2026-09-15');
      expect(summary.totalOmzet, 0);
      expect(summary.totalHpp, 0);
      expect(summary.totalProfit, 0);
      expect(summary.transactionCount, 0);
      expect(summary.productsSold, 0.0);
      expect(summary.formattedTotalOmzet, 'Rp0');
      expect(summary.formattedTotalHpp, 'Rp0');
      expect(summary.formattedTotalProfit, 'Rp0');
      expect(summary.formattedProductsSold, '0');
    });

    test('2. Single transaction: seluruh nilai teragregasi tepat', () async {
      final p1 = await insertMasterProduct('Es Teh Manis');
      final rv1 = await insertMasterRecipeVersion(p1, 1340);

      final sale = Sale(
        transactionNumber: 'TRX-20260915-001',
        transactionDate: '2026-09-15 10:30:00',
        paymentMethod: 'cash',
        totalAmount: 10000,
        totalHpp: 2680,
        totalProfit: 7320,
        createdAt: '2026-09-15 10:30:00',
        updatedAt: '2026-09-15 10:30:00',
      );

      final items = [
        SaleItem(
          productId: p1,
          recipeVersionId: rv1,
          productName: 'Es Teh Manis',
          quantity: 2.0,
          sellingPrice: 5000,
          hppPerUnit: 1340,
          subtotal: 10000,
          totalHpp: 2680,
          totalProfit: 7320,
          createdAt: '2026-09-15 10:30:00',
        ),
      ];

      await saleRepo.createSaleWithItems(sale: sale, items: items);

      final summary = await saleRepo.getDailySummary('2026-09-15');
      expect(summary.totalOmzet, 10000);
      expect(summary.totalHpp, 2680);
      expect(summary.totalProfit, 7320);
      expect(summary.transactionCount, 1);
      expect(summary.productsSold, 2.0);
      expect(summary.formattedTotalOmzet, 'Rp10.000');
      expect(summary.formattedTotalHpp, 'Rp2.680');
      expect(summary.formattedTotalProfit, 'Rp7.320');
      expect(summary.formattedProductsSold, '2');
    });

    test(
      '3. Multiple transactions: akumulasi omzet, HPP, laba benar',
      () async {
        final p1 = await insertMasterProduct('Es Teh Manis');
        final rv1 = await insertMasterRecipeVersion(p1, 1000);
        final p2 = await insertMasterProduct('Es Jeruk');
        final rv2 = await insertMasterRecipeVersion(p2, 2000);

        // Trx 1: Es Teh x 3 (omzet 15.000, hpp 3.000, laba 12.000)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 09:00:00',
            totalAmount: 15000,
            totalHpp: 3000,
            totalProfit: 12000,
            createdAt: '2026-09-15 09:00:00',
            updatedAt: '2026-09-15 09:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Es Teh Manis',
              quantity: 3.0,
              sellingPrice: 5000,
              hppPerUnit: 1000,
              subtotal: 15000,
              totalHpp: 3000,
              totalProfit: 12000,
              createdAt: '2026-09-15 09:00:00',
            ),
          ],
        );

        // Trx 2: Es Jeruk x 2 (omzet 16.000, hpp 4.000, laba 12.000)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-002',
            transactionDate: '2026-09-15 14:00:00',
            totalAmount: 16000,
            totalHpp: 4000,
            totalProfit: 12000,
            createdAt: '2026-09-15 14:00:00',
            updatedAt: '2026-09-15 14:00:00',
          ),
          items: [
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Es Jeruk',
              quantity: 2.0,
              sellingPrice: 8000,
              hppPerUnit: 2000,
              subtotal: 16000,
              totalHpp: 4000,
              totalProfit: 12000,
              createdAt: '2026-09-15 14:00:00',
            ),
          ],
        );

        final summary = await saleRepo.getDailySummary('2026-09-15');
        expect(summary.totalOmzet, 31000);
        expect(summary.totalHpp, 7000);
        expect(summary.totalProfit, 24000);
        expect(summary.transactionCount, 2);
        expect(summary.productsSold, 5.0);
        expect(summary.formattedProductsSold, '5');
      },
    );

    test(
      '4. Transaksi tanggal lain tidak ikut terhitung pada dashboard',
      () async {
        final p1 = await insertMasterProduct('Es Kopi Susu');
        final rv1 = await insertMasterRecipeVersion(p1, 4000);

        // Transaksi kemarin (2026-09-14)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260914-001',
            transactionDate: '2026-09-14 18:00:00',
            totalAmount: 50000,
            totalHpp: 20000,
            totalProfit: 30000,
            createdAt: '2026-09-14 18:00:00',
            updatedAt: '2026-09-14 18:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Es Kopi Susu',
              quantity: 5.0,
              sellingPrice: 10000,
              hppPerUnit: 4000,
              subtotal: 50000,
              totalHpp: 20000,
              totalProfit: 30000,
              createdAt: '2026-09-14 18:00:00',
            ),
          ],
        );

        // Transaksi hari ini (2026-09-15)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 11:00:00',
            totalAmount: 10000,
            totalHpp: 4000,
            totalProfit: 6000,
            createdAt: '2026-09-15 11:00:00',
            updatedAt: '2026-09-15 11:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Es Kopi Susu',
              quantity: 1.0,
              sellingPrice: 10000,
              hppPerUnit: 4000,
              subtotal: 10000,
              totalHpp: 4000,
              totalProfit: 6000,
              createdAt: '2026-09-15 11:00:00',
            ),
          ],
        );

        final summaryToday = await saleRepo.getDailySummary('2026-09-15');
        expect(summaryToday.totalOmzet, 10000);
        expect(summaryToday.totalHpp, 4000);
        expect(summaryToday.totalProfit, 6000);
        expect(summaryToday.transactionCount, 1);
        expect(summaryToday.productsSold, 1.0);

        final summaryYesterday = await saleRepo.getDailySummary('2026-09-14');
        expect(summaryYesterday.totalOmzet, 50000);
        expect(summaryYesterday.transactionCount, 1);
        expect(summaryYesterday.productsSold, 5.0);
      },
    );

    test(
      '5. Products sold dihitung dari SUM(quantity), terpisah dari transaction_count',
      () async {
        final p1 = await insertMasterProduct('Donat');
        final rv1 = await insertMasterRecipeVersion(p1, 2000);
        final p2 = await insertMasterProduct('Kopi');
        final rv2 = await insertMasterRecipeVersion(p2, 3000);

        // 1 transaksi berisi 2 produk dengan quantity 3.5 dan 1.5 -> total products sold = 5.0
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 08:30:00',
            totalAmount: 25000,
            totalHpp: 11500,
            totalProfit: 13500,
            createdAt: '2026-09-15 08:30:00',
            updatedAt: '2026-09-15 08:30:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Donat',
              quantity: 3.5,
              sellingPrice: 5000,
              hppPerUnit: 2000,
              subtotal: 17500,
              totalHpp: 7000,
              totalProfit: 10500,
              createdAt: '2026-09-15 08:30:00',
            ),
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Kopi',
              quantity: 1.5,
              sellingPrice: 5000,
              hppPerUnit: 3000,
              subtotal: 7500,
              totalHpp: 4500,
              totalProfit: 3000,
              createdAt: '2026-09-15 08:30:00',
            ),
          ],
        );

        final summary = await saleRepo.getDailySummary('2026-09-15');
        expect(summary.transactionCount, 1);
        expect(summary.productsSold, 5.0);
      },
    );

    test(
      '6. Laba negatif tetap dipertahankan dan tidak diubah menjadi 0',
      () async {
        final p1 = await insertMasterProduct('Promo Rugi');
        final rv1 = await insertMasterRecipeVersion(p1, 10000);

        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 15:00:00',
            totalAmount: 5000,
            totalHpp: 10000,
            totalProfit: -5000,
            createdAt: '2026-09-15 15:00:00',
            updatedAt: '2026-09-15 15:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Promo Rugi',
              quantity: 1.0,
              sellingPrice: 5000,
              hppPerUnit: 10000,
              subtotal: 5000,
              totalHpp: 10000,
              totalProfit: -5000,
              createdAt: '2026-09-15 15:00:00',
            ),
          ],
        );

        final summary = await saleRepo.getDailySummary('2026-09-15');
        expect(summary.totalProfit, -5000);
        expect(summary.formattedTotalProfit, '-Rp5.000');
      },
    );
  });

  group('Top Selling Product Tests', () {
    test('1. Empty database: top selling mengembalikan null', () async {
      final top = await saleRepo.getDailyTopSellingProduct('2026-09-15');
      expect(top, isNull);
    });

    test('2. Produk dengan quantity terbanyak menjadi top selling', () async {
      final p1 = await insertMasterProduct('Es Teh');
      final rv1 = await insertMasterRecipeVersion(p1, 1000);
      final p2 = await insertMasterProduct('Es Jeruk');
      final rv2 = await insertMasterRecipeVersion(p2, 1500);

      await saleRepo.createSaleWithItems(
        sale: const Sale(
          transactionNumber: 'TRX-20260915-001',
          transactionDate: '2026-09-15 10:00:00',
          totalAmount: 60000,
          totalHpp: 19000,
          totalProfit: 41000,
          createdAt: '2026-09-15 10:00:00',
          updatedAt: '2026-09-15 10:00:00',
        ),
        items: [
          SaleItem(
            productId: p1,
            recipeVersionId: rv1,
            productName: 'Es Teh',
            quantity: 10.0,
            sellingPrice: 4000,
            hppPerUnit: 1000,
            subtotal: 40000,
            totalHpp: 10000,
            totalProfit: 30000,
            createdAt: '2026-09-15 10:00:00',
          ),
          SaleItem(
            productId: p2,
            recipeVersionId: rv2,
            productName: 'Es Jeruk',
            quantity: 4.0,
            sellingPrice: 5000,
            hppPerUnit: 1500,
            subtotal: 20000,
            totalHpp: 6000,
            totalProfit: 14000,
            createdAt: '2026-09-15 10:00:00',
          ),
        ],
      );

      final top = await saleRepo.getDailyTopSellingProduct('2026-09-15');
      expect(top, isNotNull);
      expect(top!.productId, p1);
      expect(top.productName, 'Es Teh');
      expect(top.quantity, 10.0);
      expect(top.formattedQuantity, '10');
    });

    test(
      '3. Akumulasi quantity produk yang sama dari beberapa transaksi',
      () async {
        final p1 = await insertMasterProduct('Kopi Susu');
        final rv1 = await insertMasterRecipeVersion(p1, 5000);
        final p2 = await insertMasterProduct('Teh Tarik');
        final rv2 = await insertMasterRecipeVersion(p2, 3000);

        // Trx 1: Kopi Susu x 3
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 09:00:00',
            totalAmount: 30000,
            totalHpp: 15000,
            totalProfit: 15000,
            createdAt: '2026-09-15 09:00:00',
            updatedAt: '2026-09-15 09:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Kopi Susu',
              quantity: 3.0,
              sellingPrice: 10000,
              hppPerUnit: 5000,
              subtotal: 30000,
              totalHpp: 15000,
              totalProfit: 15000,
              createdAt: '2026-09-15 09:00:00',
            ),
          ],
        );

        // Trx 2: Teh Tarik x 6
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-002',
            transactionDate: '2026-09-15 11:00:00',
            totalAmount: 48000,
            totalHpp: 18000,
            totalProfit: 30000,
            createdAt: '2026-09-15 11:00:00',
            updatedAt: '2026-09-15 11:00:00',
          ),
          items: [
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Teh Tarik',
              quantity: 6.0,
              sellingPrice: 8000,
              hppPerUnit: 3000,
              subtotal: 48000,
              totalHpp: 18000,
              totalProfit: 30000,
              createdAt: '2026-09-15 11:00:00',
            ),
          ],
        );

        // Trx 3: Kopi Susu x 5 (total Kopi Susu jadi 8)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-003',
            transactionDate: '2026-09-15 13:00:00',
            totalAmount: 50000,
            totalHpp: 25000,
            totalProfit: 25000,
            createdAt: '2026-09-15 13:00:00',
            updatedAt: '2026-09-15 13:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Kopi Susu',
              quantity: 5.0,
              sellingPrice: 10000,
              hppPerUnit: 5000,
              subtotal: 50000,
              totalHpp: 25000,
              totalProfit: 25000,
              createdAt: '2026-09-15 13:00:00',
            ),
          ],
        );

        final top = await saleRepo.getDailyTopSellingProduct('2026-09-15');
        expect(top, isNotNull);
        expect(top!.productId, p1);
        expect(top.productName, 'Kopi Susu');
        expect(top.quantity, 8.0);
      },
    );

    test(
      '4. Deterministic tie-breaker: jika quantity sama, pilih product_id terkecil',
      () async {
        final p1 = await insertMasterProduct('Produk Awal');
        final rv1 = await insertMasterRecipeVersion(p1, 1000);
        final p2 = await insertMasterProduct('Produk Akhir');
        final rv2 = await insertMasterRecipeVersion(p2, 1000);

        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 20000,
            totalHpp: 4000,
            totalProfit: 16000,
            createdAt: '2026-09-15 10:00:00',
            updatedAt: '2026-09-15 10:00:00',
          ),
          items: [
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Produk Akhir',
              quantity: 2.0,
              sellingPrice: 5000,
              hppPerUnit: 1000,
              subtotal: 10000,
              totalHpp: 2000,
              totalProfit: 8000,
              createdAt: '2026-09-15 10:00:00',
            ),
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Produk Awal',
              quantity: 2.0,
              sellingPrice: 5000,
              hppPerUnit: 1000,
              subtotal: 10000,
              totalHpp: 2000,
              totalProfit: 8000,
              createdAt: '2026-09-15 10:00:00',
            ),
          ],
        );

        final top = await saleRepo.getDailyTopSellingProduct('2026-09-15');
        expect(top, isNotNull);
        // p1 < p2
        expect(top!.productId, p1);
        expect(top.productName, 'Produk Awal');
      },
    );
  });

  group('Highest Profit Product Tests', () {
    test('1. Empty database: highest profit mengembalikan null', () async {
      final hp = await saleRepo.getDailyHighestProfitProduct('2026-09-15');
      expect(hp, isNull);
    });

    test(
      '2. Produk dengan profit tertinggi terpilih meski quantity lebih sedikit',
      () async {
        final p1 = await insertMasterProduct('Es Teh');
        final rv1 = await insertMasterRecipeVersion(p1, 1000);
        final p2 = await insertMasterProduct('Espresso Blend');
        final rv2 = await insertMasterRecipeVersion(p2, 5000);

        // Es Teh terjual 10x, profit Rp20.000
        // Espresso terjual 2x, profit Rp35.000
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 75000,
            totalHpp: 20000,
            totalProfit: 55000,
            createdAt: '2026-09-15 10:00:00',
            updatedAt: '2026-09-15 10:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Es Teh',
              quantity: 10.0,
              sellingPrice: 3000,
              hppPerUnit: 1000,
              subtotal: 30000,
              totalHpp: 10000,
              totalProfit: 20000,
              createdAt: '2026-09-15 10:00:00',
            ),
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Espresso Blend',
              quantity: 2.0,
              sellingPrice: 22500,
              hppPerUnit: 5000,
              subtotal: 45000,
              totalHpp: 10000,
              totalProfit: 35000,
              createdAt: '2026-09-15 10:00:00',
            ),
          ],
        );

        final hp = await saleRepo.getDailyHighestProfitProduct('2026-09-15');
        expect(hp, isNotNull);
        expect(hp!.productId, p2);
        expect(hp.productName, 'Espresso Blend');
        expect(hp.profit, 35000);
        expect(hp.formattedProfit, 'Rp35.000');
      },
    );

    test(
      '3. Deterministic tie-breaker: jika profit sama, pilih product_id terkecil',
      () async {
        final p1 = await insertMasterProduct('Matcha Latte');
        final rv1 = await insertMasterRecipeVersion(p1, 5000);
        final p2 = await insertMasterProduct('Chocolate');
        final rv2 = await insertMasterRecipeVersion(p2, 5000);

        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 30000,
            totalHpp: 10000,
            totalProfit: 20000,
            createdAt: '2026-09-15 10:00:00',
            updatedAt: '2026-09-15 10:00:00',
          ),
          items: [
            SaleItem(
              productId: p2,
              recipeVersionId: rv2,
              productName: 'Chocolate',
              quantity: 1.0,
              sellingPrice: 15000,
              hppPerUnit: 5000,
              subtotal: 15000,
              totalHpp: 5000,
              totalProfit: 10000,
              createdAt: '2026-09-15 10:00:00',
            ),
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Matcha Latte',
              quantity: 1.0,
              sellingPrice: 15000,
              hppPerUnit: 5000,
              subtotal: 15000,
              totalHpp: 5000,
              totalProfit: 10000,
              createdAt: '2026-09-15 10:00:00',
            ),
          ],
        );

        final hp = await saleRepo.getDailyHighestProfitProduct('2026-09-15');
        expect(hp, isNotNull);
        // p1 < p2
        expect(hp!.productId, p1);
        expect(hp.productName, 'Matcha Latte');
      },
    );
  });

  group('Historical Snapshot Preservation Tests', () {
    test(
      'Perubahan master data produk dan resep tidak mengubah transaksi historis pada dashboard',
      () async {
        final p1 = await insertMasterProduct('Kopi Susu Original');
        final rv1 = await insertMasterRecipeVersion(p1, 3000);

        // Buat transaksi
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 12:00:00',
            totalAmount: 15000,
            totalHpp: 3000,
            totalProfit: 12000,
            createdAt: '2026-09-15 12:00:00',
            updatedAt: '2026-09-15 12:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Kopi Susu Original',
              quantity: 1.0,
              sellingPrice: 15000,
              hppPerUnit: 3000,
              subtotal: 15000,
              totalHpp: 3000,
              totalProfit: 12000,
              createdAt: '2026-09-15 12:00:00',
            ),
          ],
        );

        // Verifikasi dashboard awal
        var summary = await saleRepo.getDailySummary('2026-09-15');
        expect(summary.totalOmzet, 15000);
        expect(summary.totalHpp, 3000);
        expect(summary.totalProfit, 12000);

        // Ubah master data: ganti nama produk, tambah versi resep baru dengan hpp 8000
        await testDb.update(
          TableNames.products,
          {'name': 'Kopi Susu Gula Aren Spesial'},
          where: 'id = ?',
          whereArgs: [p1],
        );
        await insertMasterRecipeVersion(p1, 8000, versionNumber: 2);

        // Verifikasi dashboard TETAP menggunakan snapshot yang tersimpan
        summary = await saleRepo.getDailySummary('2026-09-15');
        expect(summary.totalOmzet, 15000);
        expect(summary.totalHpp, 3000);
        expect(summary.totalProfit, 12000);

        final top = await saleRepo.getDailyTopSellingProduct('2026-09-15');
        expect(top!.productName, 'Kopi Susu Original');
      },
    );
  });

  group('HomeScreen Widget Tests', () {
    Future<void> settleAsync(WidgetTester tester) async {
      for (int i = 0; i < 10; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Dashboard merender empty state secara rapi saat belum ada transaksi',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(home: HomeScreen(saleRepo: saleRepo)),
        );
        await settleAsync(tester);

        // Greeting & Header
        expect(find.textContaining('Selamat'), findsWidgets);
        expect(find.text('Selamat datang di Labana'), findsOneWidget);
        expect(find.text('Ringkasan Hari Ini'), findsOneWidget);

        // 4 Stat Cards
        expect(find.text('Omzet Hari Ini'), findsOneWidget);
        expect(find.text('Modal / HPP'), findsOneWidget);
        expect(find.text('Laba'), findsOneWidget);
        expect(find.text('Transaksi'), findsOneWidget);
        expect(find.text('Rp0'), findsNWidgets(3));
        expect(find.text('0'), findsOneWidget);

        // Produk Terjual Banner & Empty Insight Cards
        expect(find.text('0 produk terjual'), findsOneWidget);
        expect(find.text('Belum ada penjualan'), findsNWidgets(2));
        expect(find.text('Belum ada penjualan hari ini.'), findsOneWidget);

        // Quick actions
        expect(find.text('+ Penjualan'), findsOneWidget);
        expect(find.text('+ Bahan'), findsOneWidget);
        expect(find.text('+ Produk / Resep'), findsOneWidget);
      },
    );

    testWidgets('Dashboard merender nilai riil saat ada transaksi hari ini', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final todayStr = SaleRepository.formatLocalDate(DateTime.now());
        final p1 = await insertMasterProduct('Es Coklat');
        final rv1 = await insertMasterRecipeVersion(p1, 4000);

        await saleRepo.createSaleWithItems(
          sale: Sale(
            transactionNumber: 'TRX-TODAY-001',
            transactionDate: '$todayStr 10:00:00',
            totalAmount: 20000,
            totalHpp: 8000,
            totalProfit: 12000,
            createdAt: '$todayStr 10:00:00',
            updatedAt: '$todayStr 10:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Es Coklat',
              quantity: 2.0,
              sellingPrice: 10000,
              hppPerUnit: 4000,
              subtotal: 20000,
              totalHpp: 8000,
              totalProfit: 12000,
              createdAt: '$todayStr 10:00:00',
            ),
          ],
        );
      });

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(saleRepo: saleRepo)),
      );
      await settleAsync(tester);

      expect(find.text('Rp20.000'), findsOneWidget);
      expect(find.text('Rp8.000'), findsOneWidget);
      expect(find.text('Rp12.000'), findsWidgets);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2 produk terjual'), findsOneWidget);
      expect(find.text('Es Coklat'), findsWidgets);
      expect(find.text('2 terjual'), findsOneWidget);
    });

    testWidgets('Dashboard otomatis refresh saat salesChangeNotifier dipicu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(saleRepo: saleRepo)),
      );
      await settleAsync(tester);

      expect(find.text('Rp0'), findsNWidgets(3));
      expect(find.text('0'), findsOneWidget);

      // Tambahkan transaksi secara background via runAsync
      await tester.runAsync(() async {
        final todayStr = SaleRepository.formatLocalDate(DateTime.now());
        final p1 = await insertMasterProduct('Thai Tea');
        final rv1 = await insertMasterRecipeVersion(p1, 2500);

        await saleRepo.createSaleWithItems(
          sale: Sale(
            transactionNumber: 'TRX-TODAY-002',
            transactionDate: '$todayStr 14:00:00',
            totalAmount: 12000,
            totalHpp: 2500,
            totalProfit: 9500,
            createdAt: '$todayStr 14:00:00',
            updatedAt: '$todayStr 14:00:00',
          ),
          items: [
            SaleItem(
              productId: p1,
              recipeVersionId: rv1,
              productName: 'Thai Tea',
              quantity: 1.0,
              sellingPrice: 12000,
              hppPerUnit: 2500,
              subtotal: 12000,
              totalHpp: 2500,
              totalProfit: 9500,
              createdAt: '$todayStr 14:00:00',
            ),
          ],
        );
      });

      // Settle async events to process reactive notification
      await settleAsync(tester);

      expect(find.text('Rp12.000'), findsOneWidget);
      expect(find.text('Rp2.500'), findsOneWidget);
      expect(find.text('Rp9.500'), findsWidgets);
      expect(find.text('Thai Tea'), findsWidgets);
    });

    testWidgets('Dashboard menampilkan nama usaha dan slogan kustom secara reaktif', (
      WidgetTester tester,
    ) async {
      AppSettingsRepository.businessProfileNotifier.value =
          const BusinessProfile(
        name: 'Dapur Nusantara',
        tagline: 'Cita Rasa Asli Indonesia',
      );

      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(saleRepo: saleRepo)),
      );
      await settleAsync(tester);

      expect(find.text('Dapur Nusantara'), findsWidgets);
      expect(find.text('Selamat datang di Dapur Nusantara'), findsOneWidget);
      expect(find.text('Cita Rasa Asli Indonesia'), findsOneWidget);

      // Ubah profil secara dinamis
      AppSettingsRepository.businessProfileNotifier.value =
          const BusinessProfile(
        name: 'Kedai Kopi Berkah',
        tagline: 'Kopi Mantap Harga Sahabat',
      );
      await tester.pump();

      expect(find.text('Kedai Kopi Berkah'), findsWidgets);
      expect(find.text('Selamat datang di Kedai Kopi Berkah'), findsOneWidget);
      expect(find.text('Kopi Mantap Harga Sahabat'), findsOneWidget);

      // Reset kembali ke default
      AppSettingsRepository.businessProfileNotifier.value =
          const BusinessProfile();
      await tester.pump();

      expect(find.text('Selamat datang di Labana'), findsOneWidget);
      expect(find.text('Kelola Modal, Pahami Laba.'), findsOneWidget);
    });
  });
}
