import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/sale_repository.dart';
import '../../models/sale.dart';
import '../widgets/sale_item_tile.dart';
import 'sale_form_screen.dart';

/// Layar rincian transaksi penjualan yang menampilkan data snapshot historis permanen.
class SaleDetailScreen extends StatefulWidget {
  final int saleId;
  final SaleRepository? saleRepo;

  const SaleDetailScreen({super.key, required this.saleId, this.saleRepo});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late final SaleRepository _saleRepo;
  bool _isLoading = true;
  Sale? _sale;

  @override
  void initState() {
    super.initState();
    _saleRepo = widget.saleRepo ?? SaleRepository();
    _loadSale();
  }

  Future<void> _loadSale() async {
    setState(() => _isLoading = true);
    try {
      final sale = await _saleRepo.getById(widget.saleId);
      if (mounted) {
        setState(() {
          _sale = sale;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editSale() async {
    if (_sale == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SaleFormScreen(saleId: widget.saleId, saleRepo: _saleRepo),
      ),
    );

    if (updated == true && mounted) {
      _loadSale();
    }
  }

  Future<void> _confirmDelete() async {
    if (_sale == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Penjualan?'),
          content: Text(
            'Transaksi ${_sale!.transactionNumber} akan dihapus.\n\nTindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _saleRepo.deleteSale(widget.saleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil dihapus.')),
          );
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus transaksi: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Penjualan')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Memuat detail penjualan...'),
          ),
        ),
      );
    }

    if (_sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Penjualan')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              const Text('Transaksi tidak ditemukan.'),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final sale = _sale!;
    final items = sale.items ?? [];
    final isProfitPositive = sale.totalProfit >= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Transaksi',
            onPressed: _editSale,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus Transaksi',
            color: AppColors.error,
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(
                      isDark ? 80 : 120,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sale.transactionNumber,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        _PaymentMethodChip(label: sale.paymentMethodLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sale.formattedDateFull,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sale.formattedTime,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Rincian Produk
              Text(
                'Rincian Produk (${items.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              ...items.map(
                (item) => SaleItemTile(item: item, isEditable: false),
              ),

              const SizedBox(height: 16),

              // Ringkasan Transaksi
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.primary.withAlpha(40)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Omzet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.formatRupiah(sale.totalAmount),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total HPP',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.formatRupiah(sale.totalHpp),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Laba',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              CurrencyFormatter.formatRupiah(sale.totalProfit),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isProfitPositive
                                    ? AppColors.primary
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editSale,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Hapus'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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

class _PaymentMethodChip extends StatelessWidget {
  final String label;

  const _PaymentMethodChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withAlpha(40)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
