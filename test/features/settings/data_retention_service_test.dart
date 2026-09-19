import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/backup/services/backup_file_manager.dart';
import 'package:labana/features/backup/services/database_backup_service.dart';
import 'package:labana/features/reports/data/report_repository.dart';
import 'package:labana/features/reports/services/pdf_file_storage.dart';
import 'package:labana/features/reports/services/pdf_report_generator.dart';
import 'package:labana/features/reports/services/report_pdf_service.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/settings/models/retention_models.dart';
import 'package:labana/features/settings/services/data_retention_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbFilePath;
  late Database testDb;
  late FakePdfFileStorage fakePdfStorage;
  late FakeBackupFileManager fakeFileManager;
  late ReportPdfService pdfService;
  late DatabaseBackupService backupService;
  late DataRetentionService retentionService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('retention_test_');
    dbFilePath = p.join(tempDir.path, DatabaseConstants.databaseName);

    testDb = await openDatabase(
      dbFilePath,
      version: DatabaseConstants.databaseVersion,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
    );
    DatabaseHelper.instance.setTestDatabase(testDb);

    fakePdfStorage = FakePdfFileStorage();
    pdfService = ReportPdfService(
      generator: const PdfReportGenerator(),
      storage: fakePdfStorage,
    );

    fakeFileManager = FakeBackupFileManager(
      tempDir: Directory(p.join(tempDir.path, 'backups')),
    );
    backupService = DatabaseBackupService(
      dbHelper: DatabaseHelper.instance,
      fileManager: fakeFileManager,
    );

    retentionService = DataRetentionService(
      dbHelper: DatabaseHelper.instance,
      reportRepository: ReportRepository(dbHelper: DatabaseHelper.instance),
      pdfService: pdfService,
      fileManager: fakeFileManager,
      backupService: backupService,
    );
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.instance.setTestDatabase(null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // Helper untuk mengisi data master lengkap (bahan mentah, olahan, produk, resep)
  Future<void> populateMasterData() async {
    // 1. Bahan mentah & harga
    final ingId = await testDb.insert(TableNames.ingredients, {
      'name': 'Kopi Arabika',
      'status': 'active',
      'created_at': '2026-01-01 00:00:00',
      'updated_at': '2026-01-01 00:00:00',
    });
    await testDb.insert(TableNames.ingredientPrices, {
      'ingredient_id': ingId,
      'purchase_quantity': 1.0,
      'purchase_unit': 'kg',
      'base_quantity': 1000.0,
      'base_unit': 'g',
      'price': 200000,
      'is_default': 1,
      'effective_from': '2026-01-01',
      'created_at': '2026-01-01 00:00:00',
    });

    // 2. Bahan olahan & komponen
    final procId = await testDb.insert(TableNames.processedIngredients, {
      'name': 'Espresso Base',
      'result_quantity': 30.0,
      'result_unit': 'ml',
      'status': 'active',
      'created_at': '2026-01-01 00:00:00',
      'updated_at': '2026-01-01 00:00:00',
    });
    await testDb.insert(TableNames.processedComponents, {
      'processed_ingredient_id': procId,
      'component_type': 'ingredient',
      'ingredient_id': ingId,
      'quantity': 20.0,
      'unit': 'g',
      'created_at': '2026-01-01 00:00:00',
    });

    // 3. Produk & harga
    final prodId = await testDb.insert(TableNames.products, {
      'name': 'Kopi Latte',
      'status': 'active',
      'created_at': '2026-01-01 00:00:00',
      'updated_at': '2026-01-01 00:00:00',
    });
    await testDb.insert(TableNames.productPrices, {
      'product_id': prodId,
      'selling_price': 25000,
      'effective_from': '2026-01-01',
      'created_at': '2026-01-01 00:00:00',
    });

    // 4. Versi resep & item resep
    final recipeId = await testDb.insert(TableNames.recipeVersions, {
      'product_id': prodId,
      'version_number': 1,
      'effective_from': '2026-01-01',
      'hpp_total': 8000,
      'status': 'active',
      'created_at': '2026-01-01 00:00:00',
    });
    await testDb.insert(TableNames.recipeItems, {
      'recipe_version_id': recipeId,
      'component_type': 'processed',
      'processed_ingredient_id': procId,
      'quantity': 30.0,
      'unit': 'ml',
      'created_at': '2026-01-01 00:00:00',
    });
  }

  // Helper untuk membuat transaksi penjualan
  Future<int> insertSale({
    required String transactionNumber,
    required String date,
    required int totalAmount,
    required int totalHpp,
    required int totalProfit,
  }) async {
    final saleId = await testDb.insert(TableNames.sales, {
      'transaction_number': transactionNumber,
      'transaction_date': date,
      'payment_method': 'cash',
      'total_amount': totalAmount,
      'total_hpp': totalHpp,
      'total_profit': totalProfit,
      'created_at': '$date 10:00:00',
      'updated_at': '$date 10:00:00',
    });

    await testDb.insert(TableNames.saleItems, {
      'sale_id': saleId,
      'product_id': 1,
      'recipe_version_id': 1,
      'product_name': 'Kopi Latte',
      'quantity': 1.0,
      'selling_price': totalAmount,
      'hpp_per_unit': totalHpp,
      'subtotal': totalAmount,
      'total_hpp': totalHpp,
      'total_profit': totalProfit,
      'created_at': '$date 10:00:00',
    });

    return saleId;
  }

  group('DataRetentionService - getMonthlyArchives', () {
    test('mengembalikan list kosong jika belum ada transaksi penjualan', () async {
      final archives = await retentionService.getMonthlyArchives();
      expect(archives, isEmpty);
    });

    test('mengelompokkan transaksi per bulan dan mendeteksi isCurrentMonth serta isDownloaded dengan akurat', () async {
      await populateMasterData();

      // Transaksi Januari 2026
      await insertSale(
        transactionNumber: 'TRX-20260101-001',
        date: '2026-01-15',
        totalAmount: 50000,
        totalHpp: 16000,
        totalProfit: 34000,
      );

      // Transaksi Februari 2026
      await insertSale(
        transactionNumber: 'TRX-20260201-001',
        date: '2026-02-10',
        totalAmount: 25000,
        totalHpp: 8000,
        totalProfit: 17000,
      );
      await insertSale(
        transactionNumber: 'TRX-20260201-002',
        date: '2026-02-20',
        totalAmount: 25000,
        totalHpp: 8000,
        totalProfit: 17000,
      );

      // Simulasikan laporan Januari 2026 sudah diunduh ke report_archives
      await testDb.insert(TableNames.reportArchives, {
        'report_type': 'monthly',
        'period_start': '2026-01-01',
        'period_end': '2026-01-31',
        'file_name': 'Laporan-Labana-Bulanan-2026-01.pdf',
        'file_path': '/storage/reports/Laporan-Labana-Bulanan-2026-01.pdf',
        'created_at': '2026-02-01 10:00:00',
      });

      // Acuan sekarang: Februari 2026
      final refDate = DateTime(2026, 2, 25);
      final archives = await retentionService.getMonthlyArchives(now: refDate);

      expect(archives.length, 2);

      // Urutan terbaru: Februari 2026 (index 0)
      final feb = archives[0];
      expect(feb.year, 2026);
      expect(feb.month, 2);
      expect(feb.monthLabel, 'Februari 2026');
      expect(feb.transactionCount, 2);
      expect(feb.totalOmzet, 50000);
      expect(feb.isCurrentMonth, isTrue); // Bulan berjalan
      expect(feb.isDownloaded, isFalse);

      // Index 1: Januari 2026
      final jan = archives[1];
      expect(jan.year, 2026);
      expect(jan.month, 1);
      expect(jan.monthLabel, 'Januari 2026');
      expect(jan.transactionCount, 1);
      expect(jan.totalOmzet, 50000);
      expect(jan.isCurrentMonth, isFalse);
      expect(jan.isDownloaded, isTrue);
      expect(jan.needsReDownload, isFalse);
      expect(jan.canDelete, isTrue);
      expect(jan.downloadedFilePath, '/storage/reports/Laporan-Labana-Bulanan-2026-01.pdf');
    });

    test('getMonthlyArchives menandai needsReDownload = true dan canDelete = false jika ada transaksi susulan', () async {
      await populateMasterData();

      // Transaksi Januari 2026 pertama
      await insertSale(
        transactionNumber: 'TRX-20260101-001',
        date: '2026-01-15',
        totalAmount: 50000,
        totalHpp: 16000,
        totalProfit: 34000,
      );

      // Arsip dibuat tanggal 2026-02-01 10:00:00
      await testDb.insert(TableNames.reportArchives, {
        'report_type': 'monthly',
        'period_start': '2026-01-01',
        'period_end': '2026-01-31',
        'file_name': 'Laporan-Labana-Bulanan-2026-01.pdf',
        'file_path': '/storage/reports/Laporan-Labana-Bulanan-2026-01.pdf',
        'created_at': '2026-02-01 10:00:00',
      });

      // Transaksi susulan Januari 2026 dibuat pada 2026-02-02 (setelah arsip dibuat)
      final saleId = await testDb.insert(TableNames.sales, {
        'transaction_number': 'TRX-20260101-002',
        'transaction_date': '2026-01-20 14:00:00',
        'payment_method': 'cash',
        'total_amount': 25000,
        'total_hpp': 8000,
        'total_profit': 17000,
        'created_at': '2026-02-02 12:00:00',
        'updated_at': '2026-02-02 12:00:00',
      });
      await testDb.insert(TableNames.saleItems, {
        'sale_id': saleId,
        'product_id': 1,
        'recipe_version_id': 1,
        'product_name': 'Kopi Latte',
        'quantity': 1.0,
        'selling_price': 25000,
        'hpp_per_unit': 8000,
        'subtotal': 25000,
        'total_hpp': 8000,
        'total_profit': 17000,
        'created_at': '2026-02-02 12:00:00',
      });

      final refDate = DateTime(2026, 3, 1);
      final archives = await retentionService.getMonthlyArchives(now: refDate);

      expect(archives.length, 1);
      final jan = archives[0];
      expect(jan.isDownloaded, isTrue);
      expect(jan.needsReDownload, isTrue);
      expect(jan.canDelete, isFalse); // Tombol hapus harus dinonaktifkan
    });
  });

  group('DataRetentionService - downloadMonthlyReport', () {
    test('menghasilkan laporan PDF dan mencatat ke tabel report_archives', () async {
      await populateMasterData();
      await insertSale(
        transactionNumber: 'TRX-20260101-001',
        date: '2026-01-15',
        totalAmount: 50000,
        totalHpp: 16000,
        totalProfit: 34000,
      );

      final file = await retentionService.downloadMonthlyReport(
        year: 2026,
        month: 1,
        saveToPublicDownloads: false, // In test environment, skip public dir
      );

      expect(file.existsSync() || fakePdfStorage.storedFiles.isNotEmpty, isTrue);

      final downloaded = await retentionService.isMonthReportDownloaded(2026, 1);
      expect(downloaded, isTrue);

      // Periksa baris di report_archives
      final records = await testDb.query(
        TableNames.reportArchives,
        where: "report_type = 'monthly'",
      );
      expect(records.length, 1);
      expect(records.first['period_start'], '2026-01-01');
      expect(records.first['period_end'], '2026-01-31');
    });
  });

  group('DataRetentionService - deleteMonthlyTransactions (Proteksi & Integritas Data)', () {
    test('menolak penghapusan pada bulan berjalan (Active Month Shield)', () async {
      await populateMasterData();
      await insertSale(
        transactionNumber: 'TRX-20260201-001',
        date: '2026-02-10',
        totalAmount: 25000,
        totalHpp: 8000,
        totalProfit: 17000,
      );

      final now = DateTime(2026, 2, 20);

      expect(
        () => retentionService.deleteMonthlyTransactions(
          year: 2026,
          month: 2,
          now: now,
        ),
        throwsA(isA<RetentionException>().having(
          (e) => e.message,
          'message',
          contains('Bulan berjalan yang sedang aktif dilindungi'),
        )),
      );
    });

    test('menolak penghapusan jika laporan belum pernah diunduh (Download Guard)', () async {
      await populateMasterData();
      await insertSale(
        transactionNumber: 'TRX-20260101-001',
        date: '2026-01-15',
        totalAmount: 50000,
        totalHpp: 16000,
        totalProfit: 34000,
      );

      // Acuan sekarang: Februari 2026 (Januari adalah bulan lalu)
      final now = DateTime(2026, 2, 20);

      expect(
        () => retentionService.deleteMonthlyTransactions(
          year: 2026,
          month: 1,
          now: now,
        ),
        throwsA(isA<RetentionException>().having(
          (e) => e.message,
          'message',
          contains('belum diunduh'),
        )),
      );
    });

    test('HANYA menghapus sales dan sale_items bulan target; master data resep, produk, dan bahan TETAP UTUH 100%', () async {
      await populateMasterData();

      // Transaksi Januari 2026
      await insertSale(
        transactionNumber: 'TRX-20260101-001',
        date: '2026-01-15',
        totalAmount: 50000,
        totalHpp: 16000,
        totalProfit: 34000,
      );
      await insertSale(
        transactionNumber: 'TRX-20260101-002',
        date: '2026-01-20',
        totalAmount: 75000,
        totalHpp: 24000,
        totalProfit: 51000,
      );

      // Transaksi Februari 2026 (bulan lain yang tidak dihapus)
      await insertSale(
        transactionNumber: 'TRX-20260201-001',
        date: '2026-02-10',
        totalAmount: 30000,
        totalHpp: 10000,
        totalProfit: 20000,
      );

      // Catat bahwa laporan Januari 2026 telah diunduh
      await testDb.insert(TableNames.reportArchives, {
        'report_type': 'monthly',
        'period_start': '2026-01-01',
        'period_end': '2026-01-31',
        'file_name': 'Laporan-Labana-Bulanan-2026-01.pdf',
        'file_path': '/storage/reports/Laporan-Labana-Bulanan-2026-01.pdf',
        'created_at': '2026-02-01 10:00:00',
      });

      // Simpan hitungan data master sebelum penghapusan
      final countIngredientsBefore = (await testDb.query(TableNames.ingredients)).length;
      final countIngPricesBefore = (await testDb.query(TableNames.ingredientPrices)).length;
      final countProcessedBefore = (await testDb.query(TableNames.processedIngredients)).length;
      final countProcComponentsBefore = (await testDb.query(TableNames.processedComponents)).length;
      final countProductsBefore = (await testDb.query(TableNames.products)).length;
      final countProductPricesBefore = (await testDb.query(TableNames.productPrices)).length;
      final countRecipesBefore = (await testDb.query(TableNames.recipeVersions)).length;
      final countRecipeItemsBefore = (await testDb.query(TableNames.recipeItems)).length;

      expect(countIngredientsBefore, 1);
      expect(countIngPricesBefore, 1);
      expect(countProcessedBefore, 1);
      expect(countProcComponentsBefore, 1);
      expect(countProductsBefore, 1);
      expect(countProductPricesBefore, 1);
      expect(countRecipesBefore, 1);
      expect(countRecipeItemsBefore, 1);

      // Simpan nilai awal sale notifier
      final notifierStart = SaleRepository.salesChangeNotifier.value;

      // Eksekusi penghapusan Januari 2026 (sekarang acuan Maret 2026)
      final now = DateTime(2026, 3, 1);
      final deletedCount = await retentionService.deleteMonthlyTransactions(
        year: 2026,
        month: 1,
        now: now,
      );

      expect(deletedCount, 2);

      // Verifikasi tabel sales: transaksi Januari hilang, transaksi Februari tetap ada
      final remainingSales = await testDb.query(TableNames.sales);
      expect(remainingSales.length, 1);
      expect(remainingSales.first['transaction_number'], 'TRX-20260201-001');

      // Verifikasi sale_items: item milik Januari hilang, item Februari tetap ada
      final remainingItems = await testDb.query(TableNames.saleItems);
      expect(remainingItems.length, 1);
      expect(remainingItems.first['sale_id'], remainingSales.first['id']);

      // === VERIFIKASI MUTLAK INTEGRITAS MASTER DATA ===
      final countIngredientsAfter = (await testDb.query(TableNames.ingredients)).length;
      final countIngPricesAfter = (await testDb.query(TableNames.ingredientPrices)).length;
      final countProcessedAfter = (await testDb.query(TableNames.processedIngredients)).length;
      final countProcComponentsAfter = (await testDb.query(TableNames.processedComponents)).length;
      final countProductsAfter = (await testDb.query(TableNames.products)).length;
      final countProductPricesAfter = (await testDb.query(TableNames.productPrices)).length;
      final countRecipesAfter = (await testDb.query(TableNames.recipeVersions)).length;
      final countRecipeItemsAfter = (await testDb.query(TableNames.recipeItems)).length;

      expect(countIngredientsAfter, countIngredientsBefore);
      expect(countIngPricesAfter, countIngPricesBefore);
      expect(countProcessedAfter, countProcessedBefore);
      expect(countProcComponentsAfter, countProcComponentsBefore);
      expect(countProductsAfter, countProductsBefore);
      expect(countProductPricesAfter, countProductPricesBefore);
      expect(countRecipesAfter, countRecipesBefore);
      expect(countRecipeItemsAfter, countRecipeItemsBefore);

      // Verifikasi bahwa cadangan pra-retensi otomatis dibuat di fakeFileManager
      final backups = await fakeFileManager.listLocalBackups();
      expect(backups.any((b) => b.fileName.contains('PreRetention-2026-01')), isTrue);

      // Verifikasi bahwa salesChangeNotifier telah di-increment
      expect(SaleRepository.salesChangeNotifier.value, greaterThan(notifierStart));
    });
  });
}
