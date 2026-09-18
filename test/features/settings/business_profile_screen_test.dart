import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/settings/data/app_settings_repository.dart';
import 'package:labana/features/settings/models/business_profile.dart';
import 'package:labana/features/settings/presentation/screens/business_profile_screen.dart';

class FakeAppSettingsRepository extends AppSettingsRepository {
  BusinessProfile profile;
  bool saveCalled = false;
  bool resetCalled = false;

  FakeAppSettingsRepository({
    this.profile = const BusinessProfile(
      name: 'Labana',
      tagline: 'Kelola Modal, Pahami Laba.',
    ),
  });

  @override
  Future<BusinessProfile> getBusinessProfile() async {
    return profile;
  }

  @override
  Future<BusinessProfile> saveBusinessProfile({
    required String name,
    required String tagline,
    String? newLogoSourcePath,
    bool clearLogo = false,
  }) async {
    saveCalled = true;
    profile = profile.copyWith(
      name: name.trim().isEmpty ? 'Labana' : name.trim(),
      tagline: tagline.trim(),
      clearLogo: clearLogo,
      logoPath: newLogoSourcePath ?? (clearLogo ? null : profile.logoPath),
    );
    AppSettingsRepository.businessProfileNotifier.value = profile;
    return profile;
  }

  @override
  Future<BusinessProfile> resetToDefault() async {
    resetCalled = true;
    profile = const BusinessProfile(
      name: 'Labana',
      tagline: 'Kelola Modal, Pahami Laba.',
      logoPath: null,
    );
    AppSettingsRepository.businessProfileNotifier.value = profile;
    return profile;
  }
}

void main() {
  group('BusinessProfileScreen Widget Tests', () {
    testWidgets('menampilkan data profil awal dan memungkinkan pengubahan nama serta slogan', (tester) async {
      final fakeRepo = FakeAppSettingsRepository(
        profile: const BusinessProfile(
          name: 'Warung Berkah',
          tagline: 'Murah & Lezat',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessProfileScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi input terisi
      expect(find.text('Warung Berkah'), findsOneWidget);
      expect(find.text('Murah & Lezat'), findsOneWidget);
      expect(find.text('Identitas Usaha'), findsOneWidget);

      // Ubah nama toko
      final nameFields = find.byType(TextFormField);
      expect(nameFields, findsNWidgets(2));
      await tester.enterText(nameFields.first, 'Katering Bu Joko');

      // Tekan tombol Simpan Perubahan
      final saveButton = find.widgetWithText(FilledButton, 'Simpan Perubahan');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.saveCalled, isTrue);
      expect(fakeRepo.profile.name, 'Katering Bu Joko');
    });

    testWidgets('menampilkan dialog konfirmasi saat tombol Reset ke Default ditekan', (tester) async {
      final fakeRepo = FakeAppSettingsRepository(
        profile: const BusinessProfile(
          name: 'Katering Bu Joko',
          tagline: 'Enak Tenan',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BusinessProfileScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll ke tombol Reset ke Bawaan Labana
      final resetButton = find.widgetWithText(OutlinedButton, 'Reset ke Bawaan Labana');
      await tester.ensureVisible(resetButton);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Dialog konfirmasi muncul
      expect(find.text('Reset ke Default?'), findsOneWidget);

      // Tekan tombol Reset di dialog
      final dialogResetBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Reset'),
      );
      await tester.tap(dialogResetBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.resetCalled, isTrue);
      expect(fakeRepo.profile.name, 'Labana');
    });
  });
}
