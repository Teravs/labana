import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../ingredients/data/ingredient_price_repository.dart';
import '../../../ingredients/data/ingredient_repository.dart';
import '../../../ingredients/models/ingredient_price.dart';
import '../../data/processed_ingredient_repository.dart';
import '../../models/processed_component.dart';
import '../../models/processed_ingredient.dart';
import '../../services/processed_ingredient_calculator.dart';
import '../widgets/processed_ingredient_form_sheet.dart';

/// Halaman detail bahan olahan untuk melihat komposisi komponen, ringkasan modal, dan status.
class ProcessedIngredientDetailScreen extends StatefulWidget {
  final int processedIngredientId;
  final ProcessedIngredientRepository? processedRepository;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? priceRepository;

  const ProcessedIngredientDetailScreen({
    super.key,
    required this.processedIngredientId,
    this.processedRepository,
    this.ingredientRepository,
    this.priceRepository,
  });

  @override
  State<ProcessedIngredientDetailScreen> createState() =>
      _ProcessedIngredientDetailScreenState();
}

class _ProcessedIngredientDetailScreenState
    extends State<ProcessedIngredientDetailScreen> {
  late final ProcessedIngredientRepository _processedRepo;
  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _priceRepo;

  ProcessedIngredient? _item;
  List<ProcessedComponent> _components = [];
  ProcessedIngredientCostResult? _costResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final item = await _processedRepo.getById(widget.processedIngredientId);
      if (item == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final components = await _processedRepo.getComponents(
        widget.processedIngredientId,
      );

      // Load harga bahan mentah dan data bahan olahan terkait untuk kalkulasi rekursif
      final pricesMap = <int, List<IngredientPrice>>{};
      final namesMap = <int, String>{};
      final procMap = <int, ProcessedIngredient>{};
      final procCompMap = <int, List<ProcessedComponent>>{};

      for (final comp in components) {
        if (comp.ingredientId != null &&
            !pricesMap.containsKey(comp.ingredientId)) {
          final prices = await _priceRepo.getPrices(comp.ingredientId!);
          pricesMap[comp.ingredientId!] = prices;
          final ing = await _ingredientRepo.getById(comp.ingredientId!);
          if (ing != null) {
            namesMap[comp.ingredientId!] = ing.name;
          }
        }
      }

      if (item.id != null) {
        procMap[item.id!] = item;
        procCompMap[item.id!] = components;
      }

      // Muat data bahan olahan aktif hanya jika terdapat komponen turunan
      if (components.any((c) => c.isProcessed)) {
        final allProcessed = await _processedRepo.getAll(status: null);
        for (final p in allProcessed) {
          if (p.id != null && p.id != item.id) {
            procMap[p.id!] = p;
            final c = await _processedRepo.getComponents(p.id!);
            procCompMap[p.id!] = c;
            for (final childComp in c) {
              if (childComp.ingredientId != null &&
                  !pricesMap.containsKey(childComp.ingredientId!)) {
                final pPrices = await _priceRepo.getPrices(
                  childComp.ingredientId!,
                );
                pricesMap[childComp.ingredientId!] = pPrices;
                final pIng = await _ingredientRepo.getById(
                  childComp.ingredientId!,
                );
                if (pIng != null) {
                  namesMap[childComp.ingredientId!] = pIng.name;
                }
              }
            }
          }
        }
      }

      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      final calcResult =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: item,
            components: components,
            pricesByIngredientId: pricesMap,
            ingredientNamesById: namesMap,
            processedIngredientsById: procMap,
            processedComponentsById: procCompMap,
            calculationDate: nowStr,
          );

      if (mounted) {
        setState(() {
          _item = item;
          _components = components;
          _costResult = calcResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFeedback('Gagal memuat detail bahan olahan.', isError: true);
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

  Future<void> _openEditForm() async {
    if (_item == null) return;

    final result = await ProcessedIngredientFormSheet.show(
      context,
      initialProcessedIngredient: _item,
      initialComponents: _components,
      processedRepository: _processedRepo,
      ingredientRepository: _ingredientRepo,
      priceRepository: _priceRepo,
      onSave:
          ({
            required name,
            required resultQuantity,
            required resultUnit,
            required components,
          }) async {
            await _processedRepo.update(
              _item!.id!,
              name: name,
              resultQuantity: resultQuantity,
              resultUnit: resultUnit,
              components: components,
            );
          },
    );

    if (result == true) {
      _showFeedback('Bahan olahan berhasil diperbarui.');
      await _loadData();
    }
  }

  Future<void> _confirmDeactivate() async {
    if (_item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan bahan olahan?'),
        content: Text(
          'Bahan olahan "${_item!.name}" akan dipindahkan ke daftar nonaktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _processedRepo.deactivate(_item!.id!);
        _showFeedback('Bahan olahan dinonaktifkan.');
        await _loadData();
      } catch (e) {
        _showFeedback('Gagal menonaktifkan: $e', isError: true);
      }
    }
  }

  Future<void> _activateItem() async {
    if (_item == null) return;

    try {
      await _processedRepo.activate(_item!.id!);
      _showFeedback('Bahan olahan berhasil diaktifkan kembali.');
      await _loadData();
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Bahan Olahan')),
        body: const Center(child: Text('Memuat detail bahan olahan...')),
      );
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Bahan Olahan')),
        body: const Center(child: Text('Bahan olahan tidak ditemukan.')),
      );
    }

    final item = _item!;
    final isActive = item.isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (isActive)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) {
                if (action == 'edit') {
                  _openEditForm();
                } else if (action == 'deactivate') {
                  _confirmDeactivate();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Nonaktifkan'),
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
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Resep & Komponen',
                  onPressed: _openEditForm,
                ),
                IconButton(
                  icon: const Icon(Icons.replay_rounded),
                  tooltip: 'Aktifkan Kembali',
                  onPressed: _activateItem,
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            _buildHeaderCard(context, item),
            const SizedBox(height: 16),

            // Cost Summary Card
            _buildCostSummaryCard(context, item),
            const SizedBox(height: 24),

            // Komposisi Komponen Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Komposisi Komponen',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_components.length} Komponen',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of components
            ...List.generate(_components.length, (index) {
              final comp = _components[index];
              final res = _costResult?.componentResults.elementAtOrNull(index);
              return _buildComponentItemCard(context, comp, res);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, ProcessedIngredient item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = item.isActive;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary.withAlpha(25)
                    : colorScheme.outline.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive ? Icons.blender_outlined : Icons.blender_rounded,
                size: 28,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary.withAlpha(30)
                              : colorScheme.outline.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Aktif' : 'Nonaktif',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.onSurface.withAlpha(140),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hasil Jadi: ${item.formattedResultQuantity} ${item.resultUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withAlpha(160),
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

  Widget _buildCostSummaryCard(BuildContext context, ProcessedIngredient item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final costResult = _costResult;

    if (costResult == null) {
      return const SizedBox.shrink();
    }

    final totalText = CurrencyFormatter.formatRupiah(
      costResult.totalCost.round(),
    );
    final perUnitText = CurrencyFormatter.formatCostPerBaseUnit(
      costResult.costPerResultUnit,
      item.resultUnit,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Ringkasan Modal Olahan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Modal Resep:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(180),
                ),
              ),
              Text(
                totalText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modal per Satuan Hasil:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withAlpha(180),
                ),
              ),
              Text(
                perUnitText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (costResult.hasUnresolvedCost) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.error.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sebagian komponen belum memiliki harga aktif yang valid. Total modal di atas belum mencakup seluruh komponen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentItemCard(
    BuildContext context,
    ProcessedComponent comp,
    ComponentCostResult? result,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIngredient =
        comp.componentType == ProcessedComponent.typeIngredient;
    final isProcessed = comp.componentType == ProcessedComponent.typeProcessed;

    final String title;
    final String subtext;
    final IconData iconData;
    final Color iconBgColor;
    final Color iconColor;

    if (isIngredient) {
      title = comp.ingredientName ?? 'Bahan Mentah';
      subtext = 'Penggunaan: ${comp.formattedQuantity} ${comp.unit}';
      iconData = Icons.inventory_2_outlined;
      iconBgColor = colorScheme.primary.withAlpha(20);
      iconColor = colorScheme.primary;
    } else if (isProcessed) {
      title = comp.childProcessedName ?? 'Bahan Olahan';
      subtext =
          'Bahan Olahan • Penggunaan: ${comp.formattedQuantity} ${comp.unit}';
      iconData = Icons.blender_outlined;
      iconBgColor = colorScheme.tertiary.withAlpha(25);
      iconColor = colorScheme.tertiary;
    } else {
      title = comp.label != null && comp.label!.isNotEmpty
          ? comp.label!
          : 'Biaya Lainnya / Pelengkap';
      subtext = 'Biaya utilitas / operasional olahan';
      iconData = Icons.attach_money_rounded;
      iconBgColor = colorScheme.secondary.withAlpha(20);
      iconColor = colorScheme.secondary;
    }

    final costText = result != null && result.isResolvable
        ? CurrencyFormatter.formatRupiah(result.calculatedCost.round())
        : (isIngredient || isProcessed ? 'Belum ada harga' : 'Rp0');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                  if (result != null && !result.isResolvable) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.errorMessage ?? 'Gagal menghitung biaya',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              costText,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: result != null && result.isResolvable
                    ? colorScheme.primary
                    : colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
