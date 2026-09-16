import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/reports/data/report_repository.dart';
import 'package:labana/features/reports/models/report_models.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database testDb;
  late SaleRepository saleRepo;
  late ReportRepository reportRepo;

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
    reportRepo = ReportRepository();
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  // Helper untuk membuat master produk
  Future<int> insertProduct(String name) async {
    return await testDb.insert(TableNames.products, {
      'name': name,
      'status': 'active',
      'created_at': '2026-09-01 08:00:00',
      'updated_at': '2026-09-01 08:00:00',
    });
  }

  // Helper untuk membuat master resep
  Future<int> insertRecipeVersion(
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

  // Helper untuk membuat transaksi penjualan
  Future<Sale> createSaleHelper({
    required String date,
    required String paymentMethod,
    required List<({int productId, int recipeVersionId, String name, double qty, int price, int hpp})> itemsData,
  }) async {
    var totalAmount = 0;
    var totalHpp = 0;
    var totalProfit = 0;

    final saleItems = <SaleItem>[];
    for (final item in itemsData) {
      final subtotal = (item.qty * item.price).round();
      final itemHpp = (item.qty * item.hpp).round();
      final itemProfit = subtotal - itemHpp;

      totalAmount += subtotal;
      totalHpp += itemHpp;
      totalProfit += itemProfit;

      saleItems.add(
        SaleItem(
          productId: item.productId,
          recipeVersionId: item.recipeVersionId,
          productName: item.name,
          quantity: item.qty,
          sellingPrice: item.price,
          hppPerUnit: item.hpp,
          subtotal: subtotal,
          totalHpp: itemHpp,
          totalProfit: itemProfit,
          createdAt: '$date 10:00:00',
        ),
      );
    }

    final sale = Sale(
      transactionNumber: '',
      transactionDate: '$date 10:00:00',
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      totalHpp: totalHpp,
      totalProfit: totalProfit,
      createdAt: '$date 10:00:00',
      updatedAt: '$date 10:00:00',
    );

    return await saleRepo.createSaleWithItems(sale: sale, items: saleItems);
  }

  group('Laporan Harian (Daily)', () {
    test('Empty state ketika tidak ada transaksi pada tanggal tersebut', () async {
      final summary = await reportRepo.getReportSummary('2026-09-16', '2026-09-16');
      expect(summary.totalOmzet, 0);
      expect(summary.totalHpp, 0);
      expect(summary.totalProfit, 0);
      expect(summary.transactionCount, 0);
      expect(summary.productsSold, 0.0);

      final breakdown = await reportRepo.getProductBreakdown('2026-09-16', '2026-09-16');
      expect(breakdown, isEmpty);

      final top = await reportRepo.getTopSellingProduct('2026-09-16', '2026-09-16');
      expect(top, isNull);

      final highest = await reportRepo.getHighestProfitProduct('2026-09-16', '2026-09-16');
      expect(highest, isNull);
    });

    test('Satu transaksi menghasilkan angka omzet, HPP, laba, dan produk terjual yang akurat', () async {
      final p1 = await insertProduct('Es Teh Manis');
      final r1 = await insertRecipeVersion(p1, 2000);

      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 3.0, price: 5000, hpp: 2000),
        ],
      );

      final summary = await reportRepo.getReportSummary('2026-09-16', '2026-09-16');
      expect(summary.totalOmzet, 15000);
      expect(summary.totalHpp, 6000);
      expect(summary.totalProfit, 9000);
      expect(summary.transactionCount, 1);
      expect(summary.productsSold, 3.0);
    });

    test('Beberapa transaksi di hari yang sama terakumulasi dan mengisolasi tanggal lain', () async {
      final p1 = await insertProduct('Es Teh Manis');
      final r1 = await insertRecipeVersion(p1, 2000);

      // Transaksi hari target (16 Sep) - Transaksi 1
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 2.0, price: 5000, hpp: 2000),
        ],
      );

      // Transaksi hari target (16 Sep) - Transaksi 2
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'qris',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 4.0, price: 5000, hpp: 2000),
        ],
      );

      // Transaksi di tanggal lain (15 Sep & 17 Sep) yang TIDAK boleh ikut
      await createSaleHelper(
        date: '2026-09-15',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 10.0, price: 5000, hpp: 2000),
        ],
      );
      await createSaleHelper(
        date: '2026-09-17',
        paymentMethod: 'transfer',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 10.0, price: 5000, hpp: 2000),
        ],
      );

      final summary = await reportRepo.getReportSummary('2026-09-16', '2026-09-16');
      expect(summary.transactionCount, 2);
      expect(summary.productsSold, 6.0); // 2 + 4
      expect(summary.totalOmzet, 30000); // 10.000 + 20.000
      expect(summary.totalHpp, 12000);   // 4.000 + 8.000
      expect(summary.totalProfit, 18000); // 6.000 + 12.000
    });
  });

  group('Laporan Mingguan (Weekly)', () {
    test('Mengakumulasikan transaksi Senin–Minggu dan mengabaikan minggu sebelum/sesudah', () async {
      // Minggu target: Senin 14 Sep s/d Minggu 20 Sep 2026
      final p1 = await insertProduct('Es Kopi Susu');
      final r1 = await insertRecipeVersion(p1, 5000);

      // 1. Batas awal minggu (Senin, 14 Sep)
      await createSaleHelper(
        date: '2026-09-14',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Kopi Susu', qty: 2.0, price: 15000, hpp: 5000),
        ],
      );

      // 2. Pertengahan minggu (Kamis, 17 Sep)
      await createSaleHelper(
        date: '2026-09-17',
        paymentMethod: 'qris',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Kopi Susu', qty: 3.0, price: 15000, hpp: 5000),
        ],
      );

      // 3. Batas akhir minggu (Minggu, 20 Sep)
      await createSaleHelper(
        date: '2026-09-20',
        paymentMethod: 'transfer',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Kopi Susu', qty: 5.0, price: 15000, hpp: 5000),
        ],
      );

      // 4. Di luar minggu: Minggu sebelumnya (Minggu, 13 Sep)
      await createSaleHelper(
        date: '2026-09-13',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Kopi Susu', qty: 10.0, price: 15000, hpp: 5000),
        ],
      );

      // 5. Di luar minggu: Minggu berikutnya (Senin, 21 Sep)
      await createSaleHelper(
        date: '2026-09-21',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Kopi Susu', qty: 10.0, price: 15000, hpp: 5000),
        ],
      );

      final summary = await reportRepo.getReportSummary('2026-09-14', '2026-09-20');
      expect(summary.transactionCount, 3);
      expect(summary.productsSold, 10.0); // 2 + 3 + 5
      expect(summary.totalOmzet, 150000); // 10 * 15.000
      expect(summary.totalHpp, 50000);    // 10 * 5.000
      expect(summary.totalProfit, 100000);// 150.000 - 50.000
    });

    test('getDailyBreakdown menyusun 7 hari lengkap (Senin–Minggu) dengan tanggal kosong Rp0', () async {
      final p1 = await insertProduct('Es Cokelat');
      final r1 = await insertRecipeVersion(p1, 4000);

      // Hanya ada transaksi di hari Rabu (16 Sep)
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Cokelat', qty: 5.0, price: 12000, hpp: 4000),
        ],
      );

      final dailyBreakdown = await reportRepo.getDailyBreakdown('2026-09-14', '2026-09-20');

      // Wajib ada 7 hari berurutan
      expect(dailyBreakdown.length, 7);
      expect(dailyBreakdown[0].dateStr, '2026-09-14'); // Senin
      expect(dailyBreakdown[0].omzet, 0);
      expect(dailyBreakdown[0].transactionCount, 0);

      expect(dailyBreakdown[2].dateStr, '2026-09-16'); // Rabu
      expect(dailyBreakdown[2].omzet, 60000);
      expect(dailyBreakdown[2].hpp, 20000);
      expect(dailyBreakdown[2].profit, 40000);
      expect(dailyBreakdown[2].transactionCount, 1);
      expect(dailyBreakdown[2].productsSold, 5.0);

      expect(dailyBreakdown[6].dateStr, '2026-09-20'); // Minggu
      expect(dailyBreakdown[6].omzet, 0);
      expect(dailyBreakdown[6].transactionCount, 0);
    });
  });

  group('Laporan Bulanan (Monthly)', () {
    test('Mengakumulasikan transaksi dalam satu bulan dan mengisolasi bulan sebelum/sesudah', () async {
      final p1 = await insertProduct('Matcha Latte');
      final r1 = await insertRecipeVersion(p1, 8000);

      // Awal bulan (1 Sep 2026)
      await createSaleHelper(
        date: '2026-09-01',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Matcha Latte', qty: 2.0, price: 20000, hpp: 8000),
        ],
      );

      // Akhir bulan (30 Sep 2026)
      await createSaleHelper(
        date: '2026-09-30',
        paymentMethod: 'qris',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Matcha Latte', qty: 3.0, price: 20000, hpp: 8000),
        ],
      );

      // Bulan sebelumnya (31 Agustus 2026)
      await createSaleHelper(
        date: '2026-08-31',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Matcha Latte', qty: 10.0, price: 20000, hpp: 8000),
        ],
      );

      // Bulan berikutnya (1 Oktober 2026)
      await createSaleHelper(
        date: '2026-10-01',
        paymentMethod: 'transfer',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Matcha Latte', qty: 10.0, price: 20000, hpp: 8000),
        ],
      );

      final summary = await reportRepo.getReportSummary('2026-09-01', '2026-09-30');
      expect(summary.transactionCount, 2);
      expect(summary.productsSold, 5.0); // 2 + 3
      expect(summary.totalOmzet, 100000); // 5 * 20.000
      expect(summary.totalHpp, 40000);    // 5 * 8.000
      expect(summary.totalProfit, 60000); // 100.000 - 40.000
    });

    test('Bulan Februari tahun kabisat (2024: 29 hari) tercover hingga tanggal 29', () async {
      final p1 = await insertProduct('Kopi Tubruk');
      final r1 = await insertRecipeVersion(p1, 1500);

      await createSaleHelper(
        date: '2024-02-29',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Kopi Tubruk', qty: 4.0, price: 5000, hpp: 1500),
        ],
      );

      final summary = await reportRepo.getReportSummary('2024-02-01', '2024-02-29');
      expect(summary.transactionCount, 1);
      expect(summary.productsSold, 4.0);
      expect(summary.totalOmzet, 20000);
      expect(summary.totalProfit, 14000);
    });
  });

  group('Breakdown Produk & Deterministic Tie-Breaker', () {
    test('Produk yang sama diakumulasi di seluruh transaksi dalam periode', () async {
      final p1 = await insertProduct('Es Teh Manis');
      final r1 = await insertRecipeVersion(p1, 2000);
      final p2 = await insertProduct('Es Jeruk');
      final r2 = await insertRecipeVersion(p2, 3000);

      // Transaksi 1
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 5.0, price: 5000, hpp: 2000),
          (productId: p2, recipeVersionId: r2, name: 'Es Jeruk', qty: 2.0, price: 7000, hpp: 3000),
        ],
      );

      // Transaksi 2
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'qris',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh Manis', qty: 10.0, price: 5000, hpp: 2000),
        ],
      );

      final breakdown = await reportRepo.getProductBreakdown('2026-09-16', '2026-09-16');
      expect(breakdown.length, 2);

      // Es Teh Manis total qty = 15, omzet = 75.000, hpp = 30.000, profit = 45.000
      final esTeh = breakdown.firstWhere((p) => p.productId == p1);
      expect(esTeh.quantity, 15.0);
      expect(esTeh.omzet, 75000);
      expect(esTeh.hpp, 30000);
      expect(esTeh.profit, 45000);

      // Es Jeruk total qty = 2, omzet = 14.000, hpp = 6.000, profit = 8.000
      final esJeruk = breakdown.firstWhere((p) => p.productId == p2);
      expect(esJeruk.quantity, 2.0);
      expect(esJeruk.omzet, 14000);
      expect(esJeruk.hpp, 6000);
      expect(esJeruk.profit, 8000);
    });

    test('Top Selling & Highest Profit dengan deterministic tie-breaker (product_id ASC)', () async {
      final p1 = await insertProduct('Produk Alpha');
      final r1 = await insertRecipeVersion(p1, 2000);
      final p2 = await insertProduct('Produk Beta');
      final r2 = await insertRecipeVersion(p2, 2000);

      // Keduanya memiliki kuantitas dan laba yang sama persis: qty 5, price 5000, hpp 2000
      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Produk Alpha', qty: 5.0, price: 5000, hpp: 2000),
          (productId: p2, recipeVersionId: r2, name: 'Produk Beta', qty: 5.0, price: 5000, hpp: 2000),
        ],
      );

      final topSelling = await reportRepo.getTopSellingProduct('2026-09-16', '2026-09-16');
      // Karena kuantitas sama (5.0), tie-breaker memilih product_id terkecil (p1)
      expect(topSelling?.productId, p1);
      expect(topSelling?.productName, 'Produk Alpha');

      final highestProfit = await reportRepo.getHighestProfitProduct('2026-09-16', '2026-09-16');
      // Karena profit sama (15.000), tie-breaker memilih product_id terkecil (p1)
      expect(highestProfit?.productId, p1);
      expect(highestProfit?.productName, 'Produk Alpha');
    });
  });

  group('Historical Snapshot Integrity', () {
    test('Perubahan master data harga, nama, atau resep TIDAK mengubah data laporan transaksi lama', () async {
      final p1 = await insertProduct('Es Lemon Tea Original');
      final r1 = await insertRecipeVersion(p1, 2500, versionNumber: 1);

      // Buat transaksi lama dengan snapshot harga jual Rp6.000, HPP Rp2.500
      await createSaleHelper(
        date: '2026-09-10',
        paymentMethod: 'cash',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Lemon Tea Original', qty: 2.0, price: 6000, hpp: 2500),
        ],
      );

      // Verifikasi laporan sebelum perubahan master
      final initialSummary = await reportRepo.getReportSummary('2026-09-10', '2026-09-10');
      expect(initialSummary.totalOmzet, 12000);
      expect(initialSummary.totalHpp, 5000);
      expect(initialSummary.totalProfit, 7000);

      // Simulasikan perubahan master data:
      // 1. Ubah nama produk di master
      await testDb.update(
        TableNames.products,
        {'name': 'Es Lemon Tea Deluxe Ultra'},
        where: 'id = ?',
        whereArgs: [p1],
      );

      // 2. Tambah resep versi 2 dengan HPP lebih tinggi (Rp4.000)
      await insertRecipeVersion(p1, 4000, versionNumber: 2);

      // 3. Tambah harga jual baru di master (Rp10.000)
      await testDb.insert(TableNames.productPrices, {
        'product_id': p1,
        'selling_price': 10000,
        'effective_from': '2026-09-15',
      });

      // Kueri ulang laporan untuk tanggal transaksi lama (10 Sep 2026)
      final postSummary = await reportRepo.getReportSummary('2026-09-10', '2026-09-10');
      expect(postSummary.totalOmzet, 12000); // Tetap 12.000
      expect(postSummary.totalHpp, 5000);   // Tetap 5.000
      expect(postSummary.totalProfit, 7000); // Tetap 7.000

      final postBreakdown = await reportRepo.getProductBreakdown('2026-09-10', '2026-09-10');
      expect(postBreakdown.first.productName, 'Es Lemon Tea Original'); // Nama snapshot tetap terjaga
      expect(postBreakdown.first.omzet, 12000);
      expect(postBreakdown.first.hpp, 5000);
      expect(postBreakdown.first.profit, 7000);
    });
  });

  group('getReportData Facade Integration', () {
    test('Memuat seluruh data (summary, products, top, highest, daily, paymentMethods) secara konsisten', () async {
      final p1 = await insertProduct('Es Teh');
      final r1 = await insertRecipeVersion(p1, 1000);

      await createSaleHelper(
        date: '2026-09-16',
        paymentMethod: 'qris',
        itemsData: [
          (productId: p1, recipeVersionId: r1, name: 'Es Teh', qty: 2.0, price: 3000, hpp: 1000),
        ],
      );

      final reportData = await reportRepo.getReportData(
        periodType: ReportPeriodType.weekly,
        referenceDate: DateTime(2026, 9, 16),
      );

      expect(reportData.isEmpty, isFalse);
      expect(reportData.summary.totalOmzet, 6000);
      expect(reportData.products.length, 1);
      expect(reportData.topSelling?.productName, 'Es Teh');
      expect(reportData.highestProfit?.productName, 'Es Teh');
      expect(reportData.dailyBreakdown.length, 7);
      expect(reportData.paymentMethods.length, 1);
      expect(reportData.paymentMethods.first.paymentMethodLabel, 'QRIS');
    });
  });
}

