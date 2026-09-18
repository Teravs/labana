import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/settings/models/retention_models.dart';
import 'package:labana/features/settings/presentation/screens/data_retention_screen.dart';
import 'package:labana/features/settings/services/data_retention_service.dart';

/// Fake implementation of [DataRetentionService] for fast and reliable UI testing.
class FakeDataRetentionService extends DataRetentionService {
  List<MonthlyArchiveItem> items;
  bool downloadCalled = false;
  bool deleteCalled = false;

  FakeDataRetentionService({this.items = const []});

  @override
  Future<List<MonthlyArchiveItem>> getMonthlyArchives({DateTime? now}) async {
    return items;
  }

  @override
  Future<bool> isMonthReportDownloaded(int year, int month) async {
    return items.any((i) => i.year == year && i.month == month && i.isDownloaded);
  }

  @override
  Future<File> downloadMonthlyReport({
    required int year,
    required int month,
    bool saveToPublicDownloads = true,
  }) async {
    downloadCalled = true;
    items = items.map((i) {
      if (i.year == year && i.month == month) {
        return i.copyWith(
          isDownloaded: true,
          downloadedFilePath: '/mock/reports/Laporan-Labana-Bulanan-$year-$month.pdf',
        );
      }
      return i;
    }).toList();
    return File('/mock/reports/Laporan-Labana-Bulanan-$year-$month.pdf');
  }

  @override
  Future<int> deleteMonthlyTransactions({
    required int year,
    required int month,
    bool createSafetyBackup = true,
    DateTime? now,
  }) async {
    deleteCalled = true;
    final target = items.firstWhere((i) => i.year == year && i.month == month);
    final count = target.transactionCount;
    items = items.where((i) => !(i.year == year && i.month == month)).toList();
    return count;
  }
}

void main() {
  Widget buildTestWidget(FakeDataRetentionService fakeService) {
    return MaterialApp(
      home: DataRetentionScreen(retentionService: fakeService),
    );
  }

  testWidgets('menampilkan AppBar dan empty state saat belum ada riwayat transaksi', (tester) async {
    final fakeService = FakeDataRetentionService(items: []);

    await tester.pumpWidget(buildTestWidget(fakeService));
    await tester.pump(); // First frame with loader
    await tester.pump(); // Second frame after loadArchives future resolves

    expect(find.text('Retensi Data'), findsOneWidget);
    expect(find.text('Pembersihan Transaksi Penjualan'), findsOneWidget);
    expect(find.text('Belum Ada Riwayat Transaksi'), findsOneWidget);
  });

  testWidgets('menampilkan daftar arsip bulanan dengan badge dan tombol berproteksi', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeService = FakeDataRetentionService(
      items: [
        const MonthlyArchiveItem(
          year: 2026,
          month: 9,
          monthLabel: 'September 2026',
          transactionCount: 45,
          totalOmzet: 1250000,
          isCurrentMonth: true,
          isDownloaded: false,
        ),
        const MonthlyArchiveItem(
          year: 2026,
          month: 8,
          monthLabel: 'Agustus 2026',
          transactionCount: 30,
          totalOmzet: 850000,
          isCurrentMonth: false,
          isDownloaded: false,
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(fakeService));
    await tester.pump(); // Loader frame
    await tester.pump(); // Loaded frame

    // 1. Verifikasi Header dan Label Kartu
    expect(find.text('Retensi Data'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Agustus 2026'), findsOneWidget);

    // 2. Verifikasi Badge Status
    expect(find.text('Bulan Berjalan'), findsOneWidget);
    expect(find.text('Belum Diunduh'), findsOneWidget);

    // 3. Verifikasi Tombol Hapus Data
    // Bulan berjalan dinonaktifkan dengan label "Bulan Aktif"
    expect(find.text('Bulan Aktif'), findsOneWidget);
    // Bulan lalu belum diunduh sehingga tombol Hapus Data disabled
    final deleteButtonsBefore = find.widgetWithText(FilledButton, 'Hapus Data');
    expect(deleteButtonsBefore, findsOneWidget);
    final disabledDeleteWidget = tester.widget<FilledButton>(deleteButtonsBefore);
    expect(disabledDeleteWidget.onPressed, isNull);

    // 4. Unduh Laporan PDF bulan lalu (kartu kedua)
    final downloadButtons = find.widgetWithText(OutlinedButton, 'Unduh PDF');
    expect(downloadButtons, findsNWidgets(2));

    await tester.tap(downloadButtons.last);
    await tester.pump(); // Start action
    await tester.pump(); // End action and refresh archives

    expect(fakeService.downloadCalled, isTrue);

    // 5. Sekarang bulan lalu harus menampilkan badge "Laporan Diunduh" dan tombol "Unduh Ulang"
    expect(find.text('Laporan Diunduh'), findsOneWidget);
    expect(find.text('Unduh Ulang'), findsOneWidget);

    // 6. Tombol Hapus Data sekarang aktif!
    final activeDeleteWidget = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hapus Data'));
    expect(activeDeleteWidget.onPressed, isNotNull);

    // Tap tombol Hapus Data
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus Data'));
    await tester.pump(); // Dialog open animation

    // 7. Dialog konfirmasi harus muncul dengan peringatan & penegasan keamanan data
    expect(find.textContaining('Hapus Transaksi'), findsOneWidget);
    expect(find.textContaining('Data Resep, Produk, Bahan Mentah, dan Bahan Olahan 100% AMAN'), findsOneWidget);

    // 8. Tekan "Hapus Permanen"
    final confirmButton = find.text('Hapus Permanen');
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await tester.pump(); // Close dialog & start delete
    await tester.pump(); // Finish delete & refresh archives

    expect(fakeService.deleteCalled, isTrue);

    // 9. Transaksi Agustus telah terhapus, tersisa hanya transaksi September (bulan berjalan)
    expect(find.text('Agustus 2026'), findsNothing);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Bulan Berjalan'), findsOneWidget);
  });
}
