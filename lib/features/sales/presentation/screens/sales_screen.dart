import 'package:flutter/material.dart';

import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_empty_state.dart';

/// Halaman Penjualan dengan visual empty state.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan')),
      body: SafeArea(
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Belum ada transaksi.',
          message: 'Transaksi penjualan yang kamu buat akan muncul di sini.',
          actionLabel: 'Penjualan',
          onActionPressed: () => AppFeedback.showFeatureNotice(context),
        ),
      ),
    );
  }
}
