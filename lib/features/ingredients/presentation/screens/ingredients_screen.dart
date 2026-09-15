import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';
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

  const IngredientsScreen({super.key, this.repository, this.priceRepository});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  late final IngredientRepository _repository;
  late final IngredientPriceRepository _priceRepo;

  int _selectedMainTab = 0; // 0: Bahan Mentah, 1: Bahan Olahan
  String _selectedStatus = 'active'; // 'active' atau 'inactive'

  List<Ingredient> _ingredients = [];
  Map<int, IngredientPrice> _defaultPrices = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IngredientRepository();
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
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
        _showFeedback('Gagal memuat bahan. Silakan coba lagi.', isError: true);
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
                  },
                ),
              ),
            ),

            // Konten Berdasarkan Tab Utama
            Expanded(
              child: _selectedMainTab == 1
                  ? const AppEmptyState(
                      icon: Icons.blender_outlined,
                      title: 'Bahan Olahan',
                      message:
                          'Fitur bahan olahan akan tersedia pada tahap berikutnya.',
                    )
                  : _buildRawIngredientsView(),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedMainTab == 0 && _selectedStatus == 'active'
          ? FloatingActionButton.extended(
              onPressed: _showAddForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Bahan'),
            )
          : null,
    );
  }

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
                    : _buildEmptyState())
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: 84, // Ruang untuk FloatingActionButton
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

  Widget _buildEmptyState() {
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
}
