import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../data/sale_repository.dart';
import '../../models/sale.dart';
import '../widgets/sale_card.dart';
import 'sale_detail_screen.dart';
import 'sale_form_screen.dart';

/// Halaman utama Penjualan Labana yang menampilkan daftar riwayat transaksi penjualan.
class SalesScreen extends StatefulWidget {
  final SaleRepository? saleRepo;

  const SalesScreen({super.key, this.saleRepo});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final SaleRepository _saleRepo;
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _saleRepo = widget.saleRepo ?? SaleRepository();
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      final list = await _saleRepo.getAll();
      if (mounted) {
        setState(() {
          _sales = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _openAddSale() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SaleFormScreen(saleRepo: _saleRepo)),
    );

    if (created == true && mounted) {
      _loadSales();
    }
  }

  Future<void> _openDetail(Sale sale) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SaleDetailScreen(saleId: sale.id!, saleRepo: _saleRepo),
      ),
    );

    if (changed == true && mounted) {
      _loadSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penjualan')),
      body: RefreshIndicator(
        onRefresh: _loadSales,
        child: _sales.isEmpty
            ? Stack(
                children: [
                  ListView(), // Agar RefreshIndicator dapat di-pull saat empty
                  Center(
                    child: AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Belum ada transaksi.',
                      message:
                          'Transaksi penjualan yang kamu buat akan muncul di sini.',
                      actionLabel: '+ Tambah Penjualan',
                      onActionPressed: _openAddSale,
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _sales.length,
                itemBuilder: (context, index) {
                  final sale = _sales[index];
                  return SaleCard(sale: sale, onTap: () => _openDetail(sale));
                },
              ),
      ),
      floatingActionButton: _sales.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openAddSale,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Penjualan'),
            )
          : null,
    );
  }
}
