import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/core/theme/app_theme.dart';
import 'package:labana/features/reports/data/report_repository.dart';
import 'package:labana/features/reports/models/report_models.dart';
import 'package:labana/features/reports/presentation/screens/reports_screen.dart';
import 'package:labana/features/reports/services/report_date_helper.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/features/reports/services/pdf_file_storage.dart';
import 'package:labana/features/reports/services/report_pdf_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database testDb;
  late SaleRepository saleRepo;
  late ReportRepository reportRepo;
  late FakePdfFileStorage fakeStorage;
  late ReportPdfService pdfService;

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
    fakeStorage = FakePdfFileStorage();
    pdfService = ReportPdfService(storage: fakeStorage);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  Future<void> settleAsync(
    WidgetTester tester, {
    int maxIterations = 30,
  }) async {
    for (var i = 0; i < maxIterations; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<int> insertProduct(String name) async {
    return await testDb.insert(TableNames.products, {
      'name': name,
      'status': 'active',
      'created_at': '2026-09-01 08:00:00',
      'updated_at': '2026-09-01 08:00:00',
    });
  }

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

  Future<Sale> createSaleHelper({
    required String date,
    required String paymentMethod,
    required List<
      ({
        int productId,
        int recipeVersionId,
        String name,
        double qty,
        int price,
        int hpp,
      })
    >
    itemsData,
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

  Widget createTestWidget({
    ThemeMode themeMode = ThemeMode.light,
    ReportPdfService? pdfServiceOverride,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: ReportsScreen(
        reportRepo: reportRepo,
        pdfService: pdfServiceOverride ?? pdfService,
      ),
    );
  }

  group('ReportsScreen Widget Tests', () {
    testWidgets('Menampilkan empty state saat belum ada data transaksi', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await settleAsync(tester);

      // Verifikasi judul AppBar & SegmentedButton
      expect(find.text('Laporan'), findsOneWidget);
      expect(find.text('Hari'), findsOneWidget);
      expect(find.text('Minggu'), findsOneWidget);
      expect(find.text('Bulan'), findsOneWidget);

      // Verifikasi empty state text
      expect(
        find.text('Belum ada transaksi pada periode ini.'),
        findsOneWidget,
      );

      // Verifikasi 4 stat cards menampilkan Rp0 dan 0
      expect(find.text('Omzet'), findsOneWidget);
      expect(find.text('Modal / HPP'), findsOneWidget);
      expect(find.text('Estimasi Laba'), findsOneWidget);
      expect(find.text('Rp0'), findsNWidgets(3));
      expect(find.text('0 Transaksi • 0 Terjual'), findsOneWidget);
    });

    testWidgets(
      'Perpindahan segmen periode (Hari -> Minggu -> Bulan) memicu pembaruan laporan',
      (tester) async {
        final todayStr = ReportDateHelper.formatDate(DateTime.now());

        await tester.runAsync(() async {
          final p1 = await insertProduct('Es Teh');
          final r1 = await insertRecipeVersion(p1, 1000);
          await createSaleHelper(
            date: todayStr,
            paymentMethod: 'cash',
            itemsData: [
              (
                productId: p1,
                recipeVersionId: r1,
                name: 'Es Teh',
                qty: 2.0,
                price: 5000,
                hpp: 1000,
              ),
            ],
          );
        });

        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        // Pada tab Hari: Breakdown Harian tidak muncul
        expect(find.text('Breakdown Harian'), findsNothing);

        // Klik segmen "Minggu"
        await tester.tap(find.text('Minggu'));
        await settleAsync(tester);

        // Periode mingguan menampilkan rincian Breakdown Harian
        expect(find.text('Breakdown Harian'), findsOneWidget);
        expect(find.text('7 Hari'), findsOneWidget);

        // Klik segmen "Bulan"
        await tester.tap(find.text('Bulan'));
        await settleAsync(tester);

        expect(find.text('Breakdown Harian'), findsOneWidget);

        // Klik kembali ke "Hari"
        await tester.tap(find.text('Hari'));
        await settleAsync(tester);

        // Breakdown Harian tidak muncul di tab harian
        expect(find.text('Breakdown Harian'), findsNothing);
      },
    );

    testWidgets(
      'Navigasi tombol previous dan next periode bekerja tanpa error',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        // Catat label awal
        final initialLabel = ReportDateHelper.formatPeriodLabel(
          ReportPeriodType.daily,
          DateTime.now(),
        );
        expect(find.text(initialLabel), findsOneWidget);

        // Tekan tombol Previous (<)
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await settleAsync(tester);

        final prevLabel = ReportDateHelper.formatPeriodLabel(
          ReportPeriodType.daily,
          DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(find.text(prevLabel), findsOneWidget);

        // Tekan tombol Next (>) kembali ke hari ini
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await settleAsync(tester);

        expect(find.text(initialLabel), findsOneWidget);
      },
    );

    testWidgets(
      'Menampilkan ringkasan finansial riil, produk terlaris, laba tertinggi, dan performa menu',
      (tester) async {
        final todayStr = ReportDateHelper.formatDate(DateTime.now());

        await tester.runAsync(() async {
          final p1 = await insertProduct('Es Teh Manis');
          final r1 = await insertRecipeVersion(p1, 2000);
          final p2 = await insertProduct('Es Jeruk Segar');
          final r2 = await insertRecipeVersion(p2, 3500);

          await createSaleHelper(
            date: todayStr,
            paymentMethod: 'cash',
            itemsData: [
              (
                productId: p1,
                recipeVersionId: r1,
                name: 'Es Teh Manis',
                qty: 5.0,
                price: 5000,
                hpp: 2000,
              ),
              (
                productId: p2,
                recipeVersionId: r2,
                name: 'Es Jeruk Segar',
                qty: 2.0,
                price: 8000,
                hpp: 3500,
              ),
            ],
          );
        });

        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        // Omzet = (5*5000) + (2*8000) = 25.000 + 16.000 = 41.000
        // HPP = (5*2000) + (2*3500) = 10.000 + 7.000 = 17.000
        // Laba = 41.000 - 17.000 = 24.000
        expect(find.text('Rp41.000'), findsWidgets); // di Omzet stat card
        expect(find.text('Rp17.000'), findsWidgets); // di HPP stat card
        expect(find.text('Rp24.000'), findsWidgets); // di Laba stat card
        expect(find.text('1 Transaksi • 7 Terjual'), findsOneWidget);

        // Produk Utama: Es Teh Manis terlaris (5 terjual), Es Teh Manis laba tertinggi (Rp15.000)
        expect(find.text('Performa Produk Utama'), findsOneWidget);
        expect(find.text('Produk Terlaris'), findsOneWidget);
        expect(find.text('Laba Tertinggi'), findsOneWidget);

        // Performa Per Produk list
        expect(find.text('Performa Produk'), findsOneWidget);
        expect(find.text('Es Teh Manis'), findsWidgets);
        expect(find.text('Es Jeruk Segar'), findsWidgets);
        expect(find.text('5 Terjual'), findsOneWidget);
        expect(find.text('2 Terjual'), findsOneWidget);

        // Metode Pembayaran
        expect(find.text('Metode Pembayaran'), findsOneWidget);
        expect(find.text('Tunai'), findsOneWidget);
        expect(find.text('(1 trx)'), findsOneWidget);
      },
    );

    testWidgets(
      'Laporan otomatis refresh saat SaleRepository.salesChangeNotifier dipicu',
      (tester) async {
        final todayStr = ReportDateHelper.formatDate(DateTime.now());

        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        // Awalnya empty
        expect(
          find.text('Belum ada transaksi pada periode ini.'),
          findsOneWidget,
        );

        // Tambahkan transaksi di background
        await tester.runAsync(() async {
          final p1 = await insertProduct('Es Cincau');
          final r1 = await insertRecipeVersion(p1, 1500);

          await createSaleHelper(
            date: todayStr,
            paymentMethod: 'qris',
            itemsData: [
              (
                productId: p1,
                recipeVersionId: r1,
                name: 'Es Cincau',
                qty: 4.0,
                price: 6000,
                hpp: 1500,
              ),
            ],
          );
        });

        // Tunggu notifier memicu re-render
        await settleAsync(tester);

        // Empty state harus hilang dan data baru muncul
        expect(
          find.text('Belum ada transaksi pada periode ini.'),
          findsNothing,
        );
        expect(find.text('Rp24.000'), findsWidgets); // Omzet 4 * 6000
        expect(find.text('Es Cincau'), findsWidgets);
      },
    );

    testWidgets('Render rapi pada tema Dark Mode tanpa layout overflow', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(themeMode: ThemeMode.dark));
      await settleAsync(tester);

      expect(find.text('Laporan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tombol Export PDF muncul pada AppBar ReportsScreen', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await settleAsync(tester);

      expect(find.byTooltip('Export PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets(
      'Ekspor PDF berhasil memanggil service dan menampilkan notifikasi sukses',
      (tester) async {
        final todayStr = ReportDateHelper.formatDate(DateTime.now());

        await tester.runAsync(() async {
          final p1 = await insertProduct('Es Kopi Susu');
          final r1 = await insertRecipeVersion(p1, 3000);
          await createSaleHelper(
            date: todayStr,
            paymentMethod: 'cash',
            itemsData: [
              (
                productId: p1,
                recipeVersionId: r1,
                name: 'Es Kopi Susu',
                qty: 2.0,
                price: 10000,
                hpp: 3000,
              ),
            ],
          );
        });

        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        // Tekan tombol Export PDF di AppBar
        await tester.tap(find.byTooltip('Export PDF'));
        await settleAsync(tester);

        // Notifikasi sukses muncul
        expect(
          find.textContaining('Laporan PDF berhasil dibuat'),
          findsOneWidget,
        );
        // File tersimpan di fakeStorage
        expect(fakeStorage.storedFiles.length, 1);
        // Share sheet terpanggil
        expect(fakeStorage.sharedFiles.length, 1);
      },
    );

    testWidgets(
      'Simulasi kendala ekspor memunculkan notifikasi error dengan opsi Coba Lagi',
      (tester) async {
        fakeStorage.simulateSaveError = true;

        await tester.pumpWidget(createTestWidget());
        await settleAsync(tester);

        await tester.tap(find.byTooltip('Export PDF'));
        await settleAsync(tester);

        expect(find.text('Gagal membuat laporan PDF.'), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
      },
    );

    testWidgets('Ekspor PDF pada tab Mingguan tetap berfungsi normal', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await settleAsync(tester);

      // Pindah ke tab Mingguan
      await tester.tap(find.text('Minggu'));
      await settleAsync(tester);

      // Ekspor PDF mingguan
      await tester.tap(find.byTooltip('Export PDF'));
      await settleAsync(tester);

      expect(
        find.textContaining('Laporan PDF berhasil dibuat'),
        findsOneWidget,
      );
      expect(fakeStorage.storedFiles.keys.first, contains('Mingguan'));
    });
  });
}
