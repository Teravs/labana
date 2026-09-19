import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../../ingredients/data/ingredient_price_repository.dart';
import '../../../ingredients/data/ingredient_repository.dart';
import '../../../ingredients/models/ingredient.dart';
import '../../../ingredients/models/ingredient_price.dart';
import '../../data/processed_ingredient_repository.dart';
import '../../models/processed_component.dart';
import '../../models/processed_ingredient.dart';
import '../../services/processed_ingredient_calculator.dart';

class _ComponentFormEntry {
  String type;
  int? ingredientId;
  int? childProcessedId;
  final TextEditingController quantityController;
  String unit;
  final TextEditingController otherCostController;
  final TextEditingController labelController;

  _ComponentFormEntry({
    required this.type,
    this.ingredientId,
    this.childProcessedId,
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

/// Modal bottom sheet untuk menambah atau mengedit bahan olahan beserta komponen resepnya.
class ProcessedIngredientFormSheet extends StatefulWidget {
  final ProcessedIngredient? initialProcessedIngredient;
  final List<ProcessedComponent>? initialComponents;
  final ProcessedIngredientRepository? processedRepository;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? priceRepository;
  final Future<void> Function({
    required String name,
    required double resultQuantity,
    required String resultUnit,
    required List<ProcessedComponent> components,
  })
  onSave;

  const ProcessedIngredientFormSheet({
    super.key,
    this.initialProcessedIngredient,
    this.initialComponents,
    this.processedRepository,
    this.ingredientRepository,
    this.priceRepository,
    required this.onSave,
  });

  static Future<bool?> show(
    BuildContext context, {
    ProcessedIngredient? initialProcessedIngredient,
    List<ProcessedComponent>? initialComponents,
    ProcessedIngredientRepository? processedRepository,
    IngredientRepository? ingredientRepository,
    IngredientPriceRepository? priceRepository,
    required Future<void> Function({
      required String name,
      required double resultQuantity,
      required String resultUnit,
      required List<ProcessedComponent> components,
    })
    onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ProcessedIngredientFormSheet(
        initialProcessedIngredient: initialProcessedIngredient,
        initialComponents: initialComponents,
        processedRepository: processedRepository,
        ingredientRepository: ingredientRepository,
        priceRepository: priceRepository,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ProcessedIngredientFormSheet> createState() =>
      _ProcessedIngredientFormSheetState();
}

class _ProcessedIngredientFormSheetState
    extends State<ProcessedIngredientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _resultQtyController;
  late String _resultUnit;

  late final ProcessedIngredientRepository _processedRepo;
  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _priceRepo;

  List<Ingredient> _availableRawIngredients = [];
  List<ProcessedIngredient> _availableProcessedCandidates = [];
  Map<int, List<IngredientPrice>> _pricesByIngredient = {};
  Map<int, String> _ingredientNamesById = {};
  Map<int, ProcessedIngredient> _processedIngredientsById = {};
  Map<int, List<ProcessedComponent>> _processedComponentsById = {};

  final List<_ComponentFormEntry> _components = [];

  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditMode => widget.initialProcessedIngredient != null;

  static const List<MapEntry<String, String>> _resultUnits = [
    MapEntry('ml', 'Mililiter (ml)'),
    MapEntry('g', 'Gram (g)'),
    MapEntry('pcs', 'Pcs'),
  ];

  static const List<MapEntry<String, String>> _componentUnits = [
    MapEntry('g', 'Gram (g)'),
    MapEntry('kg', 'Kilogram (kg)'),
    MapEntry('ml', 'Mililiter (ml)'),
    MapEntry('liter', 'Liter'),
    MapEntry('pcs', 'Pcs'),
  ];

  @override
  void initState() {
    super.initState();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();

    final initial = widget.initialProcessedIngredient;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _resultQtyController = TextEditingController(
      text: initial != null
          ? (initial.resultQuantity % 1 == 0
                ? initial.resultQuantity.toInt().toString()
                : initial.resultQuantity.toString())
          : '',
    );
    _resultUnit = initial?.resultUnit ?? 'ml';

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _resultQtyController.dispose();
    for (final c in _components) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final rawList = await _ingredientRepo.getAll(status: 'active');
      final namesMap = <int, String>{};
      final priceMap = <int, List<IngredientPrice>>{};

      for (final ing in rawList) {
        if (ing.id != null) {
          namesMap[ing.id!] = ing.name;
          final prices = await _priceRepo.getPrices(ing.id!);
          priceMap[ing.id!] = prices;
        }
      }

      // Load bahan olahan aktif & kandidat valid untuk mencegah circular dependency
      final allActiveProcessed = await _processedRepo.getAll(status: 'active');
      final validCandidates = await _processedRepo.getValidChildCandidates(
        currentProcessedId: widget.initialProcessedIngredient?.id,
      );
      final procMap = <int, ProcessedIngredient>{};
      final procCompMap = <int, List<ProcessedComponent>>{};

      for (final proc in allActiveProcessed) {
        if (proc.id != null) {
          procMap[proc.id!] = proc;
          final comps = await _processedRepo.getComponents(proc.id!);
          procCompMap[proc.id!] = comps;

          // Ambil harga bahan mentah yang dibutuhkan oleh olahan anak jika belum ada
          for (final c in comps) {
            if (c.ingredientId != null &&
                !priceMap.containsKey(c.ingredientId!)) {
              final prices = await _priceRepo.getPrices(c.ingredientId!);
              priceMap[c.ingredientId!] = prices;
              final ing = await _ingredientRepo.getById(c.ingredientId!);
              if (ing != null) {
                namesMap[c.ingredientId!] = ing.name;
              }
            }
          }
        }
      }

      // Proteksi bahan nonaktif: jika form edit membawa komponen yang saat ini nonaktif,
      // muat bahan tersebut dan sertakan dengan label (Nonaktif) agar DropdownButtonFormField tidak crash.
      if (widget.initialComponents != null) {
        for (final comp in widget.initialComponents!) {
          if (comp.isIngredient &&
              comp.ingredientId != null &&
              !namesMap.containsKey(comp.ingredientId)) {
            final inactiveIng = await _ingredientRepo.getById(comp.ingredientId!);
            if (inactiveIng != null) {
              final displayIng = inactiveIng.copyWith(
                name: '${inactiveIng.name} (Nonaktif)',
              );
              rawList.add(displayIng);
              namesMap[displayIng.id!] = displayIng.name;
              final prices = await _priceRepo.getPrices(displayIng.id!);
              priceMap[displayIng.id!] = prices;
            }
          } else if (comp.isProcessed &&
              comp.childProcessedId != null &&
              !procMap.containsKey(comp.childProcessedId)) {
            final inactiveProc = await _processedRepo.getById(comp.childProcessedId!);
            if (inactiveProc != null) {
              final displayProc = ProcessedIngredient(
                id: inactiveProc.id,
                name: '${inactiveProc.name} (Nonaktif)',
                resultQuantity: inactiveProc.resultQuantity,
                resultUnit: inactiveProc.resultUnit,
                status: inactiveProc.status,
                createdAt: inactiveProc.createdAt,
                updatedAt: inactiveProc.updatedAt,
              );
              validCandidates.add(displayProc);
              procMap[displayProc.id!] = displayProc;
              final comps = await _processedRepo.getComponents(displayProc.id!);
              procCompMap[displayProc.id!] = comps;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableRawIngredients = rawList;
          _availableProcessedCandidates = validCandidates;
          _processedIngredientsById = procMap;
          _processedComponentsById = procCompMap;
          _ingredientNamesById = namesMap;
          _pricesByIngredient = priceMap;

          // Inisialisasi komponen jika edit mode atau ada initial components
          if (widget.initialComponents != null &&
              widget.initialComponents!.isNotEmpty) {
            for (final comp in widget.initialComponents!) {
              _components.add(
                _ComponentFormEntry(
                  type: comp.componentType,
                  ingredientId: comp.ingredientId,
                  childProcessedId: comp.childProcessedId,
                  initialQuantity: comp.formattedQuantity ?? '',
                  unit:
                      comp.unit ??
                      (comp.isProcessed
                          ? (procMap[comp.childProcessedId]?.resultUnit ?? 'ml')
                          : 'g'),
                  initialOtherCost: comp.otherCost?.toString() ?? '',
                  initialLabel: comp.label ?? '',
                ),
              );
            }
          } else {
            // Default 1 komponen bahan mentah awal jika belum ada
            if (rawList.isNotEmpty) {
              final firstId = rawList.first.id;
              _components.add(
                _ComponentFormEntry(
                  type: ProcessedComponent.typeIngredient,
                  ingredientId: firstId,
                  unit: _getDefaultUnitForIngredient(firstId),
                ),
              );
            } else if (validCandidates.isNotEmpty) {
              _components.add(
                _ComponentFormEntry(
                  type: ProcessedComponent.typeProcessed,
                  childProcessedId: validCandidates.first.id,
                  unit: validCandidates.first.resultUnit,
                ),
              );
            }
          }

          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _errorMessage = 'Gagal memuat data: $e';
        });
      }
    }
  }

  String _getDefaultUnitForIngredient(int? ingredientId) {
    if (ingredientId == null) return 'g';
    final prices = _pricesByIngredient[ingredientId];
    if (prices != null && prices.isNotEmpty) {
      return prices.first.baseUnit;
    }
    return 'g';
  }

  List<MapEntry<String, String>> _getCompatibleUnitsForIngredient(
    int? ingredientId,
  ) {
    if (ingredientId == null) return _componentUnits;
    final prices = _pricesByIngredient[ingredientId];
    String baseUnit = 'g';
    if (prices != null && prices.isNotEmpty) {
      baseUnit = prices.first.baseUnit;
    }
    return _componentUnits
        .where((u) => UnitConverter.isCompatible(u.key, baseUnit))
        .toList();
  }

  void _addIngredientComponent() {
    if (_availableRawIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada bahan mentah aktif. Tambahkan bahan mentah terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    final firstId = _availableRawIngredients.first.id;
    setState(() {
      _components.add(
        _ComponentFormEntry(
          type: ProcessedComponent.typeIngredient,
          ingredientId: firstId,
          unit: _getDefaultUnitForIngredient(firstId),
        ),
      );
    });
  }

  void _addProcessedComponent() {
    if (_availableProcessedCandidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada bahan olahan yang dapat dipilih (atau untuk mencegah ketergantungan melingkar).',
          ),
        ),
      );
      return;
    }

    final firstCandidate = _availableProcessedCandidates.first;
    setState(() {
      _components.add(
        _ComponentFormEntry(
          type: ProcessedComponent.typeProcessed,
          childProcessedId: firstCandidate.id,
          unit: firstCandidate.resultUnit,
        ),
      );
    });
  }

  void _addOtherComponent() {
    setState(() {
      _components.add(
        _ComponentFormEntry(
          type: ProcessedComponent.typeOther,
          initialOtherCost: '0',
          initialLabel: '',
        ),
      );
    });
  }

  void _removeComponent(int index) {
    if (_components.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bahan olahan minimal harus memiliki 1 komponen.'),
        ),
      );
      return;
    }

    setState(() {
      final removed = _components.removeAt(index);
      removed.dispose();
    });
  }

  ProcessedIngredientCostResult _calculateLiveCost() {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final resultQty = double.tryParse(
          _resultQtyController.text.trim().replaceAll(',', '.'),
        ) ??
        1.0;

    final dummyProcessed = ProcessedIngredient(
      id: widget.initialProcessedIngredient?.id ?? 0,
      name: _nameController.text.trim(),
      resultQuantity: resultQty > 0 ? resultQty : 1.0,
      resultUnit: _resultUnit,
    );

    final parsedComponents = <ProcessedComponent>[];
    for (int i = 0; i < _components.length; i++) {
      final entry = _components[i];
      if (entry.type == ProcessedComponent.typeIngredient) {
        final qty = double.tryParse(
          entry.quantityController.text.trim().replaceAll(',', '.'),
        );
        parsedComponents.add(
          ProcessedComponent(
            id: i,
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: entry.ingredientId,
            quantity: qty ?? 0,
            unit: entry.unit,
            ingredientName: entry.ingredientId != null
                ? _ingredientNamesById[entry.ingredientId!]
                : null,
          ),
        );
      } else if (entry.type == ProcessedComponent.typeProcessed) {
        final qty = double.tryParse(
          entry.quantityController.text.trim().replaceAll(',', '.'),
        );
        final child = entry.childProcessedId != null
            ? _processedIngredientsById[entry.childProcessedId!]
            : null;
        parsedComponents.add(
          ProcessedComponent(
            id: i,
            componentType: ProcessedComponent.typeProcessed,
            childProcessedId: entry.childProcessedId,
            quantity: qty ?? 0,
            unit: entry.unit,
            childProcessedName: child?.name,
          ),
        );
      } else {
        final cost = int.tryParse(entry.otherCostController.text.trim());
        parsedComponents.add(
          ProcessedComponent(
            id: i,
            componentType: ProcessedComponent.typeOther,
            otherCost: cost ?? 0,
            label: entry.labelController.text.trim(),
          ),
        );
      }
    }

    return ProcessedIngredientCalculator.calculateProcessedIngredientCost(
      processedIngredient: dummyProcessed,
      components: parsedComponents,
      pricesByIngredientId: _pricesByIngredient,
      ingredientNamesById: _ingredientNamesById,
      processedIngredientsById: _processedIngredientsById,
      processedComponentsById: _processedComponentsById,
      calculationDate: nowStr,
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_components.isEmpty) {
      setState(() {
        _errorMessage = 'Bahan olahan minimal harus memiliki 1 komponen.';
      });
      return;
    }

    final resultQty = double.tryParse(
      _resultQtyController.text.trim().replaceAll(',', '.'),
    );
    if (resultQty == null || resultQty <= 0) {
      setState(() {
        _errorMessage = 'Jumlah hasil olahan harus lebih besar dari 0.';
      });
      return;
    }

    // Validasi isi komponen
    final parsedComponents = <ProcessedComponent>[];
    for (int i = 0; i < _components.length; i++) {
      final entry = _components[i];
      if (entry.type == ProcessedComponent.typeIngredient) {
        if (entry.ingredientId == null) {
          setState(() {
            _errorMessage = 'Pilih bahan mentah untuk semua komponen.';
          });
          return;
        }
        final qty = double.tryParse(
          entry.quantityController.text.trim().replaceAll(',', '.'),
        );
        if (qty == null || qty <= 0) {
          setState(() {
            _errorMessage =
                'Jumlah penggunaan bahan mentah harus lebih dari 0.';
          });
          return;
        }
        parsedComponents.add(
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: entry.ingredientId,
            quantity: qty,
            unit: entry.unit,
          ),
        );
      } else if (entry.type == ProcessedComponent.typeProcessed) {
        if (entry.childProcessedId == null) {
          setState(() {
            _errorMessage = 'Pilih bahan olahan untuk semua komponen.';
          });
          return;
        }
        final qty = double.tryParse(
          entry.quantityController.text.trim().replaceAll(',', '.'),
        );
        if (qty == null || qty <= 0) {
          setState(() {
            _errorMessage =
                'Jumlah penggunaan bahan olahan harus lebih dari 0.';
          });
          return;
        }
        parsedComponents.add(
          ProcessedComponent(
            componentType: ProcessedComponent.typeProcessed,
            childProcessedId: entry.childProcessedId,
            quantity: qty,
            unit: entry.unit,
          ),
        );
      } else {
        final cost = int.tryParse(entry.otherCostController.text.trim());
        if (cost == null || cost < 0) {
          setState(() {
            _errorMessage =
                'Biaya lainnya tidak boleh kosong atau bernilai negatif.';
          });
          return;
        }
        parsedComponents.add(
          ProcessedComponent(
            componentType: ProcessedComponent.typeOther,
            otherCost: cost,
            label: entry.labelController.text.trim(),
          ),
        );
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        resultQuantity: resultQty,
        resultUnit: _resultUnit,
        components: parsedComponents,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + keyboardHeight,
      ),
      child: _isLoadingInitial
          ? const SizedBox(
              height: 200,
              child: Center(child: Text('Memuat data formulir...')),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      _isEditMode ? 'Edit Bahan Olahan' : 'Tambah Bahan Olahan',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bahan olahan terdiri dari bahan mentah atau biaya pelengkap yang diolah.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.error.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Input Nama Bahan Olahan
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama bahan olahan',
                        hintText: 'Contoh: Simple Syrup, Milk Base',
                        prefixIcon: Icon(Icons.blender_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama bahan olahan wajib diisi.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Input Hasil Olahan (Kuantitas & Satuan)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _resultQtyController,
                            enabled: !_isSaving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[.,]?\d*'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Jumlah hasil jadi',
                              hintText: 'Misal: 750',
                              prefixIcon: Icon(Icons.scale_rounded),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Wajib diisi';
                              }
                              final numVal = double.tryParse(
                                value.replaceAll(',', '.'),
                              );
                              if (numVal == null || numVal <= 0) {
                                return 'Harus > 0';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _resultUnit,
                            decoration: const InputDecoration(
                              labelText: 'Satuan',
                            ),
                            items: _resultUnits.map((e) {
                              return DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              );
                            }).toList(),
                            onChanged: _isSaving
                                ? null
                                : (newVal) {
                                    if (newVal != null) {
                                      setState(() => _resultUnit = newVal);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section Komponen Olahan
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Komponen / Komposisi',
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

                    // Daftar Komponen
                    ...List.generate(_components.length, (index) {
                      final entry = _components[index];
                      return _buildComponentCard(entry, index);
                    }),

                    const SizedBox(height: 12),

                    // Tombol Tambah Komponen
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _addIngredientComponent,
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                          ),
                          label: const Text('Bahan Mentah'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _addProcessedComponent,
                          icon: const Icon(Icons.blender_outlined, size: 16),
                          label: const Text('Bahan Olahan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _addOtherComponent,
                          icon: const Icon(
                            Icons.attach_money_rounded,
                            size: 16,
                          ),
                          label: const Text('Biaya Lainnya'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Live Preview Ringkasan Modal
                    _buildLiveCostSummaryCard(),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _isSaving ? null : _handleSubmit,
                          child: Text(
                            _isSaving
                                ? 'Menyimpan...'
                                : (_isEditMode
                                      ? 'Simpan Perubahan'
                                      : 'Simpan Bahan Olahan'),
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

  Widget _buildComponentCard(_ComponentFormEntry entry, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIngredient = entry.type == ProcessedComponent.typeIngredient;
    final isProcessed = entry.type == ProcessedComponent.typeProcessed;

    final IconData headerIcon;
    final Color headerColor;
    final String headerTitle;

    if (isIngredient) {
      headerIcon = Icons.inventory_2_outlined;
      headerColor = colorScheme.primary;
      headerTitle = 'Bahan Mentah';
    } else if (isProcessed) {
      headerIcon = Icons.blender_outlined;
      headerColor = colorScheme.tertiary;
      headerTitle = 'Bahan Olahan';
    } else {
      headerIcon = Icons.attach_money_rounded;
      headerColor = colorScheme.secondary;
      headerTitle = 'Biaya Lainnya / Pelengkap';
    }

    // Untuk bahan olahan, siapkan opsi child (termasuk candidate valid & child yang sedang terpilih)
    final childOptions = <ProcessedIngredient>[];
    if (isProcessed) {
      final seenIds = <int>{};
      for (final cand in _availableProcessedCandidates) {
        if (cand.id != null) {
          seenIds.add(cand.id!);
          childOptions.add(cand);
        }
      }
      if (entry.childProcessedId != null &&
          !seenIds.contains(entry.childProcessedId) &&
          _processedIngredientsById.containsKey(entry.childProcessedId)) {
        childOptions.add(_processedIngredientsById[entry.childProcessedId]!);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar Komponen (Tipe & Hapus)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(headerIcon, size: 16, color: headerColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          headerTitle,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: headerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: colorScheme.error,
                  tooltip: 'Hapus komponen',
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSaving ? null : () => _removeComponent(index),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isIngredient) ...[
              // Dropdown Pilihan Bahan Mentah
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: entry.ingredientId,
                decoration: const InputDecoration(
                  labelText: 'Pilih bahan mentah',
                  isDense: true,
                ),
                items: _availableRawIngredients.map((ing) {
                  return DropdownMenuItem<int>(
                    value: ing.id,
                    child: Text(ing.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (val) {
                        setState(() {
                          entry.ingredientId = val;
                          if (val != null) {
                            final compatible = _getCompatibleUnitsForIngredient(
                              val,
                            );
                            if (!compatible.any((u) => u.key == entry.unit)) {
                              entry.unit = _getDefaultUnitForIngredient(val);
                            }
                          }
                        });
                      },
                validator: (val) {
                  if (val == null) return 'Pilih bahan mentah';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Input Kuantitas & Satuan Penggunaan
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: entry.quantityController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[.,]?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        hintText: 'Misal: 500',
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Isi jumlah';
                        }
                        final numVal = double.tryParse(val.replaceAll(',', '.'));
                        if (numVal == null || numVal <= 0) {
                          return 'Harus > 0';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Builder(
                    builder: (context) {
                      final compatibleUnits = _getCompatibleUnitsForIngredient(
                        entry.ingredientId,
                      );
                      final hasCurrentUnit = compatibleUnits.any(
                        (u) => u.key == entry.unit,
                      );
                      final currentVal = hasCurrentUnit
                          ? entry.unit
                          : (compatibleUnits.isNotEmpty
                                ? compatibleUnits.first.key
                                : entry.unit);

                      return Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: currentVal,
                          decoration: const InputDecoration(
                            labelText: 'Satuan',
                            isDense: true,
                          ),
                          items: compatibleUnits.map((u) {
                            return DropdownMenuItem(
                              value: u.key,
                              child: Text(u.value),
                            );
                          }).toList(),
                          onChanged: _isSaving
                              ? null
                              : (newUnit) {
                                  if (newUnit != null) {
                                    setState(() => entry.unit = newUnit);
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ] else if (isProcessed) ...[
              // Dropdown Pilihan Bahan Olahan
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: entry.childProcessedId,
                decoration: const InputDecoration(
                  labelText: 'Pilih bahan olahan',
                  isDense: true,
                ),
                items: childOptions.map((proc) {
                  return DropdownMenuItem<int>(
                    value: proc.id,
                    child: Text(
                      '${proc.name} (${proc.formattedResultQuantity} ${proc.resultUnit})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (val) {
                        setState(() {
                          entry.childProcessedId = val;
                          final child = val != null
                              ? _processedIngredientsById[val]
                              : null;
                          if (child != null) {
                            entry.unit = child.resultUnit;
                          }
                        });
                      },
                validator: (val) {
                  if (val == null) return 'Pilih bahan olahan';
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Input Kuantitas & Satuan Penggunaan
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: entry.quantityController,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*[.,]?\d*'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah',
                        hintText: 'Misal: 100',
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Isi jumlah';
                        }
                        final numVal = double.tryParse(val.replaceAll(',', '.'));
                        if (numVal == null || numVal <= 0) {
                          return 'Harus > 0';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: entry.unit,
                      decoration: const InputDecoration(
                        labelText: 'Satuan',
                        isDense: true,
                      ),
                      items: _componentUnits.map((u) {
                        return DropdownMenuItem(
                          value: u.key,
                          child: Text(u.value),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (newUnit) {
                              if (newUnit != null) {
                                setState(() => entry.unit = newUnit);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Biaya Lainnya: Nominal & Label
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: entry.otherCostController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Nominal Biaya (Rp)',
                        hintText: 'Contoh: 2000',
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Isi nominal';
                        }
                        final numVal = int.tryParse(val);
                        if (numVal == null || numVal < 0) {
                          return 'Tidak valid';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: entry.labelController,
                      enabled: !_isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan (Opsional)',
                        hintText: 'Air, Gas, Listrik',
                        isDense: true,
                      ),
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

  Widget _buildLiveCostSummaryCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final costResult = _calculateLiveCost();

    final totalText = CurrencyFormatter.formatRupiah(
      costResult.totalCost.round(),
    );
    final perUnitText = CurrencyFormatter.formatCostPerBaseUnit(
      costResult.costPerResultUnit,
      _resultUnit,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimasi Modal Olahan',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Modal:', style: theme.textTheme.bodyMedium),
              Text(
                totalText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Modal per Satuan Hasil:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                perUnitText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          if (costResult.hasUnresolvedCost) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Beberapa harga bahan mentah belum tersedia atau tidak kompatibel.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
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
}
