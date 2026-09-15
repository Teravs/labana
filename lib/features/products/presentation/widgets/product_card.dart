import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../models/product_price.dart';
import '../../models/recipe_version.dart';

/// Card item untuk menampilkan produk minuman, versi resep, harga jual, HPP, dan estimasi laba.
class ProductCard extends StatelessWidget {
  final Product product;
  final RecipeVersion? activeRecipeVersion;
  final ProductPrice? currentPrice;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  const ProductCard({
    super.key,
    required this.product,
    this.activeRecipeVersion,
    this.currentPrice,
    this.onTap,
    this.onEdit,
    this.onDeactivate,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = product.isActive;

    final sellingPrice = currentPrice?.sellingPrice ?? 0;
    final hpp = activeRecipeVersion?.hppTotal ?? 0;
    final profit = sellingPrice - hpp;
    final isBelowHpp = sellingPrice > 0 && sellingPrice < hpp;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ikon Produk
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? colorScheme.primary.withAlpha(25)
                          : colorScheme.outline.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive ? Icons.local_cafe_outlined : Icons.local_cafe_rounded,
                  size: 22,
                  color:
                      isActive
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  isActive
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface.withAlpha(140),
                              decoration:
                                  isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        if (isActive && activeRecipeVersion != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer.withAlpha(150),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${activeRecipeVersion!.versionNumber}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (isActive) ...[
                      // Harga Jual & HPP
                      Row(
                        children: [
                          Text(
                            currentPrice != null
                                ? CurrencyFormatter.formatRupiah(sellingPrice)
                                : 'Harga belum diatur',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• HPP: ${CurrencyFormatter.formatRupiah(hpp)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withAlpha(160),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Estimasi Laba
                      if (currentPrice != null)
                        Row(
                          children: [
                            Text(
                              'Laba: ${CurrencyFormatter.formatRupiah(profit)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    isBelowHpp
                                        ? colorScheme.error
                                        : AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isBelowHpp) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Di bawah HPP',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ] else ...[
                      Text(
                        'Produk Nonaktif',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Aksi: Popup Menu (Aktif) atau Tombol Reaktivasi (Nonaktif)
              if (isActive)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurface.withAlpha(160),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'deactivate') onDeactivate?.call();
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'deactivate',
                          child: Row(
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 18,
                                color: colorScheme.error,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Nonaktifkan',
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                )
              else
                IconButton(
                  onPressed: onActivate,
                  tooltip: 'Aktifkan Kembali',
                  icon: Icon(
                    Icons.replay_rounded,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

