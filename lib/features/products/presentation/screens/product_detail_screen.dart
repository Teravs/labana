import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_stat_card.dart';
import '../../../ingredients/data/ingredient_price_repository.dart';
import '../../../ingredients/data/ingredient_repository.dart';
import '../../../ingredients/models/ingredient_price.dart';
import '../../../processed_ingredients/data/processed_ingredient_repository.dart';
import '../../../processed_ingredients/models/processed_component.dart';
import '../../../processed_ingredients/models/processed_ingredient.dart';
import '../../data/product_price_repository.dart';
import '../../data/product_repository.dart';
import '../../data/recipe_item_repository.dart';
import '../../data/recipe_version_repository.dart';
import '../../models/product.dart';
import '../../models/product_price.dart';
import '../../models/recipe_item.dart';
import '../../models/recipe_version.dart';
import '../../services/recipe_calculator.dart';
import '../widgets/product_form_sheet.dart';

/// Halaman detail produk minuman: menampilkan resep aktif, rincian komponen,
/// estimasi laba, riwayat versi resep, dan riwayat harga jual.
class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final ProductRepository? productRepository;
  final RecipeVersionRepository? recipeVersionRepository;
  final RecipeItemRepository? recipeItemRepository;
  final ProductPriceRepository? productPriceRepository;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? ingredientPriceRepository;
  final ProcessedIngredientRepository? processedRepository;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.productRepository,
    this.recipeVersionRepository,
    this.recipeItemRepository,
    this.productPriceRepository,
    this.ingredientRepository,
    this.ingredientPriceRepository,
    this.processedRepository,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductRepository _productRepo;
  late final RecipeVersionRepository _recipeVersionRepo;
  late final RecipeItemRepository _recipeItemRepo;
  late final ProductPriceRepository _productPriceRepo;
  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _ingredientPriceRepo;
  late final ProcessedIngredientRepository _processedRepo;

  Product? _product;
  RecipeVersion? _activeVersion;
  List<RecipeItem> _activeItems = [];
  ProductPrice? _currentPrice;
  List<RecipeVersion> _allVersions = [];
  List<ProductPrice> _priceHistory = [];

  RecipeCalculationResult? _calcResult;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _productRepo = widget.productRepository ?? ProductRepository();
    _recipeVersionRepo =
        widget.recipeVersionRepository ?? RecipeVersionRepository();
    _recipeItemRepo = widget.recipeItemRepository ?? RecipeItemRepository();
    _productPriceRepo =
        widget.productPriceRepository ?? ProductPriceRepository();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _ingredientPriceRepo =
        widget.ingredientPriceRepository ?? IngredientPriceRepository();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();

    _loadData();
  }

  Future<void> _loadData({bool isInitial = false}) async {
    if (isInitial || _product == null) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        _productRepo.getById(widget.productId),
        _recipeVersionRepo.getActiveVersion(widget.productId),
        _recipeVersionRepo.getByProductId(widget.productId),
        _productPriceRepo.getByProductId(widget.productId),
        _productPriceRepo.getEffectivePrice(widget.productId),
      ]);

      final product = results[0] as Product?;
      if (product == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Produk tidak ditemukan.';
          });
        }
        return;
      }

      var activeVersion = results[1] as RecipeVersion?;
      var allVersions = results[2] as List<RecipeVersion>;
      final priceHistory = results[3] as List<ProductPrice>;
      final currentPrice = results[4] as ProductPrice?;

      List<RecipeItem> activeItems = [];
      RecipeCalculationResult? calcResult;

      if (activeVersion != null && activeVersion.id != null) {
        var currentActive = activeVersion;
        activeItems = await _recipeItemRepo.getByRecipeVersionId(
          currentActive.id!,
        );

        // Siapkan data lookup untuk kalkulasi HPP secara efisien
        final pricesMap = <int, List<IngredientPrice>>{};
        final procMap = <int, ProcessedIngredient>{};
        final procCompMap = <int, List<ProcessedComponent>>{};
        final ingPriceFutures = <Future>[];
        final procIds = <int>{};

        for (final item in activeItems) {
          if (item.isIngredient && item.ingredientId != null) {
            ingPriceFutures.add(
              _ingredientPriceRepo.getPrices(item.ingredientId!).then((prices) {
                pricesMap[item.ingredientId!] = prices;
              }),
            );
          } else if (item.isProcessed && item.processedIngredientId != null) {
            procIds.add(item.processedIngredientId!);
          }
        }

        if (procIds.isNotEmpty) {
          final allProcessed = await _processedRepo.getAll();
          for (final pi in allProcessed) {
            if (pi.id != null) {
              procMap[pi.id!] = pi;
              final comps = await _processedRepo.getComponents(pi.id!);
              procCompMap[pi.id!] = comps;
              for (final c in comps) {
                if (c.ingredientId != null &&
                    !pricesMap.containsKey(c.ingredientId!)) {
                  ingPriceFutures.add(
                    _ingredientPriceRepo
                        .getPrices(c.ingredientId!)
                        .then((prices) {
                          pricesMap[c.ingredientId!] = prices;
                        }),
                  );
                }
              }
            }
          }
        }

        if (ingPriceFutures.isNotEmpty) {
          await Future.wait(ingPriceFutures);
        }

        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final calcDate = currentActive.effectiveFrom.compareTo(todayStr) > 0
            ? currentActive.effectiveFrom
            : todayStr;

        calcResult = RecipeCalculator.calculateRecipeCost(
          items: activeItems,
          calculationDate: calcDate,
          ingredientPricesMap: pricesMap,
          allProcessedIngredients: procMap,
          allProcessedComponents: procCompMap,
        );

        if (calcResult.hppTotal > 0 &&
            !calcResult.hasUnresolvedCost &&
            currentActive.hppTotal != calcResult.hppTotal) {
          await _recipeVersionRepo.updateHppTotal(
            currentActive.id!,
            calcResult.hppTotal,
          );
          currentActive = currentActive.copyWith(hppTotal: calcResult.hppTotal);
          activeVersion = currentActive;
          allVersions = allVersions.map((v) {
            if (v.id == currentActive.id) return currentActive;
            return v;
          }).toList();
        }
      }

      if (mounted) {
        setState(() {
          _product = product;
          _activeVersion = activeVersion;
          _activeItems = activeItems;
          _allVersions = allVersions;
          _priceHistory = priceHistory;
          _currentPrice = currentPrice;
          _calcResult = calcResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data produk: $e';
        });
      }
    }
  }

  Future<void> _openEditSheet() async {
    if (_product == null) return;

    final updated = await ProductFormSheet.show(
      context,
      initialProduct: _product,
      initialRecipeVersion: _activeVersion,
      initialItems: _activeItems,
      initialPrice: _currentPrice,
      productRepository: _productRepo,
      ingredientRepository: _ingredientRepo,
      priceRepository: _ingredientPriceRepo,
      processedRepository: _processedRepo,
      onSave:
          ({
            required String name,
            required List<RecipeItem> recipeItems,
            required int sellingPrice,
            required String effectiveDate,
            required int hppTotal,
          }) async {
            await _productRepo.updateProductWithRecipeAndPrice(
              productId: _product!.id!,
              name: name,
              recipeItems: recipeItems,
              sellingPrice: sellingPrice,
              effectiveDate: effectiveDate,
              hppTotal: hppTotal,
            );
          },
    );

    if (updated == true) {
      _showFeedback('Perubahan produk berhasil disimpan.');
      await _loadData();
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

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Produk?'),
        content: Text(
          'Produk "${_product?.name}" tidak akan muncul dalam daftar menu aktif, namun resep dan riwayat penjualannya tetap aman tersimpan.',
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
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && _product?.id != null) {
      try {
        await _productRepo.deactivate(_product!.id!);
        _showFeedback('Produk dinonaktifkan.');
        await _loadData();
      } catch (e) {
        _showFeedback('Gagal menonaktifkan: $e', isError: true);
      }
    }
  }

  Future<void> _activateProduct() async {
    if (_product?.id == null) return;
    try {
      await _productRepo.activate(_product!.id!);
      _showFeedback('Produk berhasil diaktifkan kembali.');
      await _loadData();
    } catch (e) {
      _showFeedback(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Detail Produk'),
        actions: [
          if (_product != null && _product!.isActive)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _openEditSheet();
                if (val == 'deactivate') _confirmDeactivate();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
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
          else if (_product != null && _product!.isInactive)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit Produk & Resep',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _openEditSheet,
                ),
                TextButton.icon(
                  onPressed: _activateProduct,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Aktifkan'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: Text('Memuat data produk...'))
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = _product!;

    final sellingPrice = _currentPrice?.sellingPrice ?? 0;
    final hpp = _calcResult?.hppTotal ?? _activeVersion?.hppTotal ?? 0;
    final profit = sellingPrice - hpp;
    final isBelowHpp = sellingPrice > 0 && sellingPrice < hpp;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: product.isActive
                      ? colorScheme.primary.withAlpha(25)
                      : colorScheme.outline.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.isActive ? 'Produk Aktif' : 'Produk Nonaktif',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: product.isActive
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                ),
              ),
              const Spacer(),
              if (_activeVersion != null)
                Text(
                  _activeVersion!.versionLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Ringkasan Keuangan (Stat Cards)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              AppStatCard(
                title: 'Harga Jual',
                value: _currentPrice != null
                    ? CurrencyFormatter.formatRupiah(sellingPrice)
                    : 'Belum diatur',
                icon: Icons.payments_outlined,
              ),
              AppStatCard(
                title: 'Modal / HPP',
                value: CurrencyFormatter.formatRupiah(hpp),
                icon: Icons.account_balance_wallet_outlined,
              ),
              AppStatCard(
                title: 'Estimasi Laba',
                value: CurrencyFormatter.formatRupiah(profit),
                icon: Icons.trending_up_rounded,
                iconColor: isBelowHpp ? colorScheme.error : AppColors.accent,
              ),
              AppStatCard(
                title: 'Margin Laba',
                value: sellingPrice > 0
                    ? '${((profit / sellingPrice) * 100).toStringAsFixed(1)}%'
                    : '0%',
                icon: Icons.pie_chart_outline_rounded,
              ),
            ],
          ),

          if (isBelowHpp) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.error.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Perhatian: Harga jual berada di bawah HPP resep.',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Section: Resep Aktif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Komposisi Resep',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_activeVersion != null)
                Text(
                  'Efektif: ${_activeVersion!.effectiveFrom}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_activeItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Belum ada item resep.'),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeItems.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _activeItems[index];
                final itemCostRes =
                    _calcResult?.itemResults.length == _activeItems.length
                    ? _calcResult!.itemResults[index]
                    : null;

                return _buildRecipeItemRow(context, item, itemCostRes);
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total HPP Resep',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatRupiah(hpp),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Section: Riwayat Versi Resep
          Text(
            'Riwayat Versi Resep',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allVersions.length,
            separatorBuilder: (context, i) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final v = _allVersions[index];
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withAlpha(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: colorScheme.outline.withAlpha(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Text(
                        v.versionLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: v.isActive
                              ? colorScheme.primary.withAlpha(30)
                              : colorScheme.outline.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          v.isActive ? 'Aktif' : 'Arsip',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: v.isActive
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'HPP: ${v.formattedHppTotal}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Tgl: ${v.effectiveFrom}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
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
          const SizedBox(height: 28),

          // Section: Riwayat Harga Jual
          Text(
            'Riwayat Harga Jual',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_priceHistory.isEmpty)
            const Text('Belum ada riwayat harga.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _priceHistory.length,
              separatorBuilder: (context, i) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final p = _priceHistory[index];
                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest.withAlpha(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: colorScheme.outline.withAlpha(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mulai ${p.effectiveFrom}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          p.formattedSellingPrice,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRecipeItemRow(
    BuildContext context,
    RecipeItem item,
    RecipeItemCostResult? costResult,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outline.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Ikon penanda tipe
            Icon(
              item.isIngredient
                  ? Icons.grain_outlined
                  : item.isProcessed
                  ? Icons.blender_outlined
                  : Icons.receipt_outlined,
              size: 20,
              color: item.isProcessed
                  ? colorScheme.secondary
                  : colorScheme.primary,
            ),
            const SizedBox(width: 10),

            // Deskripsi & Kuantitas
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isProcessed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Bahan Olahan',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!item.isOther)
                    Text(
                      item.formattedQuantity,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),

            // Subtotal biaya
            Text(
              costResult != null
                  ? CurrencyFormatter.formatRupiah(
                      costResult.calculatedCost.round(),
                    )
                  : (item.otherCost != null
                        ? CurrencyFormatter.formatRupiah(item.otherCost!)
                        : '—'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
