import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_section_title.dart';
import '../../../../core/widgets/app_stat_card.dart';

/// Halaman Home / Dashboard Labana dengan stat card placeholder dan quick actions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppConstants.appName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card / Greeting
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.primary.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat datang di ${AppConstants.appName}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppConstants.appTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withAlpha(180),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Ringkasan Hari Ini
              const AppSectionTitle(title: 'Ringkasan Hari Ini'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: const [
                  AppStatCard(
                    title: 'Omzet Hari Ini',
                    value: '—',
                    icon: Icons.payments_outlined,
                  ),
                  AppStatCard(
                    title: 'Modal / HPP',
                    value: '—',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  AppStatCard(
                    title: 'Laba',
                    value: '—',
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.accent,
                  ),
                  AppStatCard(
                    title: 'Transaksi',
                    value: '—',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section: Aksi Cepat
              const AppSectionTitle(title: 'Aksi Cepat'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => AppFeedback.showFeatureNotice(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('+ Penjualan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => AppFeedback.showFeatureNotice(context),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('+ Bahan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => AppFeedback.showFeatureNotice(context),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('+ Produk / Resep'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
