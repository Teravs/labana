import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_stat_card.dart';
import '../../../sales/data/sale_repository.dart';
import '../../data/report_repository.dart';
import '../../models/report_models.dart';
import '../../services/report_date_helper.dart';
import '../../services/report_pdf_service.dart';

/// Halaman Laporan Penjualan (Harian, Mingguan, Bulanan) berbasis data riil SQLite.
class ReportsScreen extends StatefulWidget {
  final ReportRepository? reportRepo;
  final ReportPdfService? pdfService;

  const ReportsScreen({super.key, this.reportRepo, this.pdfService});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportRepository _reportRepo;
  late final ReportPdfService _pdfService;

  ReportPeriodType _selectedPeriod = ReportPeriodType.daily;
  DateTime _referenceDate = DateTime.now();

  ReportData? _reportData;
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _reportRepo = widget.reportRepo ?? ReportRepository();
    _pdfService = widget.pdfService ?? ReportPdfService();
    _loadReportData();
    SaleRepository.salesChangeNotifier.addListener(_onSalesChanged);
  }

  @override
  void dispose() {
    SaleRepository.salesChangeNotifier.removeListener(_onSalesChanged);
    super.dispose();
  }

  void _onSalesChanged() {
    if (mounted) {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _reportRepo.getReportData(
        periodType: _selectedPeriod,
        referenceDate: _referenceDate,
      );
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Data laporan belum dapat dimuat.';
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(Set<ReportPeriodType> newSelection) {
    if (newSelection.isNotEmpty && newSelection.first != _selectedPeriod) {
      setState(() {
        _selectedPeriod = newSelection.first;
      });
      _loadReportData();
    }
  }

  void _onPreviousPeriod() {
    setState(() {
      _referenceDate = ReportDateHelper.getPreviousPeriod(
        _selectedPeriod,
        _referenceDate,
      );
    });
    _loadReportData();
  }

  void _onNextPeriod() {
    setState(() {
      _referenceDate = ReportDateHelper.getNextPeriod(
        _selectedPeriod,
        _referenceDate,
      );
    });
    _loadReportData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _referenceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'Pilih Tanggal Acuan Laporan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _referenceDate = picked;
      });
      _loadReportData();
    }
  }

  Future<void> _handleExportPdf() async {
    final currentData = _reportData;
    if (currentData == null || _isExporting) return;

    setState(() {
      _isExporting = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Membuat PDF...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final result = await _pdfService.exportAndShareReport(currentData);
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan PDF berhasil dibuat (${result.fileName}).'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal membuat laporan PDF.'),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: _handleExportPdf,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = _reportData?.summary ?? const ReportSummary();
    final hasData = _reportData != null && !_reportData!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            icon: Icon(
              _isExporting
                  ? Icons.hourglass_top_rounded
                  : Icons.picture_as_pdf_outlined,
            ),
            tooltip: 'Export PDF',
            onPressed: (_isLoading || _isExporting || _reportData == null)
                ? null
                : _handleExportPdf,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReportData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Filter Segment Periode
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ReportPeriodType>(
                    segments: const [
                      ButtonSegment(
                        value: ReportPeriodType.daily,
                        label: Text('Hari'),
                        icon: Icon(Icons.calendar_today_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ReportPeriodType.weekly,
                        label: Text('Minggu'),
                        icon: Icon(Icons.date_range_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: ReportPeriodType.monthly,
                        label: Text('Bulan'),
                        icon: Icon(Icons.calendar_month_outlined, size: 16),
                      ),
                    ],
                    selected: {_selectedPeriod},
                    onSelectionChanged: _onPeriodChanged,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Bar Navigasi Tanggal Periode (< [Label] >)
                _buildPeriodNavigationBar(theme, colorScheme),
                const SizedBox(height: 16),

                // 3. Error Banner jika terjadi error
                if (_errorMessage != null) ...[
                  _buildErrorBanner(theme, colorScheme),
                  const SizedBox(height: 16),
                ],

                // 4. Ringkasan Finansial Utama (4 Stat Cards)
                _buildFinancialSummaryCards(summary, colorScheme),
                const SizedBox(height: 16),

                // 5. Empty State Banner jika tidak ada transaksi
                if (!hasData && !_isLoading) ...[
                  _buildEmptyState(theme, colorScheme),
                ],

                // 6. Konten Laporan ketika ada transaksi
                if (hasData) ...[
                  // Performa Produk Terlaris & Laba Tertinggi
                  _buildTopPerformersSection(theme, colorScheme),
                  const SizedBox(height: 20),

                  // Breakdown Harian (khusus Mingguan & Bulanan)
                  if (_selectedPeriod != ReportPeriodType.daily) ...[
                    _buildDailyBreakdownSection(theme, colorScheme),
                    const SizedBox(height: 20),
                  ],

                  // Breakdown Performa Per Produk
                  _buildProductBreakdownSection(theme, colorScheme),
                  const SizedBox(height: 20),

                  // Ringkasan Metode Pembayaran
                  if ((_reportData?.paymentMethods ?? []).isNotEmpty) ...[
                    _buildPaymentMethodSection(theme, colorScheme),
                    const SizedBox(height: 20),
                  ],
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bar kontrol navigasi periode dengan tombol previous, label interaktif, dan tombol next.
  Widget _buildPeriodNavigationBar(ThemeData theme, ColorScheme colorScheme) {
    final periodLabel = ReportDateHelper.formatPeriodLabel(
      _selectedPeriod,
      _referenceDate,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Periode Sebelumnya',
            onPressed: _onPreviousPeriod,
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        periodLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Periode Berikutnya',
            onPressed: _onNextPeriod,
          ),
        ],
      ),
    );
  }

  /// Banner pesan error ketika terjadi kendala memuat data.
  Widget _buildErrorBanner(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withAlpha(120)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
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
            onPressed: _loadReportData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  /// 4 Card Ringkasan Finansial: Omzet, Modal / HPP, Estimasi Laba, Transaksi & Produk.
  Widget _buildFinancialSummaryCards(
    ReportSummary summary,
    ColorScheme colorScheme,
  ) {
    final showPlaceholder = _isLoading && _reportData == null;

    final omzetStr = showPlaceholder ? '—' : summary.formattedTotalOmzet;
    final hppStr = showPlaceholder ? '—' : summary.formattedTotalHpp;
    final profitStr = showPlaceholder ? '—' : summary.formattedTotalProfit;
    final trxAndProductStr = showPlaceholder
        ? '—'
        : '${summary.transactionCount} Transaksi • ${summary.formattedProductsSold} Terjual';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppStatCard(
                title: 'Omzet',
                value: omzetStr,
                icon: Icons.trending_up_rounded,
                iconColor: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppStatCard(
                title: 'Modal / HPP',
                value: hppStr,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppStatCard(
                title: 'Estimasi Laba',
                value: profitStr,
                icon: Icons.payments_outlined,
                iconColor: summary.totalProfit >= 0
                    ? AppColors.success
                    : colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppStatCard(
                title: 'Volume Penjualan',
                value: trxAndProductStr,
                icon: Icons.receipt_long_outlined,
                iconColor: colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tampilan Empty State ketika belum ada transaksi pada periode yang dipilih.
  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: colorScheme.onSurface.withAlpha(120),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada transaksi pada periode ini.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Transaksi penjualan yang dicatat pada periode ini akan otomatis muncul di sini.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha(160),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Section Performa Produk (Produk Terlaris & Laba Tertinggi).
  Widget _buildTopPerformersSection(ThemeData theme, ColorScheme colorScheme) {
    final topSelling = _reportData?.topSelling;
    final highestProfit = _reportData?.highestProfit;

    if (topSelling == null && highestProfit == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performa Produk Utama',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (topSelling != null) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(70),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Produk Terlaris',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        topSelling.productName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${topSelling.formattedQuantity} terjual',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (topSelling != null && highestProfit != null)
              const SizedBox(width: 12),
            if (highestProfit != null) ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withAlpha(70),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.tertiary.withAlpha(40),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            size: 16,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Laba Tertinggi',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        highestProfit.productName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        highestProfit.formattedProfit,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface.withAlpha(160),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Section Breakdown Harian (Senin–Minggu atau Kalender Bulan Lengkap).
  Widget _buildDailyBreakdownSection(ThemeData theme, ColorScheme colorScheme) {
    final dailyList = _reportData?.dailyBreakdown ?? [];
    if (dailyList.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Breakdown Harian',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              '${dailyList.length} Hari',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyList.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final item = dailyList[index];
              final hasTrx = item.transactionCount > 0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Tanggal & Hari
                    SizedBox(
                      width: 95,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.formattedDateDisplay,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: hasTrx
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: hasTrx
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasTrx
                                ? '${item.transactionCount} trx • ${item.formattedProductsSold} porsi'
                                : '0 transaksi',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withAlpha(120),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Metrik Keuangan Harian
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.formattedOmzet,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: hasTrx
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Modal: ${item.formattedHpp}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withAlpha(130),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Laba: ${item.formattedProfit}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: hasTrx
                                      ? (item.profit >= 0
                                            ? AppColors.success
                                            : colorScheme.error)
                                      : colorScheme.onSurface.withAlpha(130),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section Breakdown Rincian Performa per Produk.
  Widget _buildProductBreakdownSection(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final products = _reportData?.products ?? [];
    if (products.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Performa Produk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              '${products.length} Menu',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final p = products[index];

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.productName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withAlpha(80),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${p.formattedQuantity} Terjual',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Omzet',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(130),
                              ),
                            ),
                            Text(
                              p.formattedOmzet,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modal / HPP',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(130),
                              ),
                            ),
                            Text(
                              p.formattedHpp,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Laba',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(130),
                              ),
                            ),
                            Text(
                              p.formattedProfit,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: p.profit >= 0
                                    ? AppColors.success
                                    : colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Section Metode Pembayaran (Tunai, QRIS, Transfer).
  Widget _buildPaymentMethodSection(ThemeData theme, ColorScheme colorScheme) {
    final methods = _reportData?.paymentMethods ?? [];
    if (methods.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metode Pembayaran',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: methods.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            m.paymentMethod == 'qris'
                                ? Icons.qr_code_rounded
                                : (m.paymentMethod == 'transfer'
                                      ? Icons.account_balance_rounded
                                      : Icons.payments_outlined),
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.paymentMethodLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${m.transactionCount} trx)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withAlpha(130),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        m.formattedTotalAmount,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
