import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/features/sales/services/transaction_number_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late TransactionNumberGenerator generator;
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
    generator = TransactionNumberGenerator();
    saleRepo = SaleRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  SaleItem dummyItem({int productId = 1}) {
    return SaleItem(
      productId: productId,
      recipeVersionId: 1,
      productName: 'Sample',
      quantity: 1,
      sellingPrice: 5000,
      hppPerUnit: 2000,
      subtotal: 5000,
      totalHpp: 2000,
      totalProfit: 3000,
      createdAt: '2026-09-15T00:00:00Z',
    );
  }

  // Siapkan data dummy produk dan resep agar foreign key valid
  Future<void> setupProductAndRecipe() async {
    await db.insert('products', {
      'id': 1,
      'name': 'Sample Product',
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
      'updated_at': '2026-09-01 00:00:00',
    });
    await db.insert('recipe_versions', {
      'id': 1,
      'product_id': 1,
      'version_number': 1,
      'effective_from': '2026-09-01',
      'hpp_total': 2000,
      'status': 'active',
      'created_at': '2026-09-01 00:00:00',
    });
  }

  group('TransactionNumberGenerator Tests', () {
    test('1. First transaction on date -> TRX-YYYYMMDD-001', () async {
      final num1 = await generator.generate('2026-09-15 10:00:00');
      expect(num1, 'TRX-20260915-001');
    });

    test('2. Next transaction on same date -> TRX-YYYYMMDD-002', () async {
      await setupProductAndRecipe();

      await saleRepo.createSaleWithItems(
        sale: const Sale(
          transactionNumber: 'TRX-20260915-001',
          transactionDate: '2026-09-15 10:00:00',
          totalAmount: 5000,
          totalHpp: 2000,
          totalProfit: 3000,
          createdAt: '',
          updatedAt: '',
        ),
        items: [dummyItem()],
      );

      final nextNum = await generator.generate('2026-09-15 11:00:00');
      expect(nextNum, 'TRX-20260915-002');
    });

    test(
      '3. Different date has its own independent sequence starting at 001',
      () async {
        await setupProductAndRecipe();

        // Transaksi di tanggal 15 Sep
        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 5000,
            totalHpp: 2000,
            totalProfit: 3000,
            createdAt: '',
            updatedAt: '',
          ),
          items: [dummyItem()],
        );

        // Tanggal 16 Sep harus mulai dari 001
        final numDate2 = await generator.generate('2026-09-16 09:00:00');
        expect(numDate2, 'TRX-20260916-001');
      },
    );

    test(
      '4. Offset parameter generates sequence leap for collision retry',
      () async {
        await setupProductAndRecipe();

        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 5000,
            totalHpp: 2000,
            totalProfit: 3000,
            createdAt: '',
            updatedAt: '',
          ),
          items: [dummyItem()],
        );

        // Normal next sequence is 002 (offset = 0)
        final seq0 = await generator.generate('2026-09-15', offset: 0);
        expect(seq0, 'TRX-20260915-002');

        // Retry with offset = 1 jumps to 003
        final seq1 = await generator.generate('2026-09-15', offset: 1);
        expect(seq1, 'TRX-20260915-003');
      },
    );

    test(
      '5. Sequence gap handling: deletion does not cause sequence reuse',
      () async {
        await setupProductAndRecipe();

        final s1 = await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-001',
            transactionDate: '2026-09-15 10:00:00',
            totalAmount: 5000,
            totalHpp: 2000,
            totalProfit: 3000,
            createdAt: '',
            updatedAt: '',
          ),
          items: [dummyItem()],
        );

        await saleRepo.createSaleWithItems(
          sale: const Sale(
            transactionNumber: 'TRX-20260915-002',
            transactionDate: '2026-09-15 11:00:00',
            totalAmount: 5000,
            totalHpp: 2000,
            totalProfit: 3000,
            createdAt: '',
            updatedAt: '',
          ),
          items: [dummyItem()],
        );

        // Hapus transaksi s1 (001)
        await saleRepo.deleteSale(s1.id!);

        // Transaksi berikutnya tetap 003 (karena 002 masih ada sebagai max sequence)
        final nextNum = await generator.generate('2026-09-15');
        expect(nextNum, 'TRX-20260915-003');
      },
    );
  });
}
