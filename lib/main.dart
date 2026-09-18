import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/settings/data/app_settings_repository.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi profil bisnis dan pengaturan dari SQLite
  await AppSettingsRepository().getBusinessProfile();
  runApp(const LabanaApp());
}

/// Notifier global untuk memicu rekonstruksi bersih seluruh widget tree saat database dipulihkan.
final ValueNotifier<int> appReloadNotifier = ValueNotifier<int>(0);

/// Root widget aplikasi Labana.
class LabanaApp extends StatelessWidget {
  const LabanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appReloadNotifier,
      builder: (context, reloadCount, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeModeNotifier,
          builder: (context, currentThemeMode, _) {
            return KeyedSubtree(
              key: ValueKey('labana_root_$reloadCount'),
              child: MaterialApp.router(
                title: AppConstants.appName,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: currentThemeMode,
                routerConfig: AppRouter.router,
                debugShowCheckedModeBanner: false,
              ),
            );
          },
        );
      },
    );
  }
}
