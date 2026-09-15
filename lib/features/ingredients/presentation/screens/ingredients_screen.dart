import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../processed_ingredients/data/processed_ingredient_repository.dart';
import '../../../processed_ingredients/models/processed_ingredient.dart';
import '../../../processed_ingredients/presentation/screens/processed_ingredient_detail_screen.dart';
import '../../../processed_ingredients/presentation/widgets/processed_ingredient_card.dart';
import '../../../processed_ingredients/presentation/widgets/processed_ingredient_form_sheet.dart';
import '../../../processed_ingredients/services/processed_ingredient_calculator.dart';
import '../../data/ingredient_price_repository.dart';
import '../../data/ingredient_repository.dart';
import '../../models/ingredient.dart';
import '../../models/ingredient_price.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/ingredient_form_sheet.dart';
import 'ingredient_detail_screen.dart';

/// Halaman utama pengelolaan Bahan dengan tab Bahan Mentah dan Bahan Olahan.
class IngredientsScreen extends StatefulWidget {
  final IngredientRepository? repository;
  final IngredientPriceRepository? priceRepository;
  final ProcessedIngredientRepository? processedRepository;

  const IngredientsScreen({
    super.key,
    this.repository,
    this.priceRepository,
    this.processedRepository,
  });

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  late final IngredientRepository _repository;
  late final IngredientPriceRepository _priceRepo;
  late final ProcessedIngredientRepository _processedRepo;

  int _selectedMainTab = 0; // 0: Bahan Mentah, 1: Bahan Olahan
  String _selectedStatus = 'active'; // 'active' atau 'inactive'
  String _processedStatus = 'active'; // 'active' atau 'inactive'

  // State Bahan Mentah
  List<Ingredient> _ingredients = [];
  Map<int, IngredientPrice> _defaultPrices = {};
  bool _isLoading = false;

