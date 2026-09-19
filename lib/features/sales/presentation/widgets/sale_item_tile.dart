import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/sale_item.dart';

/// Widget tampilan item produk penjualan, mendukung mode edit (pengatur kuantitas)
/// dan mode baca (detail transaksi).
class SaleItemTile extends StatelessWidget {
  final SaleItem item;
  final bool isEditable;
  final ValueChanged<double>? onQuantityChanged;
  final VoidCallback? onRemove;

  const SaleItemTile({
    super.key,
    required this.item,
    this.isEditable = false,
    this.onQuantityChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (!isEditable) {
      // Mode Detail (Read-only)
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(isDark ? 80 : 120),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama Produk & Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.formattedSubtotal,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Rincian Kuantitas × Harga Jual & HPP per unit
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${item.formattedQuantity} × ${item.formattedSellingPrice}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'HPP/unit ${item.formattedHppPerUnit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Rincian HPP & Laba
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'HPP: ${item.formattedTotalHpp}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Laba: ${item.formattedTotalProfit}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: item.totalProfit >= 0
                        ? AppColors.primary
                        : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Mode Form (Editable)
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 80 : 120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama Produk & Tombol Hapus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.error,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRemove,
                  tooltip: 'Hapus item',
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Harga Jual & HPP Satuan
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Harga ${item.formattedSellingPrice}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '• HPP ${item.formattedHppPerUnit}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kontrol Kuantitas [-] Qty [+] & Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kontrol Stepper Kuantitas
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: item.quantity > 1
                          ? () => onQuantityChanged?.call(item.quantity - 1)
                          : null,
                      tooltip: 'Kurang kuantitas',
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: onQuantityChanged == null
                          ? null
                          : () => _showEditQuantityDialog(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          item.formattedQuantity,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          onQuantityChanged?.call(item.quantity + 1),
                      tooltip: 'Tambah kuantitas',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Subtotal
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Subtotal',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        item.formattedSubtotal,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditQuantityDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toString(),
    );

    final newQty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ubah Kuantitas "${item.productName}"'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Jumlah Porsi',
            hintText: 'Misal: 10',
            suffixText: 'porsi',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop(parsed);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newQty != null && newQty > 0) {
      onQuantityChanged?.call(newQty);
    }
  }
}
