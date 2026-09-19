import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../data/ingredient_price_repository.dart';
import '../../data/ingredient_repository.dart';
import '../../models/ingredient.dart';
import '../../models/ingredient_price.dart';
import '../widgets/ingredient_form_sheet.dart';
import '../widgets/ingredient_price_form_sheet.dart';

/// Halaman detail bahan mentah untuk melihat status, harga aktif, format pembelian, dan riwayat harga.
class IngredientDetailScreen extends StatefulWidget {
  final int ingredientId;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? priceRepository;

  const IngredientDetailScreen({
    super.key,
    required this.ingredientId,
    this.ingredientRepository,
    this.priceRepository,
  });

  @override
  State<IngredientDetailScreen> createState() => _IngredientDetailScreenState();
}

class _IngredientDetailScreenState extends State<IngredientDetailScreen> {
  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _priceRepo;

  Ingredient? _ingredient;
  List<IngredientPrice> _prices = [];
  bool _isLoading = true;

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  @override
  void initState() {
    super.initState();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
    _loadData();
  }

  String _formatDisplayDate(String yyyyMmDd) {
    try {
      final parts = yyyyMmDd.split('-');
      if (parts.length == 3) {
        final y = parts[0];
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        return '$d ${_monthNames[m - 1]} $y';
      }
    } catch (_) {}
    return yyyyMmDd;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final item = await _ingredientRepo.getById(widget.ingredientId);
      final priceList = await _priceRepo.getPrices(widget.ingredientId);

      if (mounted) {
        setState(() {
          _ingredient = item;
          _prices = priceList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFeedback('Gagal memuat detail bahan.', isError: true);
      }
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openAddPriceForm() async {
    if (_ingredient == null) return;

    final result = await IngredientPriceFormSheet.show(
      context,
      ingredient: _ingredient!,
      priceRepository: _priceRepo,
      isFirstPrice: _prices.isEmpty,
    );

    if (result == true) {
      _showFeedback('Harga pembelian berhasil ditambahkan.');
      await _loadData();
    }
  }

  Future<void> _handleSetDefault(IngredientPrice price) async {
    try {
      await _priceRepo.setDefaultPrice(
        ingredientId: widget.ingredientId,
        priceId: price.id!,
      );
      _showFeedback('Format pembelian utama berhasil diperbarui.');
      await _loadData();
    } catch (e) {
      _showFeedback('Gagal mengubah format utama.', isError: true);
    }
  }

  Future<void> _showEditForm() async {
    if (_ingredient == null) return;
    final result = await IngredientFormSheet.show(
      context,
      initialIngredient: _ingredient,
      onSave: (newName) async {
        await _ingredientRepo.update(_ingredient!.id!, newName);
      },
    );
    if (result == true) {
      _showFeedback('Nama bahan berhasil diperbarui.');
      await _loadData();
    }
  }

  Future<void> _confirmDeactivate() async {
    if (_ingredient == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan bahan?'),
        content: Text(
          'Bahan "${_ingredient!.name}" akan disembunyikan dari daftar bahan aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _ingredientRepo.deactivate(_ingredient!.id!);
        _showFeedback('Bahan dinonaktifkan.');
        await _loadData();
      } catch (e) {
        _showFeedback('Gagal menonaktifkan bahan: $e', isError: true);
      }
    }
  }

  Future<void> _activateIngredient() async {
    if (_ingredient == null) return;
    try {
      await _ingredientRepo.activate(_ingredient!.id!);
      _showFeedback('Bahan berhasil diaktifkan kembali.');
      await _loadData();
    } catch (e) {
      _showFeedback(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Bahan')),
        body: Center(
          child: Text(
            'Memuat detail bahan...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ),
      );
    }

    if (_ingredient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Bahan')),
        body: const Center(child: Text('Bahan mentah tidak ditemukan.')),
      );
    }

    final ingredient = _ingredient!;
    final isActive = ingredient.isActive;

    // Tentukan harga saat ini (utamakan default, jika tidak ada ambil yang terbaru)
    final defaultPrice = _prices.where((p) => p.isDefault).firstOrNull;
    final currentPrice = defaultPrice ?? _prices.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(ingredient.name),
        actions: [
          if (isActive)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'edit') {
                  _showEditForm();
                } else if (action == 'deactivate') {
                  _confirmDeactivate();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Nama'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      Icon(
                        Icons.archive_outlined,
                        size: 18,
                        color: colorScheme.error,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Nonaktifkan',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit Nama',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _showEditForm,
                ),
                TextButton.icon(
                  onPressed: _activateIngredient,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Aktifkan'),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Header Info Bahan Mentah & Status
              _buildHeaderCard(theme, colorScheme, isActive),
              const SizedBox(height: 20),

              // Section: Harga Saat Ini
              _buildSectionTitle(theme, 'Harga Saat Ini'),
              const SizedBox(height: 8),
              if (currentPrice != null)
                _buildCurrentPriceCard(theme, colorScheme, currentPrice)
              else
                _buildEmptyPriceCard(theme, colorScheme),

              const SizedBox(height: 24),

              // Section: Riwayat Perubahan Harga
              if (_prices.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(theme, 'Riwayat Harga'),
                    TextButton.icon(
                      onPressed: _openAddPriceForm,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Harga'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildPriceHistoryList(theme, colorScheme),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _prices.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _openAddPriceForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Harga'),
            )
          : null,
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isActive,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary.withAlpha(25)
                    : colorScheme.outline.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive
                    ? Icons.inventory_2_outlined
                    : Icons.inventory_2_rounded,
                size: 26,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ingredient!.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withAlpha(30)
                              : Colors.grey.withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Aktif' : 'Nonaktif',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? Colors.green.shade800
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bahan Mentah',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPriceCard(
    ThemeData theme,
    ColorScheme colorScheme,
    IngredientPrice price,
  ) {
    final formattedPrice = CurrencyFormatter.formatRupiah(price.price);
    final formattedUnitCost = CurrencyFormatter.formatCostPerBaseUnit(
      price.costPerBaseUnit,
      price.baseUnit,
    );
    final displayDate = _formatDisplayDate(price.effectiveFrom);

    return Card(
      color: colorScheme.primary.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.primary.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  price.formattedPurchaseFormat,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (price.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Default',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedPrice,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.scale_rounded,
                  size: 16,
                  color: colorScheme.onSurface.withAlpha(160),
                ),
                const SizedBox(width: 6),
                Text(
                  formattedUnitCost,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '•',
                  style: TextStyle(color: colorScheme.onSurface.withAlpha(120)),
                ),
                const SizedBox(width: 12),
                Text(
                  'Berlaku sejak $displayDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPriceCard(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.price_change_outlined,
              size: 40,
              color: colorScheme.primary.withAlpha(160),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum ada harga',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tambahkan harga pembelian bahan ini untuk perhitungan modal dan HPP.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAddPriceForm,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Harga'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceHistoryList(ThemeData theme, ColorScheme colorScheme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _prices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = _prices[index];
        final formattedPrice = CurrencyFormatter.formatRupiah(p.price);
        final formattedUnitCost = CurrencyFormatter.formatCostPerBaseUnit(
          p.costPerBaseUnit,
          p.baseUnit,
        );
        final displayDate = _formatDisplayDate(p.effectiveFrom);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: p.isDefault
                  ? colorScheme.primary.withAlpha(100)
                  : colorScheme.outline.withAlpha(40),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayDate,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface.withAlpha(180),
                            ),
                          ),
                          if (p.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Default',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.formattedPurchaseFormat} · $formattedPrice',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedUnitCost,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!p.isDefault)
                  TextButton(
                    onPressed: () => _handleSetDefault(p),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Jadikan Default'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
