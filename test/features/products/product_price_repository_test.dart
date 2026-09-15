import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/products/data/product_price_repository.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/models/product_price.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ProductRepository productRepo;
  late ProductPriceRepository priceRepo;
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
    priceRepo = ProductPriceRepository();

    final product = await productRepo.create('Es Teh Manis');
    productId = product.id!;
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('ProductPriceRepository Tests', () {
    test('9. create selling price', () async {
      final price = ProductPrice(
        productId: productId,
        sellingPrice: 5000,
        effectiveFrom: '2026-09-01',
        createdAt: '2026-09-01T00:00:00Z',
      );

      final created = await priceRepo.create(price);
      expect(created.id, isNotNull);
      expect(created.sellingPrice, 5000);
      expect(created.effectiveFrom, '2026-09-01');
    });

    test('10. effective date lookup', () async {
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 4000,
          effectiveFrom: '2026-08-01',
          createdAt: '2026-08-01T00:00:00Z',
        ),
      );
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      // Lookup per 2026-09-15 harus mendapatkan 5000
      final effectiveNow = await priceRepo.getEffectivePrice(
        productId,
        effectiveDate: '2026-09-15',
      );
      expect(effectiveNow, isNotNull);
      expect(effectiveNow!.sellingPrice, 5000);
    });

    test('11. backdated price lookup', () async {
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 4000,
          effectiveFrom: '2026-08-01',
          createdAt: '2026-08-01T00:00:00Z',
        ),
      );
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      // Lookup per 2026-08-15 harus mendapatkan 4000 (sebelum kenaikan September)
      final backdated = await priceRepo.getEffectivePrice(
        productId,
        effectiveDate: '2026-08-15',
      );
      expect(backdated, isNotNull);
      expect(backdated!.sellingPrice, 4000);

      // Lookup sebelum 2026-08-01 harus null
      final beforeAny = await priceRepo.getEffectivePrice(
        productId,
        effectiveDate: '2026-07-31',
      );
      expect(beforeAny, isNull);
    });

    test('12. future price lookup', () async {
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 6000,
          effectiveFrom: '2026-10-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      // Lookup per 2026-09-15 belum terpengaruh kenaikan Oktober
      final septPrice = await priceRepo.getEffectivePrice(
        productId,
        effectiveDate: '2026-09-15',
      );
      expect(septPrice!.sellingPrice, 5000);

      // Lookup per 2026-10-05 sudah menggunakan harga 6000
      final octPrice = await priceRepo.getEffectivePrice(
        productId,
        effectiveDate: '2026-10-05',
      );
      expect(octPrice!.sellingPrice, 6000);
    });

    test('13. duplicate product + effective date rejected', () async {
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      // Percobaan membuat harga pada tanggal efektif yang sama harus ditolak
      expect(
        () => priceRepo.create(
          ProductPrice(
            productId: productId,
            sellingPrice: 5500,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('14. price history preserved', () async {
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 4000,
          effectiveFrom: '2026-07-01',
          createdAt: '2026-07-01T00:00:00Z',
        ),
      );
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5000,
          effectiveFrom: '2026-08-01',
          createdAt: '2026-08-01T00:00:00Z',
        ),
      );
      await priceRepo.create(
        ProductPrice(
          productId: productId,
          sellingPrice: 5500,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T00:00:00Z',
        ),
      );

      final history = await priceRepo.getByProductId(productId);
      expect(history.length, 3);
      // Diurutkan berdasarkan tanggal terbaru
      expect(history[0].sellingPrice, 5500);
      expect(history[0].effectiveFrom, '2026-09-01');
      expect(history[1].sellingPrice, 5000);
      expect(history[2].sellingPrice, 4000);
    });
  });
}

