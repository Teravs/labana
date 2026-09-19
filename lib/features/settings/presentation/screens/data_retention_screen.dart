import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/currency_formatter.dart';
import '../../models/retention_models.dart';
import '../../services/data_retention_service.dart';

/// Halaman Retensi Data untuk mengelola pengunduhan laporan dan pembersihan arsip transaksi bulanan.
class DataRetentionScreen extends StatefulWidget {
  final DataRetentionService? retentionService;

  const DataRetentionScreen({super.key, this.retentionService});

  @override
  State<DataRetentionScreen> createState() => _DataRetentionScreenState();
}

class _DataRetentionScreenState extends State<DataRetentionScreen> {
  late final DataRetentionService _retentionService;
  bool _isLoading = true;
  bool _isActionRunning = false;
  List<MonthlyArchiveItem> _archives = [];

  @override
  void initState() {
    super.initState();
    _retentionService = widget.retentionService ?? DataRetentionService();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    setState(() => _isLoading = true);
    try {
      final archives = await _retentionService.getMonthlyArchives();
      if (mounted) {
        setState(() {
          _archives = archives;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat arsip transaksi: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Mengunduh laporan bulanan PDF untuk arsip terkait.
  Future<void> _handleDownloadReport(MonthlyArchiveItem item) async {
    if (_isActionRunning) return;
    setState(() => _isActionRunning = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Menyiapkan laporan PDF ${item.monthLabel}...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final file = await _retentionService.downloadMonthlyReport(
        year: item.year,
        month: item.month,
      );

      if (mounted) {
        final fileName = p.basename(file.path);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF006C4C),
            content: Text(
              'Laporan $fileName berhasil diunduh ke folder Download.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        await _loadArchives();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Gagal mengunduh laporan PDF: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  /// Meminta konfirmasi tegas sebelum menghapus riwayat transaksi bulan tersebut.
  Future<void> _confirmAndDelete(MonthlyArchiveItem item) async {
    if (_isActionRunning) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: colorScheme.error,
            size: 40,
          ),
          title: Text('Hapus Transaksi ${item.monthLabel}?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tindakan ini akan menghapus ${item.transactionCount} data transaksi penjualan periode ${item.monthLabel} secara permanen.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Data Resep, Produk, Bahan Mentah, dan Bahan Olahan 100% AMAN dan TIDAK AKAN DIHAPUS.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Cadangan pengaman database lokal otomatis dibuat sebelum proses pembersihan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(150),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus Permanen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isActionRunning = true);

    try {
      final count = await _retentionService.deleteMonthlyTransactions(
        year: item.year,
        month: item.month,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF006C4C),
            content: Text(
              'Berhasil menghapus $count transaksi periode ${item.monthLabel}.',
            ),
          ),
        );
        await _loadArchives();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colorScheme.error,
            content: Text('Gagal menghapus transaksi: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retensi Data'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadArchives,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  children: [
                    // Banner Informasi Retensi
                    _buildInfoBanner(context),
                    const SizedBox(height: 16),

                    if (_archives.isEmpty)
                      _buildEmptyState(context)
                    else ...[
                      Text(
                        'Arsip Riwayat Bulanan',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._archives.map((item) => _buildArchiveCard(context, item)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembersihan Transaksi Penjualan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola arsip transaksi per bulan. Untuk keamanan data finansial Anda, transaksi bulan lalu hanya dapat dihapus setelah laporan PDF diunduh.\n\nDatabase master resep, bahan, dan katalog produk tetap utuh 100%.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: colorScheme.outline.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Riwayat Transaksi',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data transaksi penjualan bulanan akan muncul di sini secara otomatis.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(BuildContext context, MonthlyArchiveItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canDelete = item.canDelete;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isCurrentMonth
              ? colorScheme.primary.withAlpha(100)
              : colorScheme.outlineVariant.withAlpha(80),
          width: item.isCurrentMonth ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Baris 1: Nama Bulan & Badge Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.monthLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildStatusBadge(context, item),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 2: Ringkasan Transaksi & Omzet
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: colorScheme.onSurface.withAlpha(140),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.transactionCount} Transaksi',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(180),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Omzet: ${CurrencyFormatter.formatRupiah(item.totalOmzet.toInt())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Baris 3: Tombol Aksi
            Row(
              children: [
                // Tombol Unduh Laporan PDF
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: item.needsReDownload
                            ? const Color(0xFFE65100)
                            : (item.isDownloaded
                                ? const Color(0xFF2E7D32)
                                : colorScheme.primary),
                      ),
                      foregroundColor: item.needsReDownload
                          ? const Color(0xFFE65100)
                          : (item.isDownloaded
                              ? const Color(0xFF2E7D32)
                              : colorScheme.primary),
                    ),
                    icon: Icon(
                      item.needsReDownload
                          ? Icons.refresh_rounded
                          : (item.isDownloaded
                              ? Icons.check_circle_outline_rounded
                              : Icons.download_rounded),
                      size: 18,
                    ),
                    label: Text(
                      item.isDownloaded ? 'Unduh Ulang' : 'Unduh PDF',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: _isActionRunning
                        ? null
                        : () => _handleDownloadReport(item),
                  ),
                ),
                const SizedBox(width: 12),

                // Tombol Hapus Transaksi
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: canDelete
                          ? colorScheme.errorContainer
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: canDelete
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurface.withAlpha(100),
                    ),
                    icon: Icon(
                      item.isCurrentMonth
                          ? Icons.lock_outline_rounded
                          : Icons.delete_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      item.isCurrentMonth ? 'Bulan Aktif' : 'Hapus Data',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: (!canDelete || _isActionRunning)
                        ? null
                        : () => _confirmAndDelete(item),
                  ),
                ),
              ],
            ),

            // Pesan bantuan jika tombol hapus dinonaktifkan
            if (!canDelete) ...[
              const SizedBox(height: 8),
              Text(
                item.isCurrentMonth
                    ? 'Bulan berjalan dilindungi demi keutuhan data aktif.'
                    : item.needsReDownload
                    ? 'Terdapat pembaruan data transaksi. Unduh ulang laporan sebelum melakukan pembersihan data.'
                    : 'Unduh laporan PDF terlebih dahulu sebelum dapat menghapus transaksi.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurface.withAlpha(130),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, MonthlyArchiveItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (item.isCurrentMonth) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withAlpha(180),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock,
              size: 13,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              'Bulan Berjalan',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (item.needsReDownload) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.update_rounded,
              size: 13,
              color: Color(0xFFE65100),
            ),
            const SizedBox(width: 4),
            Text(
              'Perlu Unduh Ulang',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFFE65100),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (item.isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(width: 4),
            Text(
              'Laporan Diunduh',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF1B5E20),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 13,
            color: Color(0xFFE65100),
          ),
          const SizedBox(width: 4),
          Text(
            'Belum Diunduh',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFFE65100),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
