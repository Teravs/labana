import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';

/// Halaman Laporan dengan tab periode filter visual dan empty state.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = 'Hari';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Hari', label: Text('Hari')),
                    ButtonSegment(value: 'Minggu', label: Text('Minggu')),
                    ButtonSegment(value: 'Bulan', label: Text('Bulan')),
                  ],
                  selected: {_selectedPeriod},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _selectedPeriod = newSelection.first;
                    });
                  },
                ),
              ),
            ),
            const Expanded(
              child: AppEmptyState(
                icon: Icons.analytics_outlined,
                title: 'Belum ada data laporan.',
                message:
                    'Laporan akan tersedia setelah terdapat transaksi penjualan.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

