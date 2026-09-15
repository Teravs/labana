import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../ingredients/data/ingredient_price_repository.dart';
import '../../../ingredients/data/ingredient_repository.dart';
import '../../../ingredients/models/ingredient.dart';
import '../../../ingredients/models/ingredient_price.dart';
import '../../../processed_ingredients/data/processed_ingredient_repository.dart';
import '../../../processed_ingredients/models/processed_component.dart';
import '../../../processed_ingredients/models/processed_ingredient.dart';
import '../../data/product_repository.dart';
import '../../models/product.dart';
import '../../models/product_price.dart';
import '../../models/recipe_item.dart';
import '../../models/recipe_version.dart';
import '../../services/recipe_calculator.dart';

class _RecipeComponentEntry {
  String type; // 'ingredient', 'processed', 'other'
  int? ingredientId;
  int? processedIngredientId;
  final TextEditingController quantityController;
  String unit;
  final TextEditingController otherCostController;
  final TextEditingController labelController;

  _RecipeComponentEntry({
    required this.type,
    this.ingredientId,
    this.processedIngredientId,
    String initialQuantity = '',
    this.unit = 'g',
    String initialOtherCost = '',
    String initialLabel = '',
  }) : quantityController = TextEditingController(text: initialQuantity),
       otherCostController = TextEditingController(text: initialOtherCost),
       labelController = TextEditingController(text: initialLabel);

  void dispose() {
    quantityController.dispose();
    otherCostController.dispose();
    labelController.dispose();
  }
}

/// Modal form sheet untuk menambah atau mengedit produk minuman beserta resep dan harga jual.
class ProductFormSheet extends StatefulWidget {
  final Product? initialProduct;
  final RecipeVersion? initialRecipeVersion;
  final List<RecipeItem>? initialItems;
  final ProductPrice? initialPrice;
  final ProductRepository? productRepository;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? priceRepository;
  final ProcessedIngredientRepository? processedRepository;
  final Future<void> Function({
    required String name,
    required List<RecipeItem> recipeItems,
    required int sellingPrice,
    required String effectiveDate,
    required int hppTotal,
  })
  onSave;

  const ProductFormSheet({
    super.key,
    this.initialProduct,
    this.initialRecipeVersion,
    this.initialItems,
    this.initialPrice,
    this.productRepository,
    this.ingredientRepository,
    this.priceRepository,
    this.processedRepository,
    required this.onSave,
  });

  static Future<bool?> show(
    BuildContext context, {
    Product? initialProduct,
    RecipeVersion? initialRecipeVersion,
    List<RecipeItem>? initialItems,
    ProductPrice? initialPrice,
    ProductRepository? productRepository,
    IngredientRepository? ingredientRepository,
    IngredientPriceRepository? priceRepository,
    ProcessedIngredientRepository? processedRepository,
    required Future<void> Function({
      required String name,
      required List<RecipeItem> recipeItems,
      required int sellingPrice,
      required String effectiveDate,
      required int hppTotal,
    })
    onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => ProductFormSheet(
            initialProduct: initialProduct,
            initialRecipeVersion: initialRecipeVersion,
            initialItems: initialItems,
            initialPrice: initialPrice,
            productRepository: productRepository,
            ingredientRepository: ingredientRepository,
            priceRepository: priceRepository,
            processedRepository: processedRepository,
            onSave: onSave,
          ),
    );
  }

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sellingPriceController;
  late String _effectiveDate;

  final List<_RecipeComponentEntry> _componentEntries = [];

  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _priceRepo;
  late final ProcessedIngredientRepository _processedRepo;

  List<Ingredient> _activeIngredients = [];
  List<ProcessedIngredient> _activeProcessed = [];
  Map<int, List<IngredientPrice>> _pricesMap = {};
  Map<int, ProcessedIngredient> _processedMap = {};
  Map<int, List<ProcessedComponent>> _processedComponentsMap = {};

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  RecipeCalculationResult _calcResult = const RecipeCalculationResult(
    itemResults: [],
    totalCost: 0,
    hppTotal: 0,
    hasUnresolvedCost: false,
    warnings: [],
  );

  @override
  void initState() {
    super.initState();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();

    _nameController = TextEditingController(
      text: widget.initialProduct?.name ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: widget.initialPrice != null ? '${widget.initialPrice!.sellingPrice}' : '',
    );
    _effectiveDate =
        widget.initialRecipeVersion?.effectiveFrom ??
        widget.initialPrice?.effectiveFrom ??
        DateTime.now().toUtc().toIso8601String().substring(0, 10);

    // Inisialisasi komponen yang sudah ada jika edit
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      for (final item in widget.initialItems!) {
        _componentEntries.add(
          _RecipeComponentEntry(
            type: item.componentType,
            ingredientId: item.ingredientId,
            processedIngredientId: item.processedIngredientId,
            initialQuantity:
                item.quantity != null
                    ? (item.quantity! % 1 == 0
                        ? item.quantity!.toInt().toString()
                        : item.quantity!.toString())
                    : '',
            unit: item.unit ?? 'g',
            initialOtherCost:
                item.otherCost != null ? item.otherCost!.toString() : '',
            initialLabel: item.label ?? '',
          ),
        );
      }
    }

