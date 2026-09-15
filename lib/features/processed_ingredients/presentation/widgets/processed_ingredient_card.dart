import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../models/processed_ingredient.dart';
import '../../services/processed_ingredient_calculator.dart';

/// Card item untuk menampilkan informasi bahan olahan, hasil olahan, komponen, dan modal.
class ProcessedIngredientCard extends StatelessWidget {
  final ProcessedIngredient processedIngredient;
  final int componentCount;
  final ProcessedIngredientCostResult? costResult;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  const ProcessedIngredientCard({
    super.key,
    required this.processedIngredient,
    required this.componentCount,
    this.costResult,
    this.onTap,
    this.onEdit,
    this.onDeactivate,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = processedIngredient.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ikon / Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary.withAlpha(25)
                      : colorScheme.outline.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.blender_outlined : Icons.blender_rounded,
                  size: 22,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withAlpha(120),
                ),
              ),
              const SizedBox(width: 14),

              // Konten Teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      processedIngredient.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withAlpha(140),
                        decoration: isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hasil: ${processedIngredient.formattedResultQuantity} ${processedIngredient.resultUnit} • $componentCount komponen',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? colorScheme.onSurface.withAlpha(160)
                            : colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 4),
                      _buildCostSummary(context),
                    ],
                  ],
                ),
              ),

              // Aksi: Popup Menu (Aktif) atau Tombol Reaktivasi (Nonaktif)
              if (isActive)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Pilihan bahan olahan',
                  onSelected: (action) {
                    if (action == 'edit') {
                      onEdit?.call();
                    } else if (action == 'deactivate') {
                      onDeactivate?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'deactivate',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Nonaktifkan'),
                        ],
                      ),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: onActivate,
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: const Text('Aktifkan Kembali'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostSummary(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (costResult == null) {
      return Text(
        'Menghitung modal...',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withAlpha(120),
        ),
      );
    }

    if (costResult!.hasUnresolvedCost) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: colorScheme.error),
          const SizedBox(width: 4),
          Text(
            'Harga belum lengkap',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final totalText = CurrencyFormatter.formatRupiah(
      costResult!.totalCost.round(),
    );
    final perUnitText = CurrencyFormatter.formatCostPerBaseUnit(
      costResult!.costPerResultUnit,
      processedIngredient.resultUnit,
    );

    return Text(
      '$totalText ($perUnitText)',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
