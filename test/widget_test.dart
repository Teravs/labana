import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/constants/app_constants.dart';
import 'package:labana/core/theme/theme_controller.dart';
import 'package:labana/main.dart';

void main() {
  setUp(() {
    appThemeModeNotifier.value = ThemeMode.system;
  });

  // ---------------------------------------------------------------------------
  // Test 1 & 2: App dapat dijalankan & Home tampil
  // ---------------------------------------------------------------------------
  testWidgets(
    'Test 1 & 2: App dapat dijalankan dan menampilkan Home dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LabanaApp());
      await tester.pumpAndSettle();

      // Verifikasi Home header & branding
      expect(
        find.text('Selamat datang di ${AppConstants.appName}'),
        findsOneWidget,
      );
      expect(find.text(AppConstants.appTagline), findsOneWidget);

      // Verifikasi stat cards placeholder
      expect(find.text('Omzet Hari Ini'), findsOneWidget);
      expect(find.text('Modal / HPP'), findsOneWidget);
      expect(find.text('Laba'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(4));

      // Verifikasi quick actions
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
  // Test 4: User dapat berpindah ke halaman Bahan
  // ---------------------------------------------------------------------------
  testWidgets('Test 4: User dapat berpindah ke halaman Bahan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    // Tap tab Bahan di NavigationBar
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Bahan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada bahan.'), findsOneWidget);
    expect(find.text('Tambah Bahan'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Test 5: User dapat berpindah ke halaman Penjualan
  // ---------------------------------------------------------------------------
  testWidgets('Test 5: User dapat berpindah ke halaman Penjualan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    // Tap tab Penjualan
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Penjualan'),
      ),
    );
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    // Tap tab Laporan
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Laporan'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari'), findsOneWidget);
    expect(find.text('Minggu'), findsOneWidget);
    expect(find.text('Bulan'), findsOneWidget);
    expect(find.text('Belum ada data laporan.'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Test 7: User dapat berpindah ke halaman Pengaturan
  // ---------------------------------------------------------------------------
  testWidgets('Test 7: User dapat berpindah ke halaman Pengaturan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    // Tap tab Pengaturan
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

    // Pergi ke Pengaturan
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Pengaturan'),
      ),
    );
    await tester.pumpAndSettle();

    // Pilih mode Gelap
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.dark);

    // Pilih mode Terang
    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.light);

    // Pilih mode Sistem
    await tester.tap(find.text('Sistem'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.system);
  });
}
