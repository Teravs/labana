import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/constants/app_constants.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/core/theme/theme_controller.dart';
import 'package:labana/features/ingredients/data/ingredient_price_repository.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/data/processed_ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/products/data/product_price_repository.dart';
import 'package:labana/features/products/data/product_repository.dart';
import 'package:labana/features/products/data/recipe_item_repository.dart';
import 'package:labana/features/products/data/recipe_version_repository.dart';
import 'package:labana/features/products/models/product_price.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/models/recipe_version.dart';
import 'package:labana/features/sales/data/sale_repository.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/main.dart';
import 'package:labana/routes/app_routes.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database testDb;

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
    appThemeModeNotifier.value = ThemeMode.system;
    AppRouter.router.go(AppRoutes.home);
  });

  tearDown(() async {
    await testDb.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  /// Helper untuk menunggu operasi asynchronous SQLite dan animasi widget selesai.
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

  // ---------------------------------------------------------------------------
  // Test 1 & 2: App dapat dijalankan & Home tampil
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 1 & 2: App dapat dijalankan dan menampilkan Home dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      expect(
        find.text('Selamat datang di ${AppConstants.appName}'),
        findsOneWidget,
      );
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      expect(find.text('Omzet Hari Ini'), findsOneWidget);
      expect(find.text('Modal / HPP'), findsOneWidget);
      expect(find.text('Laba'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Rp0'), findsNWidgets(3));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0 produk terjual'), findsOneWidget);
      expect(find.text('Belum ada penjualan'), findsNWidgets(2));
      expect(find.text('Belum ada penjualan hari ini.'), findsOneWidget);

      expect(find.text('+ Penjualan'), findsOneWidget);
      expect(find.text('+ Bahan'), findsOneWidget);
      expect(find.text('+ Produk / Resep'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 3: Bottom navigation memiliki 5 menu
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 3: Bottom navigation memiliki Home, Bahan, Penjualan, Laporan, Pengaturan',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Bahan'), findsOneWidget);
      expect(find.text('Penjualan'), findsOneWidget);
      expect(find.text('Laporan'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 4: Bahan Mentah CRUD Flow (Tambah, Validasi, Tampil, Edit, Nonaktif, Aktifkan)
  // ---------------------------------------------------------------------------
  testWidgets('Test 4: Alur CRUD Bahan Mentah bekerja dengan benar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    // 1. Pindah ke halaman Bahan
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bahan'),
      ),
    );
    await settleAsync(tester);

    // Verifikasi empty state awal
    expect(find.text('Belum ada bahan mentah'), findsOneWidget);
    expect(find.text('Bahan Mentah'), findsWidgets);
    expect(find.text('Bahan Olahan'), findsOneWidget);

    // 2. Buka form tambah bahan
    await tester.tap(find.text('Tambah Bahan').first);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Bahan Mentah'), findsOneWidget);

    // 3. Uji validasi nama kosong
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama bahan wajib diisi.'), findsOneWidget);

    // 4. Masukkan nama valid "Gula Pasir" dan simpan
    await tester.enterText(find.byType(TextFormField), 'Gula Pasir');
    await tester.tap(find.text('Simpan'));
    await settleAsync(tester);

    // Verifikasi item muncul di daftar aktif
    expect(find.text('Gula Pasir'), findsOneWidget);
    expect(find.text('Bahan berhasil ditambahkan.'), findsOneWidget);

    // Biarkan SnackBar menghilang agar tidak menghalangi tombol
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 5. Uji Edit Bahan
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Bahan Mentah'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Gula Pasir Premium');
    await tester.tap(find.text('Simpan Perubahan'));
    await settleAsync(tester);

    expect(find.text('Gula Pasir Premium'), findsOneWidget);
    expect(find.text('Bahan berhasil diperbarui.'), findsOneWidget);

    // Biarkan SnackBar menghilang
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 6. Uji Nonaktifkan Bahan (dengan konfirmasi)
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();

    expect(find.text('Nonaktifkan bahan?'), findsOneWidget);

    // Konfirmasi nonaktifkan
    await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
    await settleAsync(tester);

    expect(find.text('Bahan dinonaktifkan.'), findsOneWidget);
    expect(find.text('Belum ada bahan mentah'), findsOneWidget);

    // Biarkan SnackBar hilang
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 7. Lihat di tab Nonaktif dan aktifkan kembali
    await tester.tap(find.text('Nonaktif'));
    await settleAsync(tester);

    expect(find.text('Gula Pasir Premium'), findsOneWidget);
    expect(find.text('Aktifkan Kembali'), findsOneWidget);

    await tester.tap(find.text('Aktifkan Kembali'));
    await settleAsync(tester);

    expect(find.text('Bahan berhasil diaktifkan kembali.'), findsOneWidget);
    expect(find.text('Tidak ada bahan nonaktif'), findsOneWidget);

    // Biarkan SnackBar hilang
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Kembali ke tab Aktif
    await tester.tap(find.text('Aktif'));
    await settleAsync(tester);
    expect(find.text('Gula Pasir Premium'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Test 5: User dapat berpindah ke halaman Penjualan
  // ---------------------------------------------------------------------------
  testWidgets('Test 5: User dapat berpindah ke halaman Penjualan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await settleAsync(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Penjualan'),
      ),
    );
    await settleAsync(tester);

    expect(find.text('Belum ada transaksi.'), findsOneWidget);
    expect(
      find.text('Transaksi penjualan yang kamu buat akan muncul di sini.'),
      findsOneWidget,
    );
  });

  // ---------------------------------------------------------------------------
  // Test 6: User dapat berpindah ke halaman Laporan
  // ---------------------------------------------------------------------------
  testWidgets('Test 6: User dapat berpindah ke halaman Laporan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await settleAsync(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Laporan'),
      ),
    );
    await settleAsync(tester);

    expect(find.text('Hari'), findsOneWidget);
    expect(find.text('Minggu'), findsOneWidget);
    expect(find.text('Bulan'), findsOneWidget);
    expect(find.text('Belum ada transaksi pada periode ini.'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Test 7: User dapat berpindah ke halaman Pengaturan
  // ---------------------------------------------------------------------------
  testWidgets('Test 7: User dapat berpindah ke halaman Pengaturan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Pengaturan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Mode Tampilan'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Backup Data'), findsOneWidget);
    expect(find.text('Restore Data'), findsOneWidget);
    expect(find.text('Retensi Data'), findsOneWidget);
    expect(find.text('Versi ${AppConstants.appVersion}'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Test 8: Theme switching tidak menyebabkan error
  // ---------------------------------------------------------------------------
  testWidgets('Test 8: Theme switching di Pengaturan tidak menyebabkan error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Pengaturan'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.dark);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.light);

    await tester.tap(find.text('Sistem'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.system);
  });

  // ---------------------------------------------------------------------------
  // Test 9: Navigasi ke Detail Bahan Mentah dan Tampilan Empty State Harga
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 9: Navigasi ke Detail Bahan Mentah menampilkan empty state harga',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      // Pindah ke tab Bahan
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bahan'),
        ),
      );
      await settleAsync(tester);

      // Tambah Bahan Mentah 'Kopi Bubuk'
      await tester.tap(find.text('Tambah Bahan').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Kopi Bubuk');
      await tester.tap(find.text('Simpan'));
      await settleAsync(tester);

      expect(find.text('Kopi Bubuk'), findsOneWidget);

      // Tap card bahan untuk membuka detail
      await tester.tap(find.text('Kopi Bubuk'));
      await settleAsync(tester);

      expect(find.text('Harga Saat Ini'), findsOneWidget);
      expect(find.text('Belum ada harga'), findsOneWidget);
      expect(find.text('Tambah Harga'), findsWidgets);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 10: Form Tambah Harga, Satuan Pack & Riwayat Harga
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 10: Form Tambah Harga, conditional Isi per Pack, dan riwayat harga',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      // Pindah ke tab Bahan
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bahan'),
        ),
      );
      await settleAsync(tester);

      // Tambah Bahan 'Sedotan Plastik'
      await tester.tap(find.text('Tambah Bahan').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Sedotan Plastik');
      await tester.tap(find.text('Simpan'));
      await settleAsync(tester);

      // Buka detail Sedotan Plastik
      await tester.tap(find.text('Sedotan Plastik'));
      await settleAsync(tester);

      // Buka form tambah harga
      await tester.tap(find.text('Tambah Harga').first);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Harga Pembelian'), findsOneWidget);
      expect(find.text('Isi per Pack'), findsNothing);

      // Pilih unit Pack dari dropdown
      await tester.tap(find.text('Kilogram (kg)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pack').last);
      await tester.pumpAndSettle();

      // Field Isi per Pack sekarang muncul
      expect(find.text('Isi per Pack'), findsOneWidget);

      // Isi data form: 1 pack, isi 50 pcs, harga 10000
      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(0), '1');
      await tester.enterText(formFields.at(1), '50');
      await tester.enterText(formFields.at(2), '10000');
      await tester.pump();

      // Simpan harga
      await tester.ensureVisible(find.text('Simpan'));
      await tester.tap(find.text('Simpan'));
      await settleAsync(tester);

      // Verifikasi harga tersimpan di halaman detail
      expect(find.text('1 pack (50 pcs)'), findsWidgets);
      expect(find.text('Rp10.000'), findsWidgets);
      expect(find.text('Rp200/pcs'), findsWidgets);
      expect(find.text('Default'), findsWidgets);
      expect(find.text('Riwayat Harga'), findsOneWidget);

      // Kembali ke halaman daftar bahan
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      // Verifikasi di card bahan mentah terdapat ringkasan harga
      expect(find.text('Sedotan Plastik'), findsOneWidget);
      expect(find.text('Rp10.000 / 1 pack (50 pcs)'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 11: Tab Bahan Olahan — Empty State & Sub-filter Status
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 11: Tab Bahan Olahan menampilkan empty state dan toggle filter status',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      // Pindah ke tab Bahan
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bahan'),
        ),
      );
      await settleAsync(tester);

      // Pindah ke sub-tab 'Bahan Olahan'
      await tester.tap(find.text('Bahan Olahan'));
      await settleAsync(tester);

      // Verifikasi empty state Bahan Olahan
      expect(find.text('Belum ada bahan olahan'), findsOneWidget);
      expect(
        find.text(
          'Tambahkan bahan olahan seperti sirup, racikan susu, atau saus yang dibuat sendiri.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tambah Bahan Olahan'), findsWidgets);

      // Ganti filter ke Nonaktif
      await tester.tap(find.text('Nonaktif'));
      await settleAsync(tester);

      expect(find.text('Tidak ada bahan olahan nonaktif'), findsOneWidget);

      // Kembali ke filter Aktif
      await tester.tap(find.text('Aktif'));
      await settleAsync(tester);
      expect(find.text('Belum ada bahan olahan'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 12: Bahan Olahan CRUD Flow — Tambah, Komponen, Kalkulasi, Detail, Nonaktif
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 12: Bahan Olahan CRUD Flow dengan live preview modal dan detail resep',
    (WidgetTester tester) async {
      debugPrint('[Test 12] Langkah 1: Setup data awal');
      await tester.runAsync(() async {
        final ingRepo = IngredientRepository();
        final priceRepo = IngredientPriceRepository();
        final gula = await ingRepo.create('Gula Pasir');
        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1,
          purchaseUnit: 'kg',
          price: 15000,
          effectiveFrom: '2026-01-01',
          isDefault: true,
        );
      });

      debugPrint('[Test 12] Langkah 2: Pump widget LabanaApp');
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      debugPrint('[Test 12] Langkah 3: Navigasi ke tab Bahan -> Bahan Olahan');
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bahan'),
        ),
      );
      await settleAsync(tester);

      await tester.tap(find.text('Bahan Olahan'));
      await settleAsync(tester);

      debugPrint('[Test 12] Langkah 4: Buka modal Tambah Bahan Olahan');
      await tester.tap(find.text('Tambah Bahan Olahan').first);
      await settleAsync(tester);

      debugPrint('[Test 12] Langkah 5: Mengisi nama dan hasil jadi');
      final nameField = find.ancestor(
        of: find.text('Nama bahan olahan'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(nameField, 'Simple Syrup');

      final resultField = find.ancestor(
        of: find.text('Jumlah hasil jadi'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(resultField, '750');

      debugPrint('[Test 12] Langkah 6: Mengisi jumlah komponen 1 (Gula Pasir)');
      final qtyField = find.ancestor(
        of: find.text('Jumlah'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(qtyField, '500');
      await tester.pump();

      debugPrint('[Test 12] Langkah 7: Menambah komponen 2 (Biaya Lainnya)');
      await tester.ensureVisible(find.text('Biaya Lainnya'));
      await tester.tap(find.text('Biaya Lainnya'));
      await tester.pumpAndSettle();

      debugPrint('[Test 12] Langkah 8: Mengisi nominal biaya lainnya');
      final otherCostField = find.ancestor(
        of: find.text('Nominal Biaya (Rp)'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(otherCostField);
      await tester.enterText(otherCostField, '1000');
      await tester.pump();

      debugPrint('[Test 12] Langkah 9: Verifikasi live preview modal');
      expect(find.text('Estimasi Modal Olahan'), findsOneWidget);
      expect(find.text('Rp8.500'), findsOneWidget);
      expect(find.text('Rp11,33/ml'), findsOneWidget);

      debugPrint('[Test 12] Langkah 10: Simpan form');
      await tester.ensureVisible(find.text('Simpan Bahan Olahan'));
      await tester.tap(find.text('Simpan Bahan Olahan'));
      await settleAsync(tester);
      await settleAsync(tester);

      debugPrint('[Test 12] Langkah 11: Verifikasi card di daftar');
      expect(find.text('Simple Syrup'), findsOneWidget);
      expect(find.text('Hasil: 750 ml • 2 komponen'), findsOneWidget);
      expect(find.text('Rp8.500 (Rp11,33/ml)'), findsOneWidget);

      debugPrint('[Test 12] Langkah 12: Buka detail bahan olahan');
      await tester.tap(find.text('Simple Syrup'));
      await settleAsync(tester);

      debugPrint('[Test 12] Langkah 13: Verifikasi isi detail');
      expect(find.text('Hasil Jadi: 750 ml'), findsOneWidget);
      expect(find.text('Ringkasan Modal Olahan'), findsOneWidget);
      expect(find.text('Total Modal Resep:'), findsOneWidget);
      expect(find.text('Rp8.500'), findsWidgets);
      expect(find.text('Modal per Satuan Hasil:'), findsOneWidget);
      expect(find.text('Rp11,33/ml'), findsWidgets);

      expect(find.text('Komposisi Komponen'), findsOneWidget);
      expect(find.text('Gula Pasir'), findsOneWidget);
      expect(find.text('Penggunaan: 500 g'), findsOneWidget);
      expect(find.text('Rp7.500'), findsOneWidget);
      expect(find.text('Biaya Lainnya / Pelengkap'), findsOneWidget);
      expect(find.text('Rp1.000'), findsOneWidget);

      debugPrint('[Test 12] Langkah 14: Nonaktifkan');
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nonaktifkan'));
      await tester.pumpAndSettle();

      expect(find.text('Nonaktifkan bahan olahan?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await settleAsync(tester);

      debugPrint('[Test 12] Langkah 15: Kembali ke daftar');
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      expect(find.text('Belum ada bahan olahan'), findsOneWidget);

      debugPrint('[Test 12] Langkah 16: Tab Nonaktif & reaktivasi');
      await tester.tap(find.text('Nonaktif'));
      await settleAsync(tester);

      expect(find.text('Simple Syrup'), findsOneWidget);
      expect(find.text('Aktifkan Kembali'), findsOneWidget);

      await tester.tap(find.text('Aktifkan Kembali'));
      await settleAsync(tester);

      expect(find.text('Tidak ada bahan olahan nonaktif'), findsOneWidget);

      await tester.tap(find.text('Aktif'));
      await settleAsync(tester);
      expect(find.text('Simple Syrup'), findsOneWidget);
      debugPrint('[Test 12] SELESAI');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 13: Tahap 7 — Nested Bahan Olahan & Circular Dependency Prevention
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 13: Nested Bahan Olahan, live cost preview, detail resep, dan circular dependency check',
    (WidgetTester tester) async {
      debugPrint(
        '[Test 13] Langkah 1: Setup data awal (Bahan Mentah Gula Pasir)',
      );
      final ingRepo = IngredientRepository();
      final priceRepo = IngredientPriceRepository();
      final procRepo = ProcessedIngredientRepository();

      late final int syrupId;
      await tester.runAsync(() async {
        final gula = await ingRepo.create('Gula Pasir');
        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1,
          purchaseUnit: 'kg',
          price: 15000,
          effectiveFrom: '2026-01-01',
          isDefault: true,
        );

        debugPrint(
          '[Test 13] Langkah 2: Buat child bahan olahan: Simple Syrup',
        );
        final syrup = await procRepo.create(
          name: 'Simple Syrup',
          resultQuantity: 750,
          resultUnit: 'ml',
          components: [
            const ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: 1, // gula
              quantity: 500,
              unit: 'g',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 1000,
              label: 'Air',
            ),
          ],
        );
        syrupId = syrup.id!;
      });

      debugPrint(
        '[Test 13] Langkah 3: Buka aplikasi & navigasi ke tab Bahan Olahan',
      );
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Bahan'),
        ),
      );
      await settleAsync(tester);

      await tester.tap(find.text('Bahan Olahan'));
      await settleAsync(tester);

      expect(find.text('Simple Syrup'), findsOneWidget);

      debugPrint(
        '[Test 13] Langkah 4: Buka modal Tambah Bahan Olahan untuk membuat Teh Manis Base',
      );
      await tester.tap(find.text('Tambah Bahan Olahan').first);
      await settleAsync(tester);

      debugPrint('[Test 13] Langkah 5: Isi nama dan hasil jadi');
      final nameField = find.ancestor(
        of: find.text('Nama bahan olahan'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(nameField, 'Teh Manis Base');

      final resultField = find.ancestor(
        of: find.text('Jumlah hasil jadi'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(resultField, '1000');

      debugPrint('[Test 13] Langkah 6: Tambah komponen Bahan Olahan');
      final addProcessedBtn = find.widgetWithText(
        OutlinedButton,
        'Bahan Olahan',
      );
      await tester.ensureVisible(addProcessedBtn);
      await tester.tap(addProcessedBtn);
      await tester.pumpAndSettle();

      // Sekarang ada 2 komponen, hapus komponen pertama (Bahan Mentah default)
      await tester.tap(find.byTooltip('Hapus komponen').first);
      await tester.pumpAndSettle();

      debugPrint(
        '[Test 13] Langkah 7: Isi jumlah penggunaan Simple Syrup (100 ml)',
      );
      final qtyField = find.ancestor(
        of: find.text('Jumlah'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(qtyField, '100');
      await tester.pump();

      debugPrint(
        '[Test 13] Langkah 8: Tambah komponen Biaya Lainnya (Kantong Teh)',
      );
      final addOtherBtn = find.widgetWithText(OutlinedButton, 'Biaya Lainnya');
      await tester.ensureVisible(addOtherBtn);
      await tester.tap(addOtherBtn);
      await tester.pumpAndSettle();

      final otherCostField = find.ancestor(
        of: find.text('Nominal Biaya (Rp)'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(otherCostField);
      await tester.enterText(otherCostField, '1500');

      final labelField = find.ancestor(
        of: find.text('Keterangan (Opsional)'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(labelField, 'Kantong Teh');
      await tester.pump();

      debugPrint('[Test 13] Langkah 9: Verifikasi live preview modal');
      // Simple Syrup modal: 8500 / 750 * 100 = 1133.33 + 1500 = 2633.33 (Rp2.633)
      // Per unit: 2633.33 / 1000 = 2.63 (Rp2,63/ml)
      expect(find.text('Estimasi Modal Olahan'), findsOneWidget);
      expect(find.text('Rp2.633'), findsOneWidget);
      expect(find.text('Rp2,63/ml'), findsOneWidget);

      debugPrint('[Test 13] Langkah 10: Simpan form');
      await tester.ensureVisible(find.text('Simpan Bahan Olahan'));
      await tester.tap(find.text('Simpan Bahan Olahan'));
      await settleAsync(tester);
      await settleAsync(tester);

      debugPrint(
        '[Test 13] Langkah 11: Verifikasi card Teh Manis Base di daftar',
      );
      expect(find.text('Teh Manis Base'), findsOneWidget);
      expect(find.text('Hasil: 1.000 ml • 2 komponen'), findsOneWidget);
      expect(find.text('Rp2.633 (Rp2,63/ml)'), findsOneWidget);

      debugPrint('[Test 13] Langkah 12: Buka detail Teh Manis Base');
      await tester.tap(find.text('Teh Manis Base'));
      await settleAsync(tester);

      debugPrint('[Test 13] Langkah 13: Verifikasi isi detail Teh Manis Base');
      expect(find.text('Hasil Jadi: 1.000 ml'), findsOneWidget);
      expect(find.text('Ringkasan Modal Olahan'), findsOneWidget);
      expect(find.text('Total Modal Resep:'), findsOneWidget);
      expect(find.text('Rp2.633'), findsWidgets);
      expect(find.text('Modal per Satuan Hasil:'), findsOneWidget);
      expect(find.text('Rp2,63/ml'), findsWidgets);

      expect(find.text('Komposisi Komponen'), findsOneWidget);
      expect(find.text('Simple Syrup'), findsOneWidget);
      expect(find.text('Bahan Olahan • Penggunaan: 100 ml'), findsOneWidget);
      expect(find.text('Rp1.133'), findsOneWidget);
      expect(find.text('Biaya Lainnya / Pelengkap'), findsOneWidget);
      expect(find.text('Rp1.500'), findsOneWidget);

      debugPrint('[Test 13] Langkah 14: Kembali ke daftar');
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      debugPrint(
        '[Test 13] Langkah 15: Validasi circular dependency prevention pada Simple Syrup',
      );
      await tester.runAsync(() async {
        final candidatesForSyrup = await procRepo.getValidChildCandidates(
          currentProcessedId: syrupId,
        );
        final candidateNames = candidatesForSyrup.map((c) => c.name).toList();
        expect(candidateNames, isNot(contains('Teh Manis Base')));
        expect(candidateNames, isNot(contains('Simple Syrup')));

        debugPrint(
          '[Test 13] Langkah 16: Verifikasi delete rejection jika masih digunakan sebagai child',
        );
        expect(
          () => procRepo.delete(syrupId),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('masih digunakan oleh bahan olahan lain'),
            ),
          ),
        );
      });

      debugPrint('[Test 13] SELESAI');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 14: End-to-End Product + Recipe Flow
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 14: End-to-End Product + Recipe Flow (Create, Live Preview, Selling Price, Detail, Deactivate, Reactivate)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugPrint(
        '[Test 14] Langkah 1: Setup master data (Bahan Mentah & Bahan Olahan)',
      );
      final ingRepo = IngredientRepository();
      final priceRepo = IngredientPriceRepository();
      final procRepo = ProcessedIngredientRepository();

      await tester.runAsync(() async {
        // Gula Pasir: 1 kg = Rp15.000 (Rp15/g)
        final gula = await ingRepo.create('Gula Pasir');
        await priceRepo.createPrice(
          ingredientId: gula.id!,
          purchaseQuantity: 1,
          purchaseUnit: 'kg',
          price: 15000,
          effectiveFrom: '2026-01-01',
          isDefault: true,
        );

        // Teh Melati: 100 g = Rp10.000 (Rp100/g)
        final teh = await ingRepo.create('Teh Melati');
        await priceRepo.createPrice(
          ingredientId: teh.id!,
          purchaseQuantity: 100,
          purchaseUnit: 'g',
          price: 10000,
          effectiveFrom: '2026-01-01',
          isDefault: true,
        );

        // Simple Syrup: 500g Gula (7500) + Air (1000) = Rp8.500 / 750 ml = Rp11,33/ml
        await procRepo.create(
          name: 'Simple Syrup',
          resultQuantity: 750,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id!,
              quantity: 500,
              unit: 'g',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 1000,
              label: 'Air',
            ),
          ],
        );
      });

      debugPrint(
        '[Test 14] Langkah 2: Buka aplikasi & navigasi via tombol + Produk / Resep di Home',
      );
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      expect(find.text('+ Produk / Resep'), findsOneWidget);
      await tester.tap(find.text('+ Produk / Resep'));
      await settleAsync(tester);

      debugPrint('[Test 14] Langkah 3: Verifikasi halaman Produk & Resep');
      expect(find.text('Produk & Resep'), findsOneWidget);
      expect(find.text('Belum Ada Produk'), findsOneWidget);

      debugPrint(
        '[Test 14] Langkah 4: Buka form Tambah Produk & Resep via FAB',
      );
      await tester.tap(find.byType(FloatingActionButton));
      await settleAsync(tester);

      expect(find.text('Tambah Produk Baru'), findsOneWidget);

      debugPrint('[Test 14] Langkah 5: Isi Nama Produk');
      final nameField = find.ancestor(
        of: find.text('Nama Produk'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(nameField, 'Es Teh Manis');

      debugPrint(
        '[Test 14] Langkah 6: Atur komponen bahan mentah (Teh Melati 5g = Rp500)',
      );
      final ingDropdown = find.byType(DropdownButtonFormField<int>).first;
      await tester.ensureVisible(ingDropdown);
      await tester.tap(ingDropdown);
      await settleAsync(tester);
      await tester.tap(find.text('Teh Melati').last);
      await settleAsync(tester);

      final qtyFields = find.ancestor(
        of: find.text('Jumlah Pemakaian'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(qtyFields.first, '5');
      await tester.pump();

      debugPrint(
        '[Test 14] Langkah 7: Tambah komponen Bahan Olahan (Simple Syrup 30 ml = Rp340)',
      );
      final addProcessedBtn = find.widgetWithText(
        OutlinedButton,
        'Bahan Olahan',
      );
      await tester.ensureVisible(addProcessedBtn);
      await tester.tap(addProcessedBtn);
      await settleAsync(tester);

      final qtyFieldsAfterProc = find.ancestor(
        of: find.text('Jumlah Pemakaian'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(qtyFieldsAfterProc.last, '30');
      await tester.pump();

      debugPrint(
        '[Test 14] Langkah 8: Tambah komponen Biaya Lainnya (Cup Rp500)',
      );
      final addOtherBtn = find.widgetWithText(OutlinedButton, 'Biaya Lainnya');
      await tester.ensureVisible(addOtherBtn);
      await tester.tap(addOtherBtn);
      await settleAsync(tester);

      final otherCostField = find.ancestor(
        of: find.text('Nominal Biaya (Rp)'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(otherCostField);
      await tester.enterText(otherCostField, '500');

      final labelField = find.ancestor(
        of: find.text('Keterangan (Opsional)'),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(labelField, 'Cup & Sedotan');
      await tester.pump();

      debugPrint(
        '[Test 14] Langkah 9: Verifikasi live HPP preview (500 + 340 + 500 = Rp1.340)',
      );
      expect(find.text('Estimasi HPP Resep'), findsOneWidget);
      expect(find.text('Rp1.340'), findsOneWidget);

      debugPrint(
        '[Test 14] Langkah 10: Isi Harga Jual Rp5.000 & verifikasi preview laba',
      );
      final priceField = find.ancestor(
        of: find.text('Harga Jual (Rp)'),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(priceField);
      await tester.enterText(priceField, '5000');
      await tester.pump();

      expect(find.text('Estimasi Laba per Porsi'), findsOneWidget);
      expect(find.text('Rp3.660'), findsOneWidget);

      debugPrint('[Test 14] Langkah 11: Simpan produk');
      final submitBtn = find.widgetWithText(FilledButton, 'Simpan Produk');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await settleAsync(tester);
      await settleAsync(tester);

      debugPrint(
        '[Test 14] Langkah 12: Verifikasi produk di daftar (ProductsScreen)',
      );
      expect(find.text('Es Teh Manis'), findsOneWidget);
      expect(find.text('v1'), findsOneWidget);
      expect(find.text('Rp5.000'), findsOneWidget);
      expect(find.text('• HPP: Rp1.340'), findsOneWidget);
      expect(find.text('Laba: Rp3.660'), findsOneWidget);

      debugPrint('[Test 14] Langkah 13: Buka detail produk');
      await tester.tap(find.text('Es Teh Manis'));
      await settleAsync(tester);

      debugPrint('[Test 14] Langkah 14: Verifikasi isi ProductDetailScreen');
      expect(find.text('Produk Aktif'), findsOneWidget);
      expect(find.text('Resep v1'), findsWidgets);
      expect(find.text('Rp5.000'), findsWidgets);
      expect(find.text('Rp1.340'), findsWidgets);
      expect(find.text('Rp3.660'), findsWidgets);

      debugPrint(
        '[Test 14] Langkah 15: Soft deactivate via PopupMenu di detail screen',
      );
      final popupBtn = find.byType(PopupMenuButton<String>);
      await tester.tap(popupBtn);
      await settleAsync(tester);

      await tester.tap(find.text('Nonaktifkan'));
      await settleAsync(tester);

      final confirmDeactBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Nonaktifkan'),
      );
      await tester.tap(confirmDeactBtn);
      await settleAsync(tester);

      expect(find.text('Produk Nonaktif'), findsOneWidget);

      debugPrint(
        '[Test 14] Langkah 16: Reactivate produk via tombol Aktifkan di AppBar',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Aktifkan'));
      await settleAsync(tester);

      expect(find.text('Produk Aktif'), findsOneWidget);

      debugPrint('[Test 14] Langkah 17: Kembali ke halaman ProductsScreen');
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      expect(find.text('Es Teh Manis'), findsOneWidget);
      debugPrint('[Test 14] SELESAI');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 15: End-to-End Sales Flow (Create, Multi-Product, Historical Snapshot, Edit, Delete)
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 15: End-to-End Sales Flow (Create, Multi-Product, Historical Snapshot, Edit, Delete)',
    (WidgetTester tester) async {
      debugPrint('[Test 15] Langkah 1: Setup master data produk & resep');
      final ingRepo = IngredientRepository();
      final priceRepo = IngredientPriceRepository();
      final prodRepo = ProductRepository();
      final recipeVersionRepo = RecipeVersionRepository();
      final recipeItemRepo = RecipeItemRepository();
      final prodPriceRepo = ProductPriceRepository();

      await tester.runAsync(() async {
        // Teh Melati
        final teh = await ingRepo.create('Teh Melati');
        await priceRepo.createPrice(
          ingredientId: teh.id!,
          purchaseQuantity: 100,
          purchaseUnit: 'g',
          price: 10000,
          effectiveFrom: '2026-09-01',
          isDefault: true,
        );

        // Produk 1: Es Teh Manis (HPP 1000, Harga Jual 5000)
        final tehManis = await prodRepo.create('Es Teh Manis');
        final v1 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: tehManis.id!,
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
          RecipeItem(
            recipeVersionId: v1.id!,
            componentType: RecipeItem.typeOther,
            otherCost: 500,
            label: 'Cup',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        ]);
        await prodPriceRepo.create(
          ProductPrice(
            productId: tehManis.id!,
            sellingPrice: 5000,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        // Produk 2: Es Jeruk (HPP 1500, Harga Jual 6000)
        final jeruk = await prodRepo.create('Es Jeruk Segar');
        final v2 = await recipeVersionRepo.create(
          RecipeVersion(
            productId: jeruk.id!,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            hppTotal: 1500,
            status: 'active',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await recipeItemRepo.create(
          RecipeItem(
            recipeVersionId: v2.id!,
            componentType: RecipeItem.typeOther,
            otherCost: 1500,
            label: 'Jeruk & Cup',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await prodPriceRepo.create(
          ProductPrice(
            productId: jeruk.id!,
            sellingPrice: 6000,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
      });

      debugPrint(
        '[Test 15] Langkah 2: Buka aplikasi & navigasi ke tab Penjualan',
      );
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Penjualan'),
        ),
      );
      await settleAsync(tester);

      debugPrint('[Test 15] Langkah 3: Verifikasi empty state awal');
      expect(find.text('Belum ada transaksi.'), findsOneWidget);

      debugPrint('[Test 15] Langkah 4: Buka form Tambah Penjualan');
      await tester.tap(find.text('+ Tambah Penjualan'));
      await settleAsync(tester);

      expect(find.text('Tambah Penjualan'), findsOneWidget);

      debugPrint(
        '[Test 15] Langkah 5: Buka ProductPickerSheet & pilih Es Teh Manis',
      );
      await tester.ensureVisible(find.text('Tambah Produk'));
      await tester.tap(find.text('Tambah Produk'));
      await settleAsync(tester);

      expect(find.text('Pilih Produk'), findsOneWidget);
      for (int i = 0; i < 30; i++) {
        if (find.text('Es Teh Manis').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
      }
      expect(find.text('Es Teh Manis'), findsWidgets);
      await tester.tap(find.text('Es Teh Manis').first);
      await settleAsync(tester);

      expect(find.text('Es Teh Manis'), findsOneWidget);

      debugPrint(
        '[Test 15] Langkah 6: Tambah kuantitas Es Teh Manis menjadi 2',
      );
      await tester.tap(find.byIcon(Icons.add_rounded).last);
      await settleAsync(tester);

      debugPrint('[Test 15] Langkah 7: Tambah produk kedua (Es Jeruk Segar)');
      await tester.ensureVisible(find.text('Tambah Produk'));
      await tester.tap(find.text('Tambah Produk'));
      await settleAsync(tester);

      expect(find.text('Pilih Produk'), findsOneWidget);
      for (int i = 0; i < 30; i++) {
        if (find.text('Es Jeruk Segar').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
      }
      expect(find.text('Es Jeruk Segar'), findsWidgets);
      await tester.tap(find.text('Es Jeruk Segar').first);
      await settleAsync(tester);

      debugPrint(
        '[Test 15] Langkah 8: Verifikasi Live Summary (Omzet 16.000, HPP 3.500, Laba 12.500)',
      );
      expect(find.text('Rp16.000'), findsWidgets);
      expect(find.text('Rp3.500'), findsWidgets);
      expect(find.text('Rp12.500'), findsWidgets);

      debugPrint('[Test 15] Langkah 9: Simpan transaksi penjualan');
      await tester.ensureVisible(find.text('Simpan Penjualan'));
      await tester.tap(find.text('Simpan Penjualan'));
      await settleAsync(tester);

      debugPrint(
        '[Test 15] Langkah 10: Verifikasi kartu transaksi muncul di daftar',
      );
      expect(find.text('Penjualan'), findsWidgets);
      expect(find.text('Rp16.000'), findsOneWidget);
      expect(find.text('Laba Rp12.500'), findsOneWidget);
      expect(find.text('2 produk'), findsOneWidget);

      debugPrint('[Test 15] Langkah 11: Buka Detail Transaksi');
      await tester.tap(find.text('Rp16.000'));
      await settleAsync(tester);

      expect(find.text('Detail Penjualan'), findsOneWidget);
      expect(find.text('Rincian Produk (2)'), findsOneWidget);

      debugPrint('[Test 15] Langkah 12: Buka Edit Transaksi');
      await tester.tap(find.byTooltip('Edit Transaksi'));
      await settleAsync(tester);

      expect(find.text('Edit Penjualan'), findsOneWidget);

      debugPrint('[Test 15] Langkah 13: Simpan perubahan');
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      for (int i = 0; i < 30; i++) {
        if (find.text('Simpan Perubahan').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
      }
      final simpanBtn = find.widgetWithText(FilledButton, 'Simpan Perubahan');
      await tester.ensureVisible(simpanBtn);
      await tester.tap(simpanBtn);
      await settleAsync(tester);

      expect(find.text('Detail Penjualan'), findsOneWidget);

      debugPrint(
        '[Test 15] Langkah 14: Hapus Transaksi dengan konfirmasi dialog',
      );
      await tester.tap(find.byTooltip('Hapus Transaksi'));
      await settleAsync(tester);

      expect(find.text('Hapus Penjualan?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Hapus'),
        ),
      );
      await settleAsync(tester);

      debugPrint(
        '[Test 15] Langkah 15: Verifikasi transaksi terhapus dan kembali ke empty state',
      );
      expect(find.text('Belum ada transaksi.'), findsOneWidget);
      debugPrint('[Test 15] SELESAI');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 16: End-to-End Home Dashboard Real Data & Quick Actions Flow
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 16: End-to-End Home Dashboard Real Data, Ringkasan, Performa, dan Quick Actions',
    (WidgetTester tester) async {
      debugPrint(
        '[Test 16] Langkah 1: Setup master data dan transaksi hari ini',
      );
      final prodRepo = ProductRepository();
      final recipeVersionRepo = RecipeVersionRepository();
      final prodPriceRepo = ProductPriceRepository();
      final saleRepo = SaleRepository();

      late final int p1Id;
      final todayStr = SaleRepository.formatLocalDate(DateTime.now());

      await tester.runAsync(() async {
        final teh = await prodRepo.create('Es Teh Kampul');
        p1Id = teh.id!;
        await recipeVersionRepo.create(
          RecipeVersion(
            productId: p1Id,
            versionNumber: 1,
            effectiveFrom: '2026-09-01',
            hppTotal: 1500,
            status: 'active',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );
        await prodPriceRepo.create(
          ProductPrice(
            productId: p1Id,
            sellingPrice: 5000,
            effectiveFrom: '2026-09-01',
            createdAt: '2026-09-01T00:00:00Z',
          ),
        );

        // Buat 1 transaksi penjualan hari ini: Es Teh Kampul x 3 (omzet 15.000, hpp 4.500, laba 10.500)
        await saleRepo.createSaleWithItems(
          sale: Sale(
            transactionNumber: 'TRX-$todayStr-001',
            transactionDate: '$todayStr 11:30:00',
            totalAmount: 15000,
            totalHpp: 4500,
            totalProfit: 10500,
            createdAt: '$todayStr 11:30:00',
            updatedAt: '$todayStr 11:30:00',
          ),
          items: [
            SaleItem(
              productId: p1Id,
              recipeVersionId: 1,
              productName: 'Es Teh Kampul',
              quantity: 3.0,
              sellingPrice: 5000,
              hppPerUnit: 1500,
              subtotal: 15000,
              totalHpp: 4500,
              totalProfit: 10500,
              createdAt: '$todayStr 11:30:00',
            ),
          ],
        );
      });

      debugPrint('[Test 16] Langkah 2: Buka aplikasi & verifikasi dashboard');
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      // Verifikasi metrik finansial riil
      expect(find.text('Rp15.000'), findsOneWidget);
      expect(find.text('Rp4.500'), findsOneWidget);
      expect(find.text('Rp10.500'), findsWidgets);
      expect(find.text('1'), findsOneWidget); // 1 transaksi
      expect(find.text('3 produk terjual'), findsOneWidget);

      // Verifikasi insight produk terlaris & laba tertinggi
      expect(find.text('Es Teh Kampul'), findsWidgets);
      expect(find.text('3 terjual'), findsOneWidget);

      debugPrint('[Test 16] Langkah 3: Uji Quick Action + Penjualan');
      await tester.ensureVisible(find.text('+ Penjualan'));
      await tester.tap(find.text('+ Penjualan'));
      await settleAsync(tester);

      expect(find.text('Tambah Penjualan'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      debugPrint('[Test 16] Langkah 4: Uji Quick Action + Bahan');
      await tester.ensureVisible(find.text('+ Bahan'));
      await tester.tap(find.text('+ Bahan'));
      await settleAsync(tester);

      expect(find.text('Bahan Mentah'), findsWidgets);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
      );
      await settleAsync(tester);

      debugPrint('[Test 16] Langkah 5: Uji Quick Action + Produk / Resep');
      await tester.ensureVisible(find.text('+ Produk / Resep'));
      await tester.tap(find.text('+ Produk / Resep'));
      await settleAsync(tester);

      expect(find.text('Produk & Resep'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settleAsync(tester);

      debugPrint('[Test 16] SELESAI');
    },
  );

  // ---------------------------------------------------------------------------
  // Test 17: End-to-End Reports Flow (Periods, Real Data, Breakdown, and Navigation)
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 17: End-to-End Reports Flow (Periods, Real Data, Breakdown, and Navigation)',
    (WidgetTester tester) async {
      debugPrint(
        '[Test 17] Langkah 1: Setup master data dan transaksi hari ini',
      );
      final todayStr = SaleRepository.formatLocalDate(DateTime.now());

      await tester.runAsync(() async {
        final p1 = await testDb.insert(TableNames.products, {
          'name': 'Es Kopi Aren',
          'status': 'active',
          'created_at': '2026-09-01 08:00:00',
          'updated_at': '2026-09-01 08:00:00',
        });
        final r1 = await testDb.insert(TableNames.recipeVersions, {
          'product_id': p1,
          'version_number': 1,
          'effective_from': '2026-09-01',
          'hpp_total': 6000,
          'status': 'active',
          'created_at': '2026-09-01 08:00:00',
        });

        final saleRepo = SaleRepository();
        final sale = Sale(
          transactionNumber: '',
          transactionDate: '$todayStr 11:00:00',
          paymentMethod: 'qris',
          totalAmount: 36000,
          totalHpp: 12000,
          totalProfit: 24000,
          createdAt: '$todayStr 11:00:00',
          updatedAt: '$todayStr 11:00:00',
        );
        final items = [
          SaleItem(
            productId: p1,
            recipeVersionId: r1,
            productName: 'Es Kopi Aren',
            quantity: 2.0,
            sellingPrice: 18000,
            hppPerUnit: 6000,
            subtotal: 36000,
            totalHpp: 12000,
            totalProfit: 24000,
            createdAt: '$todayStr 11:00:00',
          ),
        ];
        await saleRepo.createSaleWithItems(sale: sale, items: items);
      });

      debugPrint(
        '[Test 17] Langkah 2: Buka aplikasi & navigasi ke tab Laporan',
      );
      await tester.pumpWidget(const LabanaApp());
      await settleAsync(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Laporan'),
        ),
      );
      await settleAsync(tester);

      debugPrint('[Test 17] Langkah 3: Verifikasi tab Harian dengan data riil');
      expect(find.text('Rp36.000'), findsWidgets); // Omzet
      expect(find.text('Rp12.000'), findsWidgets); // HPP
      expect(find.text('Rp24.000'), findsWidgets); // Laba
      expect(find.text('1 Transaksi • 2 Terjual'), findsOneWidget);
      expect(find.text('Es Kopi Aren'), findsWidgets);
      expect(find.text('QRIS'), findsOneWidget);

      debugPrint('[Test 17] Langkah 4: Uji perpindahan ke tab Mingguan');
      await tester.tap(find.text('Minggu'));
      await settleAsync(tester);
      expect(find.text('Breakdown Harian'), findsOneWidget);
      expect(find.text('7 Hari'), findsOneWidget);

      debugPrint('[Test 17] Langkah 5: Uji perpindahan ke tab Bulanan');
      await tester.tap(find.text('Bulan'));
      await settleAsync(tester);
      expect(find.text('Breakdown Harian'), findsOneWidget);

      debugPrint('[Test 17] Langkah 6: Uji navigasi periode sebelumnya');
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await settleAsync(tester);
      // Bulan lalu belum ada transaksi -> Empty state
      expect(
        find.text('Belum ada transaksi pada periode ini.'),
        findsOneWidget,
      );

      debugPrint('[Test 17] SELESAI');
    },
  );
}