    _loadMasterData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    for (final entry in _componentEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    try {
      final ingredients = await _ingredientRepo.getAll(status: 'active');
      final processed = await _processedRepo.getAll(status: 'active');

      final pricesMap = <int, List<IngredientPrice>>{};
      for (final ing in ingredients) {
        if (ing.id != null) {
          pricesMap[ing.id!] = await _priceRepo.getPrices(ing.id!);
        }
      }

      final procMap = <int, ProcessedIngredient>{};
      final procCompMap = <int, List<ProcessedComponent>>{};
      for (final pi in processed) {
        if (pi.id != null) {
          procMap[pi.id!] = pi;
          procCompMap[pi.id!] = await _processedRepo.getComponents(pi.id!);
        }
      }

      if (mounted) {
        setState(() {
          _activeIngredients = ingredients;
          _activeProcessed = processed;
          _pricesMap = pricesMap;
          _processedMap = procMap;
          _processedComponentsMap = procCompMap;
          _isLoadingData = false;

          // Jika mode buat baru dan komponen masih kosong, beri default 1 komponen bahan mentah jika ada
          if (_componentEntries.isEmpty && _activeIngredients.isNotEmpty) {
            final firstIngId = _activeIngredients.first.id;
            final defaultUnit =
                (firstIngId != null
                    ? pricesMap[firstIngId]?.firstOrNull?.baseUnit
                    : null) ??
                'g';
            _componentEntries.add(
              _RecipeComponentEntry(
                type: RecipeItem.typeIngredient,
                ingredientId: firstIngId,
                unit: defaultUnit,
              ),
            );
          }
        });
        _recalculate();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Gagal memuat bahan: $e';
        });
      }
    }
  }

  void _recalculate() {
    final draftItems = <RecipeItem>[];

    for (final entry in _componentEntries) {
      if (entry.type == RecipeItem.typeIngredient) {
        final qty = double.tryParse(entry.quantityController.text.trim()) ?? 0;
        draftItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeIngredient,
            ingredientId: entry.ingredientId,
            quantity: qty,
            unit: entry.unit,
            createdAt: _effectiveDate,
          ),
        );
      } else if (entry.type == RecipeItem.typeProcessed) {
        final qty = double.tryParse(entry.quantityController.text.trim()) ?? 0;
        draftItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: entry.processedIngredientId,
            quantity: qty,
            unit: entry.unit,
            createdAt: _effectiveDate,
          ),
        );
      } else if (entry.type == RecipeItem.typeOther) {
        final cost = int.tryParse(entry.otherCostController.text.trim()) ?? 0;
        draftItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeOther,
            otherCost: cost,
            createdAt: _effectiveDate,
            label: entry.labelController.text.trim(),
          ),
        );
      }
    }

    final res = RecipeCalculator.calculateRecipeCost(
      items: draftItems,
      calculationDate: _effectiveDate,
      ingredientPricesMap: _pricesMap,
      allProcessedIngredients: _processedMap,
      allProcessedComponents: _processedComponentsMap,
    );

    if (mounted) {
      setState(() {
        _calcResult = res;
      });
    }
  }

  void _addIngredientComponent() {
    setState(() {
      final defaultIng =
          _activeIngredients.isNotEmpty ? _activeIngredients.first : null;
      final defaultUnit =
          (defaultIng?.id != null
              ? _pricesMap[defaultIng!.id!]?.firstOrNull?.baseUnit
              : null) ??
          'g';
      _componentEntries.add(
        _RecipeComponentEntry(
          type: RecipeItem.typeIngredient,
          ingredientId: defaultIng?.id,
          unit: defaultUnit,
        ),
      );
    });
    _recalculate();
  }

  void _addProcessedComponent() {
    setState(() {
      final defaultProc =
          _activeProcessed.isNotEmpty ? _activeProcessed.first : null;
      _componentEntries.add(
        _RecipeComponentEntry(
          type: RecipeItem.typeProcessed,
          processedIngredientId: defaultProc?.id,
          unit: defaultProc?.resultUnit ?? 'ml',
        ),
      );
    });
    _recalculate();
  }

  void _addOtherComponent() {
    setState(() {
      _componentEntries.add(
        _RecipeComponentEntry(
          type: RecipeItem.typeOther,
          initialLabel: '',
          initialOtherCost: '',
        ),
      );
    });
    _recalculate();
  }

  void _removeComponent(int index) {
    setState(() {
      final removed = _componentEntries.removeAt(index);
      removed.dispose();
    });
    _recalculate();
  }

  Future<void> _pickEffectiveDate() async {
    final now = DateTime.now();
    final parts = _effectiveDate.split('-');
    DateTime initial = now;
    if (parts.length == 3) {
      initial =
          DateTime.tryParse(_effectiveDate) ??
          DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _effectiveDate = '$y-$m-$d';
      });
      _recalculate();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_componentEntries.isEmpty) {
      setState(() {
        _errorMessage = 'Resep minimal harus memiliki 1 komponen.';
      });
      return;
    }

    final sellingPrice =
        int.tryParse(_sellingPriceController.text.trim()) ?? -1;
    if (sellingPrice < 0) {
      setState(() {
        _errorMessage = 'Harga jual tidak boleh negatif.';
      });
      return;
    }

    final finalItems = <RecipeItem>[];
    for (int i = 0; i < _componentEntries.length; i++) {
      final entry = _componentEntries[i];
      if (entry.type == RecipeItem.typeIngredient) {
        if (entry.ingredientId == null) {
          setState(() {
            _errorMessage = 'Bahan mentah pada komponen #${i + 1} belum dipilih.';
          });
          return;
        }
        final qty = double.tryParse(entry.quantityController.text.trim());
        if (qty == null || qty <= 0) {
          setState(() {
            _errorMessage =
                'Jumlah pemakaian pada komponen #${i + 1} harus lebih dari 0.';
          });
          return;
        }
        finalItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeIngredient,
            ingredientId: entry.ingredientId,
            quantity: qty,
            unit: entry.unit,
            createdAt: _effectiveDate,
          ),
        );
      } else if (entry.type == RecipeItem.typeProcessed) {
        if (entry.processedIngredientId == null) {
          setState(() {
            _errorMessage =
                'Bahan olahan pada komponen #${i + 1} belum dipilih.';
          });
          return;
        }
        final qty = double.tryParse(entry.quantityController.text.trim());
        if (qty == null || qty <= 0) {
          setState(() {
            _errorMessage =
                'Jumlah pemakaian pada komponen #${i + 1} harus lebih dari 0.';
          });
          return;
        }
        finalItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeProcessed,
            processedIngredientId: entry.processedIngredientId,
            quantity: qty,
            unit: entry.unit,
            createdAt: _effectiveDate,
          ),
        );
      } else if (entry.type == RecipeItem.typeOther) {
        final cost = int.tryParse(entry.otherCostController.text.trim());
        if (cost == null || cost < 0) {
          setState(() {
            _errorMessage =
                'Nominal biaya lainnya pada komponen #${i + 1} tidak boleh negatif.';
          });
          return;
        }
        finalItems.add(
          RecipeItem(
            recipeVersionId: 0,
            componentType: RecipeItem.typeOther,
            otherCost: cost,
            createdAt: _effectiveDate,
            label: entry.labelController.text.trim(),
          ),
        );
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        recipeItems: finalItems,
        sellingPrice: sellingPrice,
        effectiveDate: _effectiveDate,
        hppTotal: _calcResult.hppTotal,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEdit = widget.initialProduct != null;

    final sellingPrice =
        int.tryParse(_sellingPriceController.text.trim()) ?? 0;
    final hpp = _calcResult.hppTotal;
    final profit = sellingPrice - hpp;
    final isBelowHpp = sellingPrice > 0 && sellingPrice < hpp;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child:
            _isLoadingData
                ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colorScheme.outline.withAlpha(80),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Title
                        Text(
                          isEdit ? 'Edit Produk' : 'Tambah Produk Baru',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pesan Error jika ada
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Section 1: Nama Produk
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Produk',
                            hintText: 'Contoh: Es Teh Manis',
                            prefixIcon: Icon(Icons.local_cafe_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Nama produk wajib diisi.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Komposisi Resep
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Komposisi Resep',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_componentEntries.length} Komponen',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tombol Tambah Komponen (Wrap 3 Tombol)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _addIngredientComponent,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Bahan Mentah'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _addProcessedComponent,
                              icon: const Icon(Icons.blender_outlined, size: 16),
                              label: const Text('Bahan Olahan'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _addOtherComponent,
                              icon: const Icon(Icons.receipt_outlined, size: 16),
                              label: const Text('Biaya Lainnya'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Daftar Kartu Komponen
                        if (_componentEntries.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: Text(
                              'Belum ada komponen resep. Tambahkan minimal 1 komponen.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _componentEntries.length,
                            separatorBuilder:
                                (context, i) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildComponentCard(context, index);
                            },
                          ),
                        const SizedBox(height: 20),

                        // Section 3: Live Preview Estimasi HPP
                        Container(
                          padding: const EdgeInsets.all(16),
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
                                    Icons.analytics_outlined,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estimasi HPP Resep',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.formatRupiah(
                                  _calcResult.hppTotal,
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (_calcResult.hasUnresolvedCost) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Perhatian: Sebagian harga bahan belum lengkap.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 4: Harga Jual & Tanggal Efektif
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _sellingPriceController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Harga Jual (Rp)',
                                  hintText: 'Contoh: 5000',
                                  prefixText: 'Rp',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Harga jual wajib diisi.';
                                  }
                                  final numVal = int.tryParse(val.trim());
                                  if (numVal == null || numVal < 0) {
                                    return 'Harga tidak valid.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _pickEffectiveDate,
                                borderRadius: BorderRadius.circular(8),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal Efektif',
                                    suffixIcon: Icon(
                                      Icons.calendar_today,
                                      size: 18,
                                    ),
                                  ),
                                  child: Text(
                                    _effectiveDate,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Section 5: Preview Laba
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                isBelowHpp
                                    ? colorScheme.errorContainer.withAlpha(60)
                                    : AppColors.accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isBelowHpp
                                      ? colorScheme.error.withAlpha(80)
                                      : AppColors.accent.withAlpha(60),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Estimasi Laba per Porsi',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isBelowHpp
                                              ? colorScheme.error
                                              : AppColors.accent,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatRupiah(profit),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color:
                                          isBelowHpp
                                              ? colorScheme.error
                                              : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                              if (isBelowHpp) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Peringatan: Harga jual berada di bawah HPP resep.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tombol Submit
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          child:
                              _isSubmitting
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    isEdit ? 'Simpan Perubahan' : 'Simpan Produk',
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildComponentCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entry = _componentEntries[index];

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Tag Tipe
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        entry.type == RecipeItem.typeIngredient
                            ? colorScheme.primary.withAlpha(30)
                            : entry.type == RecipeItem.typeProcessed
                            ? colorScheme.secondary.withAlpha(30)
                            : colorScheme.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.type == RecipeItem.typeIngredient
                        ? 'Bahan Mentah'
                        : entry.type == RecipeItem.typeProcessed
                        ? 'Bahan Olahan'
                        : 'Biaya Lainnya',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeComponent(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Hapus komponen',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Form berdasarkan Tipe
            if (entry.type == RecipeItem.typeIngredient) ...[
              // Dropdown Bahan Mentah
              DropdownButtonFormField<int>(
                initialValue: entry.ingredientId,
                decoration: const InputDecoration(
                  labelText: 'Pilih Bahan Mentah',
                  isDense: true,
                ),
                items:
                    _activeIngredients.map((ing) {
                      return DropdownMenuItem<int>(
                        value: ing.id,
                        child: Text(ing.name),
                      );
                    }).toList(),
                onChanged: (val) {
                  setState(() {
                    entry.ingredientId = val;
                    if (val != null) {
                      entry.unit =
                          _pricesMap[val]?.firstOrNull?.baseUnit ?? 'g';
                    }
                  });
                  _recalculate();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: entry.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Pemakaian',
                        isDense: true,
                      ),
                      onChanged: (_) => _recalculate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: entry.unit,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'liter', child: Text('liter')),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => entry.unit = val);
                          _recalculate();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else if (entry.type == RecipeItem.typeProcessed) ...[
              // Dropdown Bahan Olahan
              DropdownButtonFormField<int>(
                initialValue: entry.processedIngredientId,
                decoration: const InputDecoration(
                  labelText: 'Pilih Bahan Olahan',
                  isDense: true,
                ),
                items:
                    _activeProcessed.map((pi) {
                      return DropdownMenuItem<int>(
                        value: pi.id,
                        child: Text(pi.name),
                      );
                    }).toList(),
                onChanged: (val) {
                  setState(() {
                    entry.processedIngredientId = val;
                    final sel =
                        _activeProcessed
                            .where((pi) => pi.id == val)
                            .firstOrNull;
                    if (sel != null) {
                      entry.unit = sel.resultUnit;
                    }
                  });
                  _recalculate();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: entry.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Pemakaian',
                        isDense: true,
                      ),
                      onChanged: (_) => _recalculate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: entry.unit,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'liter', child: Text('liter')),
                        DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => entry.unit = val);
                          _recalculate();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else if (entry.type == RecipeItem.typeOther) ...[
              // Biaya Lainnya
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: entry.labelController,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan (Opsional)',
                        hintText: 'Cup / Sedotan / dll',
                        isDense: true,
                      ),
                      onChanged: (_) => _recalculate(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: entry.otherCostController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Nominal Biaya (Rp)',
                        prefixText: 'Rp',
                        isDense: true,
                      ),
                      onChanged: (_) => _recalculate(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

