import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/sale.dart';

/// Kartu representasi transaksi penjualan untuk ditampilkan pada [SalesScreen].
class SaleCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const SaleCard({super.key, required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isProfitPositive = sale.totalProfit >= 0;
    final profitColor = isProfitPositive ? AppColors.primary : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(isDark ? 80 : 120),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris 1: Nomor Transaksi & Badge Metode Pembayaran
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sale.transactionNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PaymentBadge(method: sale.paymentMethod),
                ],
              ),
              const SizedBox(height: 6),

              // Baris 2: Tanggal & Waktu • Jumlah Produk
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    sale.formattedDateTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sale.itemCount ?? 0} produk',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Baris 3: Total Omzet & Total Laba
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Omzet',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sale.formattedTotalAmount,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Laba',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Laba ${sale.formattedTotalProfit}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: profitColor,
                        ),
                      ),
                    ],
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

/// Badge visual kecil untuk metode pembayaran.
class _PaymentBadge extends StatelessWidget {
  final String method;

  const _PaymentBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String label;
    IconData icon;
    Color bgColor;
    Color fgColor;

    switch (method) {
      case Sale.paymentQris:
        label = 'QRIS';
        icon = Icons.qr_code_2_rounded;
        bgColor = Colors.blue.withAlpha(25);
        fgColor = Colors.blue.shade700;
        break;
      case Sale.paymentTransfer:
        label = 'Transfer';
        icon = Icons.account_balance_rounded;
        bgColor = Colors.purple.withAlpha(25);
        fgColor = Colors.purple.shade700;
        break;
      case Sale.paymentCash:
      default:
        label = 'Tunai';
        icon = Icons.payments_outlined;
        bgColor = colorScheme.primaryContainer.withAlpha(80);
        fgColor = colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fgColor.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
