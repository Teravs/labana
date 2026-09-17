import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/sale_repository.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../services/sale_calculator.dart';
import '../widgets/product_picker_sheet.dart';
import '../widgets/sale_item_tile.dart';

/// Layar form untuk membuat atau mengedit transaksi penjualan.
class SaleFormScreen extends StatefulWidget {
  final int? saleId;
  final SaleRepository? saleRepo;
  final SaleCalculator? calculator;

  const SaleFormScreen({
    super.key,
    this.saleId,
    this.saleRepo,
    this.calculator,
  });

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  late final SaleRepository _saleRepo;
  late final SaleCalculator _calculator;

  bool _isLoading = true;
  bool _isSaving = false;
  Sale? _existingSale;
  final Set<int> _initialProductIds = {};

  DateTime _selectedDateTime = DateTime.now();
  String _paymentMethod = Sale.paymentCash;
  List<SaleItem> _items = [];

  bool get isEditing => widget.saleId != null;

  @override
  void initState() {
    super.initState();
    _saleRepo = widget.saleRepo ?? SaleRepository();
    _calculator = widget.calculator ?? SaleCalculator();

    if (isEditing) {
      _loadExistingSale();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadExistingSale() async {
    try {
      final sale = await _saleRepo.getById(widget.saleId!);
      if (sale != null && mounted) {
        setState(() {
          _existingSale = sale;
          _paymentMethod = sale.paymentMethod;
          _items = List.from(sale.items ?? []);
          _initialProductIds.addAll(_items.map((e) => e.productId));

          final parsed = DateTime.tryParse(
            sale.transactionDate.replaceFirst(' ', 'T'),
          );
          if (parsed != null) {
            _selectedDateTime = parsed;
          }
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat transaksi: $e')));
      }
    }
  }

  String get _transactionDateStr {
    final y = _selectedDateTime.year.toString().padLeft(4, '0');
    final m = _selectedDateTime.month.toString().padLeft(2, '0');
    final d = _selectedDateTime.day.toString().padLeft(2, '0');
    final h = _selectedDateTime.hour.toString().padLeft(2, '0');
    final min = _selectedDateTime.minute.toString().padLeft(2, '0');
    final s = _selectedDateTime.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }

  String get _formattedDateTimeDisplay {
    final months = [
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
    final m = months[_selectedDateTime.month - 1];
    final h = _selectedDateTime.hour.toString().padLeft(2, '0');
    final min = _selectedDateTime.minute.toString().padLeft(2, '0');
    return '${_selectedDateTime.day} $m ${_selectedDateTime.year}, $h:$min';
  }

  SaleTotals get _totals => _calculator.calculateTotals(_items);

  Future<void> _pickDateTime() async {
    final initialDate = _selectedDateTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null || !mounted) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _selectedDateTime = newDateTime;
    });

    // Jika tanggal berubah dan ada item, hitung ulang item untuk tanggal baru
    await _recalculateAllItems();
  }

  Future<void> _recalculateAllItems() async {
    if (_items.isEmpty) return;

    setState(() => _isSaving = true);
    final recalculatedItems = <SaleItem>[];

    try {
      for (final item in _items) {
        final recalculated = await _calculator.calculateItem(
          productId: item.productId,
          transactionDate: _transactionDateStr,
          quantity: item.quantity,
          isNewItem: false,
          existingProductIds: _initialProductIds,
        );
        recalculatedItems.add(recalculated);
      }

      if (mounted) {
        setState(() {
          _items = recalculatedItems;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Peringatan: Sebagian item tidak dapat dihitung pada tanggal baru: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ProductPickerSheet(
          transactionDate: _transactionDateStr,
          calculator: _calculator,
          onProductSelected: (pickerItem) => _addProduct(pickerItem),
        );
      },
    );
  }

  Future<void> _addProduct(ProductPickerItem pickerItem) async {
    final productId = pickerItem.product.id!;

    // Cek apakah produk sudah ada di daftar item
    final existingIndex = _items.indexWhere((i) => i.productId == productId);
    if (existingIndex != -1) {
      // Tambahkan kuantitas + 1
      final current = _items[existingIndex];
      await _updateQuantity(existingIndex, current.quantity + 1);
      return;
    }

    try {
      final newItem = await _calculator.calculateItem(
        productId: productId,
        transactionDate: _transactionDateStr,
        quantity: 1,
        isNewItem: true,
        existingProductIds: _initialProductIds,
      );

      if (mounted) {
        setState(() {
          _items.add(newItem);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan produk: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(int index, double newQty) async {
    if (newQty <= 0) return;

    final current = _items[index];
    try {
      final updated = await _calculator.calculateItem(
        productId: current.productId,
        transactionDate: _transactionDateStr,
        quantity: newQty,
        isNewItem: false,
        existingProductIds: _initialProductIds,
      );

      if (mounted) {
        setState(() {
          _items[index] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui kuantitas: $e')),
        );
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _saveSale() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan minimal 1 produk terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final totals = _totals;
    final nowIso = DateTime.now().toIso8601String();

    try {
      if (isEditing) {
        final updatedSale = _existingSale!.copyWith(
          transactionDate: _transactionDateStr,
          paymentMethod: _paymentMethod,
          totalAmount: totals.totalAmount,
          totalHpp: totals.totalHpp,
          totalProfit: totals.totalProfit,
          updatedAt: nowIso,
        );

        await _saleRepo.updateSaleWithItems(sale: updatedSale, items: _items);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil diperbarui.')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        final newSale = Sale(
          transactionNumber: '', // di-generate oleh repository secara atomik
          transactionDate: _transactionDateStr,
          paymentMethod: _paymentMethod,
          totalAmount: totals.totalAmount,
          totalHpp: totals.totalHpp,
          totalProfit: totals.totalProfit,
          createdAt: nowIso,
          updatedAt: nowIso,
        );

        await _saleRepo.createSaleWithItems(sale: newSale, items: _items);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Penjualan berhasil dicatat.')),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan penjualan: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totals = _totals;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Penjualan' : 'Tambah Penjualan'),
      ),
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Memuat data penjualan...'),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Tanggal & Waktu
                    Text(
                      'Tanggal & Waktu Transaksi',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withAlpha(
                            80,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formattedDateTimeDisplay,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: Metode Pembayaran
                    Text(
                      'Metode Pembayaran',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: Sale.paymentCash,
                            label: Text('Tunai'),
                            icon: Icon(Icons.payments_outlined, size: 16),
                          ),
                          ButtonSegment<String>(
                            value: Sale.paymentQris,
                            label: Text('QRIS'),
                            icon: Icon(Icons.qr_code_2_rounded, size: 16),
                          ),
                          ButtonSegment<String>(
                            value: Sale.paymentTransfer,
                            label: Text('Transfer'),
                            icon: Icon(Icons.account_balance_rounded, size: 16),
                          ),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _paymentMethod = newSelection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 3: Produk Terjual
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Produk Terjual (${_items.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openProductPicker,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Tambah Produk'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withAlpha(
                            40,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withAlpha(60),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 36,
                                color: colorScheme.onSurfaceVariant.withAlpha(
                                  120,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada produk yang ditambahkan',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_items.length, (index) {
                        return SaleItemTile(
                          item: _items[index],
                          isEditable: true,
                          onQuantityChanged: (newQty) =>
                              _updateQuantity(index, newQty),
                          onRemove: () => _removeItem(index),
                        );
                      }),
                    const SizedBox(height: 24),

                    // Section 4: Ringkasan Transaksi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withAlpha(40),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.primary.withAlpha(40),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Omzet',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    CurrencyFormatter.formatRupiah(
                                      totals.totalAmount,
                                    ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total HPP',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    CurrencyFormatter.formatRupiah(
                                      totals.totalHpp,
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Laba',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    CurrencyFormatter.formatRupiah(
                                      totals.totalProfit,
                                    ),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: totals.totalProfit >= 0
                                              ? AppColors.primary
                                              : AppColors.error,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveSale,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Simpan Perubahan'
                                    : 'Simpan Penjualan',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
