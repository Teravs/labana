import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_section_title.dart';

/// Halaman Pengaturan dengan konfigurasi tema, placeholder data/arsip, dan informasi aplikasi.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: TAMPILAN
              const AppSectionTitle(title: 'Tampilan'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Tampilan',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih tampilan aplikasi sesuai preferensi kenyamanan mata.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: appThemeModeNotifier,
                        builder: (context, currentMode, _) {
                          return SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('Sistem'),
                                  icon: Icon(Icons.brightness_auto, size: 16),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Terang'),
                                  icon: Icon(Icons.light_mode, size: 16),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Gelap'),
                                  icon: Icon(Icons.dark_mode, size: 16),
                                ),
                              ],
                              selected: {currentMode},
                              onSelectionChanged: (newSelection) {
                                appThemeModeNotifier.value = newSelection.first;
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 2: DATA
              const AppSectionTitle(title: 'Data'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('Backup Data'),
                      subtitle: const Text('Cadangkan database lokal'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => AppFeedback.showFeatureNotice(context),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: const Text('Restore Data'),
                      subtitle: const Text('Pulihkan database dari cadangan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => AppFeedback.showFeatureNotice(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 3: ARSIP & PEMBERSIHAN
              const AppSectionTitle(title: 'Arsip & Pembersihan'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: const Text('Retensi Data'),
                  subtitle:
                      const Text('Batas waktu penyimpanan arsip transaksi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => AppFeedback.showFeatureNotice(context),
                ),
              ),
              const SizedBox(height: 24),

              // SECTION 4: TENTANG
              const AppSectionTitle(title: 'Tentang'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'L',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppConstants.appTagline,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(170),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Versi ${AppConstants.appVersion}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

