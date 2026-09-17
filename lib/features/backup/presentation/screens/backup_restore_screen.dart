import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_title.dart';
import '../../../../main.dart';
import '../../models/backup_models.dart';
import '../../services/database_backup_service.dart';

/// Layanan manajemen Backup dan Restore database SQLite Labana secara offline-first.
class BackupRestoreScreen extends StatefulWidget {
  final DatabaseBackupService? backupService;

  const BackupRestoreScreen({super.key, this.backupService});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late final DatabaseBackupService _backupService;

  List<BackupFileInfo> _localBackups = [];
  bool _isLoading = true;
  bool _isActionRunning = false;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ?? DatabaseBackupService();
    _loadLocalBackups();
  }

  Future<void> _loadLocalBackups() async {
    setState(() => _isLoading = true);
    try {
      final list = await _backupService.fileManager.listLocalBackups();
      if (mounted) {
        setState(() {
          _localBackups = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Membuat cadangan database baru dari database aktif.
  Future<void> _handleCreateBackup() async {
    if (_isActionRunning) return;

    setState(() => _isActionRunning = true);

    try {
      final createdFile = await _backupService.createBackup();
      if (mounted) {
        final fileName = p.basename(createdFile.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cadangan "$fileName" berhasil dibuat!'),
            backgroundColor: AppColors.primary,
          ),
        );
        await _loadLocalBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat cadangan: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  /// Memilih file database dari luar aplikasi (misal folder Downloads via SAF).
  Future<void> _handlePickExternalBackup() async {
    if (_isActionRunning) return;

    try {
      final file = await _backupService.pickExternalBackupFile();
      if (file == null) {
        // Pengguna membatalkan picker
        return;
      }

      if (mounted) {
        await _confirmAndRestore(file, isExternal: true);
      }
    } catch (e) {
      if (mounted) {
        final message = e is FormatException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Menampilkan rincian berkas cadangan dan meminta konfirmasi tegas sebelum pemulihan.
  Future<void> _confirmAndRestore(File file, {required bool isExternal}) async {
    final fileName = p.basename(file.path);

    setState(() => _isActionRunning = true);

    final validation = await _backupService.validateBackupFile(file);

    if (mounted) {
      setState(() => _isActionRunning = false);
    }

    if (!validation.isValid) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.error_outline_rounded,
            color: Theme.of(ctx).colorScheme.error,
            size: 36,
          ),
          title: const Text('Berkas Tidak Valid'),
          content: Text(
            validation.errorMessage ??
                'Berkas cadangan tidak memenuhi standar validasi Labana.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    final summary = validation.summary!;
    if (!mounted) return;

    // 2. Dialog Konfirmasi Pemulihan dengan Rincian Data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 40,
          ),
          title: const Text('Konfirmasi Pemulihan Database'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text(
                    'PERINGATAN: Memulihkan database akan menggantikan seluruh data aktif saat ini dengan data dari cadangan ini.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Rincian Data Cadangan:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(ctx, 'Nama Berkas', fileName),
                _buildSummaryRow(
                  ctx,
                  'Total Transaksi',
                  '${summary.transactionCount} transaksi',
                ),
                _buildSummaryRow(
                  ctx,
                  'Produk Menu',
                  '${summary.productCount} produk',
                ),
                _buildSummaryRow(
                  ctx,
                  'Bahan Mentah',
                  '${summary.ingredientCount} bahan',
                ),
                _buildSummaryRow(
                  ctx,
                  'Bahan Olahan',
                  '${summary.processedIngredientCount} bahan',
                ),
                _buildSummaryRow(
                  ctx,
                  'Transaksi Terakhir',
                  summary.formattedLastTransactionDate,
                ),
                if (isExternal)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '* Berkas dipilih dari luar penyimpanan aplikasi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
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
              child: const Text('Pulihkan Database'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // 3. Eksekusi Restore dengan Proteksi Atomik
    setState(() => _isActionRunning = true);

    try {
      await _backupService.restoreDatabase(
        backupFile: file,
        onStateRefresh: () {
          appReloadNotifier.value++;
        },
      );

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.primary,
              size: 40,
            ),
            title: const Text('Pemulihan Berhasil!'),
            content: Text(
              'Database berhasil dipulihkan dari "$fileName". Seluruh data aplikasi telah dimuat ulang.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        await _loadLocalBackups();
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              color: Theme.of(ctx).colorScheme.error,
              size: 40,
            ),
            title: const Text('Pemulihan Gagal'),
            content: Text(
              'Terjadi kendala saat memulihkan database:\n$e\n\nDatabase lama Anda tetap utuh berkat sistem perlindungan rollback otomatis.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      }
    }
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Membagikan berkas cadangan melalui system share sheet.
  Future<void> _handleShareBackup(BackupFileInfo backup) async {
    try {
      final success = await _backupService.fileManager.shareBackup(
        backup.filePath,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak dapat membuka lembar berbagi sistem pada perangkat ini.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membagikan berkas: $e')));
      }
    }
  }

  /// Menghapus berkas cadangan lokal dengan dialog konfirmasi.
  Future<void> _handleDeleteBackup(BackupFileInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Berkas Cadangan?'),
        content: Text(
          'Berkas "${backup.fileName}" akan dihapus permanen dari penyimpanan lokal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _backupService.fileManager.deleteBackup(backup.filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas "${backup.fileName}" telah dihapus.')),
        );
        _loadLocalBackups();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _isActionRunning ? null : _loadLocalBackups,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SEKSI 1: CADANGKAN SEKARANG
                    const AppSectionTitle(title: 'Cadangkan Database'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.cloud_upload_outlined,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cadangan SQLite Aktual',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Format berkas .db murni yang aman & terverifikasi.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withAlpha(160),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                icon: _isActionRunning
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.save_alt_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  _isActionRunning
                                      ? 'Memproses...'
                                      : 'Cadangkan Sekarang',
                                ),
                                onPressed: _isActionRunning
                                    ? null
                                    : _handleCreateBackup,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SEKSI 2: PULIHKAN DARI LUAR
                    const AppSectionTitle(title: 'Pulihkan dari Berkas Luar'),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7D5800).withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.file_open_outlined,
                            color: Color(0xFF7D5800),
                          ),
                        ),
                        title: const Text('Pilih Berkas Cadangan (.db)'),
                        subtitle: const Text(
                          'Pilih berkas dari Downloads, WhatsApp, dll.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _isActionRunning
                            ? null
                            : _handlePickExternalBackup,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SEKSI 3: DAFTAR CADANGAN LOKAL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppSectionTitle(title: 'Cadangan Lokal'),
                        if (_localBackups.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_localBackups.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (_localBackups.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 32,
                            horizontal: 16,
                          ),
                          child: AppEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Belum Ada Cadangan',
                            message:
                                'Ketuk tombol "Cadangkan Sekarang" di atas untuk membuat cadangan database pertama Anda.',
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _localBackups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final backup = _localBackups[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.storage_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                backup.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${backup.formattedDate} • ${backup.formattedFileSize}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withAlpha(160),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: 20,
                                    ),
                                    tooltip: 'Bagikan',
                                    onPressed: _isActionRunning
                                        ? null
                                        : () => _handleShareBackup(backup),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      size: 20,
                                    ),
                                    onSelected: (action) {
                                      if (action == 'restore') {
                                        _confirmAndRestore(
                                          File(backup.filePath),
                                          isExternal: false,
                                        );
                                      } else if (action == 'delete') {
                                        _handleDeleteBackup(backup);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.restore_rounded,
                                              size: 18,
                                            ),
                                            SizedBox(width: 10),
                                            Text('Pulihkan'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              color: colorScheme.error,
                                              size: 18,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Hapus',
                                              style: TextStyle(
                                                color: colorScheme.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
