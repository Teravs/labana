import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../services/sale_calculator.dart';

/// Modal bottom sheet untuk memilih produk aktif yang akan ditambahkan ke transaksi penjualan.
///
/// Menampilkan harga jual efektif, HPP efektif, dan estimasi laba per unit
/// yang dihitung menggunakan [SaleCalculator] pada tanggal transaksi terkait.
class ProductPickerSheet extends StatefulWidget {
  final String transactionDate;
  final ValueChanged<ProductPickerItem> onProductSelected;
  final SaleCalculator? calculator;

  const ProductPickerSheet({
    super.key,
    required this.transactionDate,
    required this.onProductSelected,
    this.calculator,
  });

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  late final SaleCalculator _calculator;
  bool _isLoading = true;
  List<ProductPickerItem> _allItems = [];
  List<ProductPickerItem> _filteredItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _calculator = widget.calculator ?? SaleCalculator();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final items = await _calculator.getAvailableProductsForPicker(
        transactionDate: widget.transactionDate,
      );
      if (mounted) {
        setState(() {
          _allItems = items;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    if (_searchQuery.trim().isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      final q = _searchQuery.toLowerCase().trim();
      _filteredItems = _allItems
          .where((item) => item.product.name.toLowerCase().contains(q))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Produk',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                      100,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilter();
                    });
                  },
                ),
              ),
              const Divider(height: 1),

              // List of products
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('Memuat produk...'),
                        ),
                      )
                    : _filteredItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: colorScheme.onSurfaceVariant.withAlpha(
                                  120,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _allItems.isEmpty
                                    ? 'Belum ada produk aktif'
                                    : 'Produk tidak ditemukan',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelectable = item.isValid;

                          return InkWell(
                            onTap: isSelectable
                                ? () {
                                    widget.onProductSelected(item);
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelectable
                                    ? colorScheme.surface
                                    : colorScheme.surfaceContainerHighest
                                          .withAlpha(40),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelectable
                                      ? colorScheme.outlineVariant.withAlpha(
                                          isDark ? 80 : 120,
                                        )
                                      : colorScheme.outlineVariant.withAlpha(
                                          40,
                                        ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon Produk
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isSelectable
                                          ? colorScheme.primaryContainer
                                                .withAlpha(80)
                                          : Colors.grey.withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.local_cafe_outlined,
                                      color: isSelectable
                                          ? colorScheme.primary
                                          : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Info Nama & Harga / Error
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: isSelectable
                                                    ? colorScheme.onSurface
                                                    : colorScheme.onSurface
                                                          .withAlpha(120),
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (isSelectable)
                                          Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                CurrencyFormatter.formatRupiah(
                                                  item.sellingPrice!,
                                                ),
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          colorScheme.onSurface,
                                                    ),
                                              ),
                                              Text(
                                                '• HPP ${CurrencyFormatter.formatRupiah(item.hppPerUnit!)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              Text(
                                                '• Laba ${CurrencyFormatter.formatRupiah(item.profitPerUnit!)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          item.profitPerUnit! >=
                                                              0
                                                          ? AppColors.primary
                                                          : AppColors.error,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                          )
                                        else
                                          Text(
                                            item.errorMessage ??
                                                'Data belum lengkap',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppColors.error,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Action Indicator
                                  if (isSelectable)
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: colorScheme.primary,
                                      size: 22,
                                    )
                                  else
                                    const Icon(
                                      Icons.block_rounded,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