  // State Bahan Olahan
  List<ProcessedIngredient> _processedIngredients = [];
  Map<int, int> _processedComponentCounts = {};
  Map<int, ProcessedIngredientCostResult> _processedCostResults = {};
  bool _isProcessedLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => _isLoading = true);
    try {
      final items = await _repository.getAll(status: _selectedStatus);
      final priceMap = <int, IngredientPrice>{};
      if (items.isNotEmpty) {
        priceMap.addAll(await _priceRepo.getAllDefaultPrices());
      }

      if (mounted) {
        setState(() {
          _ingredients = items;
          _defaultPrices = priceMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showFeedback(
          'Gagal memuat bahan mentah. Silakan coba lagi.',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadProcessedIngredients() async {
    setState(() => _isProcessedLoading = true);
    try {
      final items = await _processedRepo.getAll(status: _processedStatus);
      final countsMap = <int, int>{};
      final costResultsMap = <int, ProcessedIngredientCostResult>{};

      if (items.isNotEmpty) {
        // Ambil data harga bahan mentah sekali untuk kalkulasi
        final allRaw = await _repository.getAll(status: 'active');
        final rawNames = <int, String>{};
        final rawPrices = <int, List<IngredientPrice>>{};
        for (final r in allRaw) {
          if (r.id != null) {
            rawNames[r.id!] = r.name;
            rawPrices[r.id!] = await _priceRepo.getPrices(r.id!);
          }
        }

        final nowStr = DateTime.now().toIso8601String().substring(0, 10);

        for (final item in items) {
          if (item.id != null) {
            final comps = await _processedRepo.getComponents(item.id!);
            countsMap[item.id!] = comps.length;
            final costRes =
                ProcessedIngredientCalculator.calculateProcessedIngredientCost(
                  processedIngredient: item,
                  components: comps,
                  pricesByIngredientId: rawPrices,
                  ingredientNamesById: rawNames,
                  calculationDate: nowStr,
                );
            costResultsMap[item.id!] = costRes;
          }
        }
      }

      if (mounted) {
        setState(() {
          _processedIngredients = items;
          _processedComponentCounts = countsMap;
          _processedCostResults = costResultsMap;
          _isProcessedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessedLoading = false);
        _showFeedback(
          'Gagal memuat bahan olahan. Silakan coba lagi.',
          isError: true,
        );
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

  // ---------------------------------------------------------------------------
  // Action Handlers: Bahan Mentah
  // ---------------------------------------------------------------------------
  Future<void> _showAddForm() async {
    final result = await IngredientFormSheet.show(
      context,
      onSave: (name) async {
        await _repository.create(name);
      },
    );

    if (result == true) {
      _showFeedback('Bahan berhasil ditambahkan.');
      await _loadIngredients();
    }
  }

  Future<void> _showEditForm(Ingredient ingredient) async {
    final result = await IngredientFormSheet.show(
      context,
      initialIngredient: ingredient,
      onSave: (newName) async {
        await _repository.update(ingredient.id!, newName);
      },
    );

    if (result == true) {
      _showFeedback('Bahan berhasil diperbarui.');
      await _loadIngredients();
    }
  }

  Future<void> _confirmDeactivate(Ingredient ingredient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan bahan?'),
        content: Text(
          'Bahan "${ingredient.name}" akan disembunyikan dari daftar bahan aktif.',
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
        await _repository.deactivate(ingredient.id!);
        _showFeedback('Bahan dinonaktifkan.');
        await _loadIngredients();
      } catch (e) {
        _showFeedback('Gagal menonaktifkan bahan.', isError: true);
      }
    }
  }

  Future<void> _activateIngredient(Ingredient ingredient) async {
    try {
      await _repository.activate(ingredient.id!);
      _showFeedback('Bahan berhasil diaktifkan kembali.');
      await _loadIngredients();
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    }
  }

  Future<void> _openIngredientDetail(Ingredient ingredient) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IngredientDetailScreen(
          ingredientId: ingredient.id!,
          ingredientRepository: _repository,
          priceRepository: _priceRepo,
        ),
      ),
    );
    await _loadIngredients();
  }

  // ---------------------------------------------------------------------------
  // Action Handlers: Bahan Olahan
  // ---------------------------------------------------------------------------
  Future<void> _showAddProcessedForm() async {
    final result = await ProcessedIngredientFormSheet.show(
      context,
      ingredientRepository: _repository,
      priceRepository: _priceRepo,
      onSave:
          ({
            required name,
            required resultQuantity,
            required resultUnit,
            required components,
          }) async {
            await _processedRepo.create(
              name: name,
              resultQuantity: resultQuantity,
              resultUnit: resultUnit,
              components: components,
            );
          },
    );

    if (result == true) {
      _showFeedback('Bahan olahan berhasil ditambahkan.');
      await _loadProcessedIngredients();
    }
  }

  Future<void> _showEditProcessedForm(ProcessedIngredient item) async {
    final components = await _processedRepo.getComponents(item.id!);

    if (!mounted) return;
    final result = await ProcessedIngredientFormSheet.show(
      context,
      initialProcessedIngredient: item,
      initialComponents: components,
      ingredientRepository: _repository,
      priceRepository: _priceRepo,
      onSave:
          ({
            required name,
            required resultQuantity,
            required resultUnit,
            required components,
          }) async {
            await _processedRepo.update(
              item.id!,
              name: name,
              resultQuantity: resultQuantity,
              resultUnit: resultUnit,
              components: components,
            );
          },
    );

    if (result == true) {
      _showFeedback('Bahan olahan berhasil diperbarui.');
      await _loadProcessedIngredients();
    }
  }

  Future<void> _confirmDeactivateProcessed(ProcessedIngredient item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan bahan olahan?'),
        content: Text(
          'Bahan olahan "${item.name}" akan dipindahkan ke daftar nonaktif.',
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
        await _processedRepo.deactivate(item.id!);
        _showFeedback('Bahan olahan dinonaktifkan.');
        await _loadProcessedIngredients();
      } catch (e) {
        _showFeedback('Gagal menonaktifkan: $e', isError: true);
      }
    }
  }

  Future<void> _activateProcessed(ProcessedIngredient item) async {
    try {
      await _processedRepo.activate(item.id!);
      _showFeedback('Bahan olahan berhasil diaktifkan kembali.');
      await _loadProcessedIngredients();
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    }
  }

  Future<void> _openProcessedDetail(ProcessedIngredient item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProcessedIngredientDetailScreen(
          processedIngredientId: item.id!,
          processedRepository: _processedRepo,
          ingredientRepository: _repository,
          priceRepository: _priceRepo,
        ),
      ),
    );
    await _loadProcessedIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bahan')),
      body: SafeArea(
        child: Column(
          children: [
            // Tab Utama: Bahan Mentah vs Bahan Olahan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Bahan Mentah'),
                      icon: Icon(Icons.inventory_2_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Bahan Olahan'),
                      icon: Icon(Icons.blender_outlined, size: 16),
                    ),
                  ],
                  selected: {_selectedMainTab},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedMainTab = newSelection.first;
                    });
                    if (_selectedMainTab == 1) {
                      _loadProcessedIngredients();
                    } else {
                      _loadIngredients();
                    }
                  },
                ),
              ),
            ),

            // Konten Berdasarkan Tab Utama
            Expanded(
              child: _selectedMainTab == 1
                  ? _buildProcessedIngredientsView()
                  : _buildRawIngredientsView(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_selectedMainTab == 0 && _selectedStatus == 'active') {
      return FloatingActionButton.extended(
        onPressed: _showAddForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Bahan'),
      );
    }

    if (_selectedMainTab == 1 && _processedStatus == 'active') {
      return FloatingActionButton.extended(
        onPressed: _showAddProcessedForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Bahan Olahan'),
      );
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // View: Bahan Mentah
  // ---------------------------------------------------------------------------
  Widget _buildRawIngredientsView() {
    return Column(
      children: [
        // Sub-filter: Aktif vs Nonaktif
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Aktif')),
                  ButtonSegment(value: 'inactive', label: Text('Nonaktif')),
                ],
                selected: {_selectedStatus},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedStatus = newSelection.first;
                  });
                  _loadIngredients();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Daftar Bahan / Loading / Empty State
        Expanded(
          child: _ingredients.isEmpty
              ? (_isLoading
                    ? Center(
                        child: Text(
                          'Memuat bahan...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(150),
                              ),
                        ),
                      )
                    : _buildRawEmptyState())
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: 84,
                  ),
                  itemCount: _ingredients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _ingredients[index];
                    final defaultPrice = _defaultPrices[item.id];
                    String? priceSummary;
                    if (defaultPrice != null) {
                      priceSummary =
                          '${CurrencyFormatter.formatRupiah(defaultPrice.price)} / ${defaultPrice.formattedPurchaseFormat}';
                    }

                    return IngredientCard(
                      ingredient: item,
                      priceSummary: priceSummary,
                      onTap: () => _openIngredientDetail(item),
                      onEdit: () => _showEditForm(item),
                      onDeactivate: () => _confirmDeactivate(item),
                      onActivate: () => _activateIngredient(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRawEmptyState() {
    if (_selectedStatus == 'active') {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada bahan mentah',
        message: 'Tambahkan bahan yang digunakan dalam resep produkmu.',
        actionLabel: 'Tambah Bahan',
        onActionPressed: _showAddForm,
      );
    } else {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tidak ada bahan nonaktif',
        message: 'Bahan yang dinonaktifkan akan muncul di sini.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // View: Bahan Olahan
  // ---------------------------------------------------------------------------
  Widget _buildProcessedIngredientsView() {
    return Column(
      children: [
        // Sub-filter: Aktif vs Nonaktif
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'active', label: Text('Aktif')),
                  ButtonSegment(value: 'inactive', label: Text('Nonaktif')),
                ],
                selected: {_processedStatus},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _processedStatus = newSelection.first;
                  });
                  _loadProcessedIngredients();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Daftar Bahan Olahan / Loading / Empty State
        Expanded(
          child: _processedIngredients.isEmpty
              ? (_isProcessedLoading
                    ? Center(
                        child: Text(
                          'Memuat bahan olahan...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(150),
                              ),
                        ),
                      )
                    : _buildProcessedEmptyState())
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: 84,
                  ),
                  itemCount: _processedIngredients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _processedIngredients[index];
                    final count = _processedComponentCounts[item.id] ?? 0;
                    final costRes = _processedCostResults[item.id];

                    return ProcessedIngredientCard(
                      processedIngredient: item,
                      componentCount: count,
                      costResult: costRes,
                      onTap: () => _openProcessedDetail(item),
                      onEdit: () => _showEditProcessedForm(item),
                      onDeactivate: () => _confirmDeactivateProcessed(item),
                      onActivate: () => _activateProcessed(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProcessedEmptyState() {
    if (_processedStatus == 'active') {
      return AppEmptyState(
        icon: Icons.blender_outlined,
        title: 'Belum ada bahan olahan',
        message:
            'Tambahkan bahan olahan seperti sirup, racikan susu, atau saus yang dibuat sendiri.',
        actionLabel: 'Tambah Bahan Olahan',
        onActionPressed: _showAddProcessedForm,
      );
    } else {
      return const AppEmptyState(
        icon: Icons.blender_outlined,
        title: 'Tidak ada bahan olahan nonaktif',
        message: 'Bahan olahan yang dinonaktifkan akan muncul di sini.',
      );
    }
  }
}
