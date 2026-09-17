import 'package:flutter/material.dart';

import '../../models/ingredient.dart';

/// Card item untuk menampilkan informasi bahan mentah, ringkasan harga, dan aksi terkait.
class IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final String? priceSummary;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.priceSummary,
    this.onTap,
    this.onEdit,
    this.onDeactivate,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = ingredient.isActive;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
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
                  isActive
                      ? Icons.inventory_2_outlined
                      : Icons.inventory_2_rounded,
                  size: 22,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withAlpha(120),
                ),
              ),
              const SizedBox(width: 14),

              // Nama & Keterangan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                    Row(
                      children: [
                        Text(
                          isActive ? 'Bahan Mentah' : 'Nonaktif',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isActive
                                ? colorScheme.onSurface.withAlpha(160)
                                : colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isActive && priceSummary != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: colorScheme.onSurface.withAlpha(120),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              priceSummary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Action: Menu (Aktif) atau Tombol Aktifkan (Nonaktif)
              if (isActive)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Pilihan bahan',
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
}
