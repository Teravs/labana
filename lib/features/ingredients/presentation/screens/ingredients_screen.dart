import 'package:flutter/material.dart';

import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_empty_state.dart';

/// Halaman Bahan dengan visual empty state.
class IngredientsScreen extends StatelessWidget {
  const IngredientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahan'),
      ),
      body: SafeArea(
        child: AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Belum ada bahan.',
          message:
              'Tambahkan bahan mentah atau bahan olahan untuk mulai menghitung modal.',
          actionLabel: 'Tambah Bahan',
          onActionPressed: () => AppFeedback.showFeatureNotice(context),
        ),
      ),
    );
  }
}

