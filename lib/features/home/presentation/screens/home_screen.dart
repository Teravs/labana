import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_section_title.dart';
import '../../../../core/widgets/app_stat_card.dart';
import '../../../../routes/app_routes.dart';
import '../../../sales/data/sale_repository.dart';
import '../../models/dashboard_summary.dart';

/// Halaman Home / Dashboard Labana dengan data agregasi SQLite riil hari ini.
class HomeScreen extends StatefulWidget {
  final SaleRepository? saleRepo;

  const HomeScreen({super.key, this.saleRepo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SaleRepository _saleRepo;

  DashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _saleRepo = widget.saleRepo ?? SaleRepository();
    SaleRepository.salesChangeNotifier.addListener(_onSalesChanged);
    _loadDashboardData();
  }

  @override
  void dispose() {
    SaleRepository.salesChangeNotifier.removeListener(_onSalesChanged);
    super.dispose();
  }

  void _onSalesChanged() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  /// Memuat data agregasi dashboard untuk hari ini menggunakan tanggal lokal.
  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final dateStr = SaleRepository.formatLocalDate(now);
      final data = await _saleRepo.getTodayDashboardData(dateStr: dateStr);
      if (mounted) {
        setState(() {
          _currentDate = now;
          _dashboardData = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Data belum dapat dimuat.';
        });
      }
    }
  }

  /// Mengembalikan sapaan ramah sesuai jam lokal perangkat.
  String _getGreeting(int hour) {
    if (hour >= 4 && hour < 11) {
      return 'Selamat pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat sore';
    } else {
      return 'Selamat malam';
    }
  }

  /// Memformat tanggal ke bahasa Indonesia (misal: "15 September 2026").
  String _formatIndonesianDate(DateTime dt) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = _dashboardData?.summary ?? const DashboardSummary();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                AppConstants.logoIconPath,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Text(AppConstants.appName),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error State Banner jika query gagal
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withAlpha(120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.error.withAlpha(120),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadDashboardData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Header Card / Greeting & Tanggal Hari Ini
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting(_currentDate.hour)} 👋',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatIndonesianDate(_currentDate),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface.withAlpha(180),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.primary.withAlpha(40),
                              ),
                            ),
                            child: Text(
                              'Hari Ini',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        'Selamat datang di ${AppConstants.appName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppConstants.appTagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Ringkasan Hari Ini (4 Kartu Finansial)
                const AppSectionTitle(title: 'Ringkasan Hari Ini'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    AppStatCard(
                      title: 'Omzet Hari Ini',
                      value: _isLoading && _dashboardData == null
                          ? '—'
                          : summary.formattedTotalOmzet,
                      icon: Icons.payments_outlined,
                    ),
                    AppStatCard(
                      title: 'Modal / HPP',
                      value: _isLoading && _dashboardData == null
                          ? '—'
                          : summary.formattedTotalHpp,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    AppStatCard(
                      title: 'Laba',
                      value: _isLoading && _dashboardData == null
                          ? '—'
                          : summary.formattedTotalProfit,
                      icon: Icons.trending_up_rounded,
                      iconColor: summary.totalProfit >= 0
                          ? AppColors.accent
                          : colorScheme.error,
                    ),
                    AppStatCard(
                      title: 'Transaksi',
                      value: _isLoading && _dashboardData == null
                          ? '—'
                          : '${summary.transactionCount}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Banner: Produk Terjual Hari Ini
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Produk Terjual Hari Ini',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        _isLoading && _dashboardData == null
                            ? '—'
                            : '${summary.formattedProductsSold} produk terjual',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Performa Produk Hari Ini
                const AppSectionTitle(title: 'Performa Produk'),
                Row(
                  children: [
                    // Produk Terlaris
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(60),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 16,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Produk Terlaris',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface
                                                .withAlpha(180),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_dashboardData?.topSelling != null) ...[
                                Text(
                                  _dashboardData!.topSelling!.productName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_dashboardData!.topSelling!.formattedQuantity} terjual',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Belum ada penjualan',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withAlpha(140),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Laba Tertinggi
                    Expanded(
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withAlpha(60),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.monetization_on_outlined,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Laba Tertinggi',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface
                                                .withAlpha(180),
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_dashboardData?.highestProfit != null) ...[
                                Text(
                                  _dashboardData!.highestProfit!.productName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dashboardData!
                                      .highestProfit!
                                      .formattedProfit,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Belum ada penjualan',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface.withAlpha(140),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Empty state message jika transaksi 0
                if (!_isLoading &&
                    _dashboardData != null &&
                    _dashboardData!.isEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Belum ada penjualan hari ini.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mulai catat penjualan untuk melihat ringkasan bisnis kamu.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withAlpha(160),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Section: Aksi Cepat
                const AppSectionTitle(title: 'Aksi Cepat'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push(AppRoutes.saleNew);
                        if (mounted) {
                          _loadDashboardData();
                        }
                      },
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: const Text('+ Penjualan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.ingredients),
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('+ Bahan'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.products),
                      icon: const Icon(Icons.menu_book_rounded, size: 18),
                      label: const Text('+ Produk / Resep'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
