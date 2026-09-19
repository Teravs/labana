import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../ingredients/data/ingredient_price_repository.dart';
import '../../../ingredients/data/ingredient_repository.dart';
import '../../../processed_ingredients/data/processed_ingredient_repository.dart';
import '../../data/product_price_repository.dart';
import '../../data/product_repository.dart';
import '../../data/recipe_version_repository.dart';
import '../../models/product.dart';
import '../../models/product_price.dart';
import '../../models/recipe_item.dart';
import '../../models/recipe_version.dart';
import '../widgets/product_card.dart';
import '../widgets/product_form_sheet.dart';

/// Halaman utama daftar produk minuman dengan filter status Aktif dan Nonaktif.
class ProductsScreen extends StatefulWidget {
  final ProductRepository? productRepository;
  final RecipeVersionRepository? recipeVersionRepository;
  final ProductPriceRepository? productPriceRepository;
  final IngredientRepository? ingredientRepository;
  final IngredientPriceRepository? ingredientPriceRepository;
  final ProcessedIngredientRepository? processedRepository;

  const ProductsScreen({
    super.key,
    this.productRepository,
    this.recipeVersionRepository,
    this.productPriceRepository,
    this.ingredientRepository,
    this.ingredientPriceRepository,
    this.processedRepository,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductRepository _productRepo;
  late final RecipeVersionRepository _recipeVersionRepo;
  late final ProductPriceRepository _priceRepo;
  late final IngredientRepository _ingredientRepo;
  late final IngredientPriceRepository _ingredientPriceRepo;
  late final ProcessedIngredientRepository _processedRepo;

  String _selectedStatus = 'active'; // 'active' atau 'inactive'
  List<Product> _products = [];
  Map<int, RecipeVersion> _activeVersions = {};
  Map<int, ProductPrice> _currentPrices = {};

  bool _isLoading = true;
  String? _errorMessage;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _productRepo = widget.productRepository ?? ProductRepository();
    _recipeVersionRepo =
        widget.recipeVersionRepository ?? RecipeVersionRepository();
    _priceRepo = widget.productPriceRepository ?? ProductPriceRepository();
    _ingredientRepo = widget.ingredientRepository ?? IngredientRepository();
    _ingredientPriceRepo =
        widget.ingredientPriceRepository ?? IngredientPriceRepository();
    _processedRepo =
        widget.processedRepository ?? ProcessedIngredientRepository();

    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final currentRequestId = ++_loadRequestId;
    setState(() => _isLoading = true);
    try {
      final items = await _productRepo.getAll(status: _selectedStatus);
      final activeVersionsMap = <int, RecipeVersion>{};
      final pricesMap = <int, ProductPrice>{};

      for (final p in items) {
        if (p.id != null) {
          final v = await _recipeVersionRepo.getActiveVersion(p.id!);
          if (v != null) {
            activeVersionsMap[p.id!] = v;
          }
          final price = await _priceRepo.getEffectivePrice(p.id!);
          if (price != null) {
            pricesMap[p.id!] = price;
          }
        }
      }

      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _products = items;
          _activeVersions = activeVersionsMap;
          _currentPrices = pricesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat produk: $e';
        });
      }
    }
  }

  Future<void> _openCreateProductSheet() async {
    final created = await ProductFormSheet.show(
      context,
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
            await _productRepo.createProductWithRecipeAndPrice(
              name: name,
              recipeItems: recipeItems,
              sellingPrice: sellingPrice,
              effectiveDate: effectiveDate,
              hppTotal: hppTotal,
            );
          },
    );

    if (created == true) {
      _showMessage('Produk berhasil dibuat.');
      await _loadProducts();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
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

  Future<void> _openEditProduct(Product product) async {
    if (product.id == null) return;
    context.push('/products/${product.id}').then((_) => _loadProducts());
  }

  Future<void> _confirmDeactivate(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Produk?'),
        content: Text(
          'Produk "${product.name}" akan dipindahkan ke tab Nonaktif. Resep dan riwayat harga tetap aman.',
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

    if (confirmed == true && product.id != null) {
      try {
        await _productRepo.deactivate(product.id!);
        _showMessage('Produk dinonaktifkan.');
        _loadProducts();
      } catch (e) {
        _showMessage('Gagal menonaktifkan: $e', isError: true);
      }
    }
  }

  Future<void> _activateProduct(Product product) async {
    if (product.id == null) return;
    try {
      await _productRepo.activate(product.id!);
      _showMessage('Produk berhasil diaktifkan kembali.');
      _loadProducts();
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk & Resep')),
      body: Column(
        children: [
          // Filter Status Tab (Aktif vs Nonaktif)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'active',
                  label: Text('Aktif'),
                  icon: Icon(Icons.check_circle_outline, size: 16),
                ),
                ButtonSegment(
                  value: 'inactive',
                  label: Text('Nonaktif'),
                  icon: Icon(Icons.archive_outlined, size: 16),
                ),
              ],
              selected: {_selectedStatus},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedStatus = newSelection.first;
                });
                _loadProducts();
              },
            ),
          ),

          // Konten Utama
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _products.isEmpty
                ? AppEmptyState(
                    icon: Icons.local_cafe_outlined,
                    title: _selectedStatus == 'active'
                        ? 'Belum Ada Produk'
                        : 'Tidak Ada Produk Nonaktif',
                    message: _selectedStatus == 'active'
                        ? 'Mulai buat menu minuman Anda dengan menambahkan produk dan resep.'
                        : 'Produk yang Anda nonaktifkan akan tampil di sini.',
                  )
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _products.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final v = _activeVersions[product.id];
                        final price = _currentPrices[product.id];

                        return ProductCard(
                          product: product,
                          activeRecipeVersion: v,
                          currentPrice: price,
                          onTap: () {
                            context
                                .push('/products/${product.id}')
                                .then((_) => _loadProducts());
                          },
                          onEdit: () => _openEditProduct(product),
                          onDeactivate: () => _confirmDeactivate(product),
                          onActivate: () => _activateProduct(product),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedStatus == 'active'
          ? FloatingActionButton.extended(
              onPressed: _openCreateProductSheet,
              icon: const Icon(Icons.add),
              label: const Text('Produk'),
            )
          : null,
    );
  }
}
