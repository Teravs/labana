import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_price_repository.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late IngredientRepository ingredientRepo;
  late IngredientPriceRepository priceRepo;

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
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('IngredientPriceRepository Tests', () {
    test('Create & Konversi Otomatis: 1 kg / Rp20.000 -> 1000 g', () async {
      final gula = await ingredientRepo.create('Gula Pasir');

      final price = await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 20000,
        effectiveFrom: '2026-09-01',
      );

      expect(price.id, isNotNull);
      expect(price.ingredientId, gula.id);
      expect(price.purchaseQuantity, 1.0);
      expect(price.purchaseUnit, 'kg');
      expect(price.baseQuantity, 1000.0);
      expect(price.baseUnit, 'g');
      expect(price.packageQuantity, isNull);
      expect(price.price, 20000);
      expect(price.costPerBaseUnit, 20.0);
      expect(price.effectiveFrom, '2026-09-01');

      final saved = await priceRepo.getPriceById(price.id!);
      expect(saved, isNotNull);
      expect(saved!.baseQuantity, 1000.0);
      expect(saved.baseUnit, 'g');
    });

    test(
      'Satuan Pack: 1 pack / 50 pcs / Rp10.000 -> 50 pcs, Rp200/pcs',
      () async {
        final sedotan = await ingredientRepo.create('Sedotan');

        final price = await priceRepo.createPrice(
          ingredientId: sedotan.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'pack',
          packageQuantity: 50.0,
          price: 10000,
          effectiveFrom: '2026-09-01',
        );

        expect(price.baseQuantity, 50.0);
        expect(price.baseUnit, 'pcs');
        expect(price.packageQuantity, 50.0);
        expect(price.costPerBaseUnit, 200.0);
      },
    );

    test('Riwayat Harga & Pengurutan Effective Date', () async {
      final gula = await ingredientRepo.create('Gula');

      await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 20000,
        effectiveFrom: '2026-09-01',
      );

      await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 22000,
        effectiveFrom: '2026-09-05',
      );

      final prices = await priceRepo.getPrices(gula.id!);
      expect(prices.length, 2);
      // Paling baru (5 Sep) berada di posisi pertama
      expect(prices[0].effectiveFrom, '2026-09-05');
      expect(prices[0].price, 22000);
      expect(prices[1].effectiveFrom, '2026-09-01');
      expect(prices[1].price, 20000);
    });

    test('Query getPriceForDate berdasarkan tanggal berlaku', () async {
      final gula = await ingredientRepo.create('Gula');

      await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 20000,
        effectiveFrom: '2026-09-01',
      );

      await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 22000,
        effectiveFrom: '2026-09-05',
      );

      // Sebelum tanggal pertama: null
      final priceBefore = await priceRepo.getPriceForDate(
        gula.id!,
        targetDate: '2026-08-31',
      );
      expect(priceBefore, isNull);

      // Tanggal 3 Sep: Rp20.000
      final priceSep3 = await priceRepo.getPriceForDate(
        gula.id!,
        targetDate: '2026-09-03',
      );
      expect(priceSep3, isNotNull);
      expect(priceSep3!.price, 20000);

      // Tanggal 5 Sep: Rp22.000
      final priceSep5 = await priceRepo.getPriceForDate(
        gula.id!,
        targetDate: '2026-09-05',
      );
      expect(priceSep5, isNotNull);
      expect(priceSep5!.price, 22000);

      // Tanggal 10 Sep: Rp22.000
      final priceSep10 = await priceRepo.getPriceForDate(
        gula.id!,
        targetDate: '2026-09-10',
      );
      expect(priceSep10, isNotNull);
      expect(priceSep10!.price, 22000);
    });

    test(
      'Backdated Price disisipkan dengan urutan riwayat yang benar',
      () async {
        final gula = await ingredientRepo.create('Gula');

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 20000,
          effectiveFrom: '2026-09-01',
        );

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 22000,
          effectiveFrom: '2026-09-05',
        );

        // Sisipkan harga masa lalu (3 Sep)
        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 21000,
          effectiveFrom: '2026-09-03',
        );

        final prices = await priceRepo.getPrices(gula.id!);
        expect(prices.length, 3);
        expect(prices[0].effectiveFrom, '2026-09-05');
        expect(prices[0].price, 22000);
        expect(prices[1].effectiveFrom, '2026-09-03');
        expect(prices[1].price, 21000);
        expect(prices[2].effectiveFrom, '2026-09-01');
        expect(prices[2].price, 20000);
      },
    );

    test(
      'Future Price (harga masa depan) tersimpan dan berlaku sesuai tanggal',
      () async {
        final gula = await ingredientRepo.create('Gula');

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 20000,
          effectiveFrom: '2026-09-01',
        );

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 25000,
          effectiveFrom: '2026-09-10',
        );

        final currentPrice = await priceRepo.getPriceForDate(
          gula.id!,
          targetDate: '2026-09-05',
        );
        expect(currentPrice!.price, 20000);

        final futurePrice = await priceRepo.getPriceForDate(
          gula.id!,
          targetDate: '2026-09-10',
        );
        expect(futurePrice!.price, 25000);
      },
    );

    test(
      'Pencegahan duplikasi tanggal berlaku pada format pembelian yang sama',
      () async {
        final gula = await ingredientRepo.create('Gula');

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 20000,
          effectiveFrom: '2026-09-01',
        );

        // Input format sama pada tanggal yang sama harus ditolak
        expect(
          () => priceRepo.createPrice(
            ingredientId: gula.id!,
            purchaseQuantity: 1.0,
            purchaseUnit: 'kg',
            price: 21000,
            effectiveFrom: '2026-09-01',
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'Format pembelian berbeda boleh memiliki effective date yang sama',
      () async {
        final gula = await ingredientRepo.create('Gula');

        final price1kg = await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 20000,
          effectiveFrom: '2026-09-01',
        );

        final price500g = await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 500.0,
          purchaseUnit: 'g',
          price: 11000,
          effectiveFrom: '2026-09-01',
        );

        expect(price1kg.id, isNotNull);
        expect(price500g.id, isNotNull);
        expect(price1kg.id, isNot(price500g.id));

        final prices = await priceRepo.getPrices(gula.id!);
        expect(prices.length, 2);
      },
    );

    test('Single Default Price & Transaksi Penggantian Default', () async {
      final gula = await ingredientRepo.create('Gula');

      final p1 = await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 1.0,
        purchaseUnit: 'kg',
        price: 20000,
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );

      expect(p1.isDefault, isTrue);

      final default1 = await priceRepo.getDefaultPrice(gula.id!);
      expect(default1, isNotNull);
      expect(default1!.id, p1.id);

      // Tambah harga kedua sebagai default baru
      final p2 = await priceRepo.createPrice(
        ingredientId: gula.id!,
        purchaseQuantity: 500.0,
        purchaseUnit: 'g',
        price: 11000,
        effectiveFrom: '2026-09-01',
        isDefault: true,
      );

      final default2 = await priceRepo.getDefaultPrice(gula.id!);
      expect(default2, isNotNull);
      expect(default2!.id, p2.id);

      // Verifikasi p1 bukan default lagi
      final p1Refreshed = await priceRepo.getPriceById(p1.id!);
      expect(p1Refreshed!.isDefault, isFalse);

      // Ubah kembali p1 menjadi default via setDefaultPrice
      await priceRepo.setDefaultPrice(ingredientId: gula.id!, priceId: p1.id!);

      final default3 = await priceRepo.getDefaultPrice(gula.id!);
      expect(default3!.id, p1.id);

      final p2Refreshed = await priceRepo.getPriceById(p2.id!);
      expect(p2Refreshed!.isDefault, isFalse);
    });

    test(
      'Data harga tetap tersimpan ketika bahan dinonaktifkan dan diaktifkan',
      () async {
        final gula = await ingredientRepo.create('Gula');

        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1.0,
          purchaseUnit: 'kg',
          price: 20000,
          effectiveFrom: '2026-09-01',
        );

        // Nonaktifkan bahan
        await ingredientRepo.deactivate(gula.id!);

        // Harga tetap ada
        var prices = await priceRepo.getPrices(gula.id!);
        expect(prices.length, 1);
        expect(prices.first.price, 20000);

        // Aktifkan kembali bahan
        await ingredientRepo.activate(gula.id!);

        prices = await priceRepo.getPrices(gula.id!);
        expect(prices.length, 1);
        expect(prices.first.price, 20000);
      },
    );
  });
}
