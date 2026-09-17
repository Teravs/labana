import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/unit_converter.dart';
import '../../data/ingredient_price_repository.dart';
import '../../data/ingredient_repository.dart';
import '../../models/ingredient.dart';

/// Modal bottom sheet untuk menambahkan harga pembelian baru pada bahan mentah.
class IngredientPriceFormSheet extends StatefulWidget {
  final Ingredient ingredient;
  final IngredientPriceRepository? priceRepository;
  final bool isFirstPrice;

  const IngredientPriceFormSheet({
    super.key,
    required this.ingredient,
    this.priceRepository,
    this.isFirstPrice = false,
  });

  /// Menampilkan modal bottom sheet form harga.
  static Future<bool?> show(
    BuildContext context, {
    required Ingredient ingredient,
    IngredientPriceRepository? priceRepository,
    bool isFirstPrice = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => IngredientPriceFormSheet(
        ingredient: ingredient,
        priceRepository: priceRepository,
        isFirstPrice: isFirstPrice,
      ),
    );
  }

  @override
  State<IngredientPriceFormSheet> createState() =>
      _IngredientPriceFormSheetState();
}

class _IngredientPriceFormSheetState extends State<IngredientPriceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final IngredientPriceRepository _priceRepo;

  final _qtyController = TextEditingController(text: '1');
  final _packageQtyController = TextEditingController(text: '50');
  final _priceController = TextEditingController();

  String _selectedUnit = UnitConverter.unitKilogram;
  late DateTime _selectedDate;
  late bool _isDefault;
  bool _isSaving = false;

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
    _priceRepo = widget.priceRepository ?? IngredientPriceRepository();
    _selectedDate = DateTime.now();
    // Default format aktif otomatis bernilai true jika ini adalah harga pertama
    _isDefault = widget.isFirstPrice;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _packageQtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _formatDateDb(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateDisplay(DateTime dt) {
    return '${dt.day} ${_monthNames[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Menghitung preview konversi dan harga dasar untuk umpan balik instan
  Widget _buildLivePreview(ThemeData theme) {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final price =
        int.tryParse(_priceController.text.replaceAll('.', '').trim()) ?? 0;
    final packageQty = _selectedUnit == UnitConverter.unitPack
        ? (double.tryParse(_packageQtyController.text.trim()) ?? 0.0)
        : null;

    if (qty <= 0 || price <= 0) {
      return const SizedBox.shrink();
    }

    if (_selectedUnit == UnitConverter.unitPack &&
        (packageQty == null || packageQty <= 0)) {
      return const SizedBox.shrink();
    }

    try {
      final conversion = UnitConverter.convert(
        purchaseQuantity: qty,
        purchaseUnit: _selectedUnit,
        packageQuantity: packageQty,
      );

      final costPerBase = price / conversion.baseQuantity;
      final formattedCost = CurrencyFormatter.formatCostPerBaseUnit(
        costPerBase,
        conversion.baseUnit,
      );

      final formattedBaseQty = conversion.baseQuantity % 1 == 0
          ? conversion.baseQuantity.toInt().toString()
          : conversion.baseQuantity.toString();

      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calculate_outlined,
              size: 22,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Konversi: $formattedBaseQty ${conversion.baseUnit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Harga Satuan Dasar: $formattedCost',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.parse(_qtyController.text.trim());
    final rawPriceStr = _priceController.text.replaceAll('.', '').trim();
    final price = int.parse(rawPriceStr);
    final packageQty = _selectedUnit == UnitConverter.unitPack
        ? double.parse(_packageQtyController.text.trim())
        : null;
    final effectiveFrom = _formatDateDb(_selectedDate);

    setState(() => _isSaving = true);

    try {
      await _priceRepo.createPrice(
        ingredientId: widget.ingredient.id!,
        purchaseQuantity: qty,
        purchaseUnit: _selectedUnit,
        packageQuantity: packageQty,
        price: price,
        effectiveFrom: effectiveFrom,
        isDefault: _isDefault,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal menyimpan harga pembelian.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPack = _selectedUnit == UnitConverter.unitPack;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tambah Harga Pembelian',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Bahan: ${widget.ingredient.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
              const SizedBox(height: 20),

              // Baris Jumlah & Satuan Pembelian
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Jumlah Pembelian
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Pembelian',
                        hintText: '1',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Wajib diisi';
                        }
                        final numVal = double.tryParse(value.trim());
                        if (numVal == null || numVal <= 0) {
                          return 'Harus > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Satuan Pembelian Dropdown
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(labelText: 'Satuan'),
                      items: UnitConverter.purchaseUnits.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (newUnit) {
                              if (newUnit != null) {
                                setState(() {
                                  _selectedUnit = newUnit;
                                });
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kondisional Field: Isi per Pack (Hanya tampil jika satuan = Pack)
              if (isPack) ...[
                TextFormField(
                  key: const Key('package_quantity_field'),
                  controller: _packageQtyController,
                  decoration: const InputDecoration(
                    labelText: 'Isi per Pack',
                    hintText: '50',
                    suffixText: 'pcs',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Isi per pack wajib diisi';
                    }
                    final numVal = double.tryParse(value.trim());
                    if (numVal == null || numVal <= 0) {
                      return 'Isi per pack harus > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Harga Pembelian (Rupiah)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Harga Pembelian',
                  hintText: '20000',
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Harga pembelian wajib diisi';
                  }
                  final numVal = int.tryParse(value.replaceAll('.', '').trim());
                  if (numVal == null || numVal < 0) {
                    return 'Harga tidak boleh negatif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tanggal Mulai Berlaku
              InkWell(
                onTap: _isSaving ? null : _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Berlaku Mulai',
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 20),
                  ),
                  child: Text(
                    _formatDateDisplay(_selectedDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Jadikan Format Default Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadikan Format Utama (Default)'),
                subtitle: const Text(
                  'Format ini akan digunakan secara otomatis saat menghitung resep.',
                ),
                value: _isDefault,
                onChanged: _isSaving
                    ? null
                    : (val) {
                        setState(() {
                          _isDefault = val;
                        });
                      },
              ),

              // Live Preview Kalkulasi
              _buildLivePreview(theme),
              const SizedBox(height: 24),

              // Tombol Aksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _handleSave,
                      child: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
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
}
