import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/constants/app_constants.dart';
import 'package:labana/core/theme/theme_controller.dart';
import 'package:labana/main.dart';

void main() {
  testWidgets('LabanaApp starter smoke test', (WidgetTester tester) async {
    // Reset theme mode notifier before test
    appThemeModeNotifier.value = ThemeMode.system;

    await tester.pumpWidget(const LabanaApp());
    await tester.pumpAndSettle();

    // Verifikasi branding dan pesan awal
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);
    expect(find.text(AppConstants.setupSuccessMessage), findsOneWidget);

    // Verifikasi kontrol pemilihan mode tema
    expect(find.text('Pilihan Mode Tema'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);

    // Verifikasi interaksi perubahan mode tema
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.dark);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(appThemeModeNotifier.value, ThemeMode.light);
  });
}
