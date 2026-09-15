import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/errors/sale_exceptions.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late SaleRepository saleRepo;

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
    saleRepo = SaleRepository();

    // Setup master product & recipe dummy untuk foreign key constraint
    await db.insert('products', {
      'id': 1,
      'name': 'Es Teh Manis',
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
      'updated_at': '2026-09-01 00:00:00',
    });
    await db.insert('products', {
      'id': 2,
      'name': 'Es Jeruk',
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
      'updated_at': '2026-09-01 00:00:00',
    });

    await db.insert('recipe_versions', {
      'id': 1,
      'product_id': 1,
      'version_number': 1,
      'effective_from': '2026-09-01',
      'hpp_total': 1340,
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
    });
    await db.insert('recipe_versions', {
      'id': 2,
      'product_id': 2,
      'version_number': 1,
      'effective_from': '2026-09-01',
      'hpp_total': 1850,
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
    });
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  SaleItem makeItem({
    int productId = 1,
    int recipeVersionId = 1,
    String productName = 'Es Teh Manis',
    double quantity = 1,
    int sellingPrice = 5000,
    int hppPerUnit = 1340,
  }) {
    final subtotal = (quantity * sellingPrice).round();
    final totalHpp = (quantity * hppPerUnit).round();
    final totalProfit = subtotal - totalHpp;

    return SaleItem(
      productId: productId,
      recipeVersionId: recipeVersionId,
      productName: productName,
      quantity: quantity,
      sellingPrice: sellingPrice,
      hppPerUnit: hppPerUnit,
      subtotal: subtotal,
      totalHpp: totalHpp,
      totalProfit: totalProfit,
      createdAt: '2026-09-15T13:25:00Z',
    );
  }

  group('SaleRepository Tests', () {
    test(
      '1. Create single-product sale with atomic insertion & auto-generated transaction number',
      () async {
        final item = makeItem(quantity: 2);
        final sale = Sale(
          transactionNumber: '', // di-generate otomatis
          transactionDate: '2026-09-15 13:25:00',
          paymentMethod: Sale.paymentCash,
          totalAmount: 10000,
          totalHpp: 2680,
          totalProfit: 7320,
          createdAt: '2026-09-15 13:25:00',
          updatedAt: '2026-09-15 13:25:00',
        );

        final saved = await saleRepo.createSaleWithItems(
          sale: sale,
          items: [item],
        );

        expect(saved.id, isNotNull);
        expect(saved.transactionNumber, 'TRX-20260915-001');
        expect(saved.items?.length, 1);
        expect(saved.items?.first.saleId, saved.id);
        expect(saved.items?.first.productName, 'Es Teh Manis');
        expect(saved.items?.first.subtotal, 10000);
      },
    );

    test('2. Create multi-product sale: Es Teh × 2 & Es Jeruk × 1', () async {
      final item1 = makeItem(
        productId: 1,
        productName: 'Es Teh Manis',
        quantity: 2,
        sellingPrice: 5000,
        hppPerUnit: 1340,
      );
      final item2 = makeItem(
        productId: 2,
        recipeVersionId: 2,
        productName: 'Es Jeruk',
        quantity: 1,
        sellingPrice: 6000,
        hppPerUnit: 1850,
      );

      final sale = Sale(
        transactionNumber: '',
        transactionDate: '2026-09-15 13:30:00',
        paymentMethod: Sale.paymentQris,
        totalAmount: 16000,
        totalHpp: 4530,
        totalProfit: 11470,
        createdAt: '2026-09-15 13:30:00',
        updatedAt: '2026-09-15 13:30:00',
      );

      final saved = await saleRepo.createSaleWithItems(
        sale: sale,
        items: [item1, item2],
      );

      expect(saved.transactionNumber, 'TRX-20260915-001');
      expect(saved.items?.length, 2);
      expect(saved.paymentMethod, Sale.paymentQris);
    });

    test('3. Validation: Empty items & quantity <= 0 rejected', () async {
      final sale = Sale(
        transactionNumber: '',
        transactionDate: '2026-09-15 13:00:00',
        totalAmount: 0,
        totalHpp: 0,
        totalProfit: 0,
        createdAt: '',
        updatedAt: '',
      );

      // A. Empty items
      expect(
        () => saleRepo.createSaleWithItems(sale: sale, items: []),
        throwsA(isA<SaleValidationException>()),
      );

      // B. Quantity <= 0
      final invalidItem = makeItem(quantity: 0);
      expect(
        () => saleRepo.createSaleWithItems(sale: sale, items: [invalidItem]),
        throwsA(isA<SaleValidationException>()),
      );
    });

    test(
      '4. GetAll sales orders by transaction_date DESC, id DESC with correct item_count',
      () async {
        final item = makeItem();

        // Transaksi 1: 15 Sep 10:00
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: '',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 5000,
            totalHpp: 1340,
            totalProfit: 3660,
            createdAt: '',
            updatedAt: '',
          ),
          items: [item],
        );

        // Transaksi 2: 15 Sep 14:00 (2 items)
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: '',
            transactionDate: '2026-09-15 14:00:00',
            totalAmount: 11000,
            totalHpp: 3190,
            totalProfit: 7810,
            createdAt: '',
            updatedAt: '',
          ),
          items: [
            item,
            makeItem(productId: 2, recipeVersionId: 2, productName: 'Es Jeruk'),
          ],
        );

        final list = await saleRepo.getAll();
        expect(list.length, 2);
        // Yang terbaru muncul pertama
        expect(list.first.transactionNumber, 'TRX-20260915-002');
        expect(list.first.itemCount, 2);
        expect(list.last.transactionNumber, 'TRX-20260915-001');
        expect(list.last.itemCount, 1);
      },
    );

    test('5. GetById loads sale and its items accurately', () async {
      final item = makeItem(quantity: 2);
      final created = await saleRepo.createSaleWithItems(
        sale: const Sale(
          transactionNumber: '',
          transactionDate: '2026-09-15 12:00:00',
          totalAmount: 10000,
          totalHpp: 2680,
          totalProfit: 7320,
          createdAt: '',
          updatedAt: '',
        ),
        items: [item],
      );

      final retrieved = await saleRepo.getById(created.id!);
      expect(retrieved, isNotNull);
      expect(retrieved!.transactionNumber, created.transactionNumber);
      expect(retrieved.items?.length, 1);
      expect(retrieved.items?.first.productName, 'Es Teh Manis');
      expect(retrieved.items?.first.subtotal, 10000);
    });

    test(
      '6. Update transaction preserves transaction_number even if transaction_date changes',
      () async {
        final item = makeItem(quantity: 2);
        final created = await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: '',
            transactionDate: '2026-09-15 12:00:00',
            totalAmount: 10000,
            totalHpp: 2680,
            totalProfit: 7320,
            createdAt: '',
            updatedAt: '',
          ),
          items: [item],
        );

        expect(created.transactionNumber, 'TRX-20260915-001');

        // Edit transaksi: Ubah tanggal ke 10 September dan kuantitas menjadi 3
        final newItem = makeItem(quantity: 3);
        final updatedSale = created.copyWith(
          transactionDate: '2026-09-10 10:00:00',
          paymentMethod: Sale.paymentTransfer,
          totalAmount: 15000,
          totalHpp: 4020,
          totalProfit: 10980,
        );

        final updated = await saleRepo.updateSaleWithItems(
          sale: updatedSale,
          items: [newItem],
        );

        // Nomor transaksi HARUS tetap 'TRX-20260915-001'
        expect(updated.transactionNumber, 'TRX-20260915-001');
        expect(updated.transactionDate, '2026-09-10 10:00:00');
        expect(updated.paymentMethod, Sale.paymentTransfer);
        expect(updated.totalAmount, 15000);

        // Verifikasi di database
        final fromDb = await saleRepo.getById(created.id!);
        expect(fromDb!.transactionNumber, 'TRX-20260915-001');
        expect(fromDb.items?.length, 1);
        expect(fromDb.items?.first.quantity, 3);
      },
    );

    test(
      '7. Delete transaction cascades to sale_items and leaves master data intact',
      () async {
        final item = makeItem();
        final created = await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: '',
            transactionDate: '2026-09-15 12:00:00',
            totalAmount: 5000,
            totalHpp: 1340,
            totalProfit: 3660,
            createdAt: '',
            updatedAt: '',
          ),
          items: [item],
        );

        await saleRepo.deleteSale(created.id!);

        final afterDelete = await saleRepo.getById(created.id!);
        expect(afterDelete, isNull);

        // Pastikan sale_items juga terhapus
        final orphanItems = await db.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [created.id],
        );
        expect(orphanItems, isEmpty);

        // Pastikan master product tetap aman
        final product = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [1],
        );
        expect(product, isNotEmpty);
      },
    );

    test(
      '8. Historical snapshot: master product changes do NOT alter saved sale items',
      () async {
        final item = makeItem(
          productId: 1,
          productName: 'Es Teh Original',
          sellingPrice: 5000,
          hppPerUnit: 1340,
        );
        final created = await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: '',
            transactionDate: '2026-09-15 12:00:00',
            totalAmount: 5000,
            totalHpp: 1340,
            totalProfit: 3660,
            createdAt: '',
            updatedAt: '',
          ),
          items: [item],
        );

        // Ubah master product di database (misal nama diubah & status dinonaktifkan)
        await db.update(
          'products',
          {'name': 'Es Teh Manis Jumbo', 'status': 'inactive'},
          where: 'id = ?',
          whereArgs: [1],
        );

        // Buka kembali transaksi lama
        final retrieved = await saleRepo.getById(created.id!);
        expect(retrieved, isNotNull);
        // Snapshot harus tetap persis seperti saat disimpan
        expect(retrieved!.items?.first.productName, 'Es Teh Original');
        expect(retrieved.items?.first.sellingPrice, 5000);
        expect(retrieved.items?.first.hppPerUnit, 1340);
        expect(retrieved.items?.first.totalProfit, 3660);
      },
    );
  });
}
