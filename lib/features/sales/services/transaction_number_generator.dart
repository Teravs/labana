import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';

/// Generator nomor transaksi penjualan yang unik dan terisolasi per tanggal.
///
/// Format: `TRX-YYYYMMDD-001`, `TRX-YYYYMMDD-002`, dst.
class TransactionNumberGenerator {
  final DatabaseHelper _dbHelper;

  TransactionNumberGenerator({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Menghasilkan nomor transaksi unik untuk [transactionDate] (format `YYYY-MM-DD` atau `YYYY-MM-DD HH:mm:ss`).
  ///
  /// [offset]: Digunakan saat penanganan tabrakan unik (*unique collision retry*)
  /// untuk melompati urutan ke angka berikutnya.
  Future<String> generate(
    String transactionDate, {
    DatabaseExecutor? executor,
    int offset = 0,
  }) async {
    final exec = executor ?? await _db;

    // Ambil 10 karakter pertama: YYYY-MM-DD
    final dateOnly = transactionDate.length >= 10
        ? transactionDate.substring(0, 10)
        : transactionDate;
    final dateDigits = dateOnly.replaceAll('-', '');
    final prefix = 'TRX-$dateDigits-';

    // Cari transaksi terakhir pada tanggal tersebut
    final results = await exec.query(
      TableNames.sales,
      columns: ['transaction_number'],
      where: 'transaction_number LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'LENGTH(transaction_number) DESC, transaction_number DESC',
      limit: 1,
    );

    int nextSequence = 1;

    if (results.isNotEmpty) {
      final lastTrx = results.first['transaction_number'] as String;
      final parts = lastTrx.split('-');
      if (parts.length >= 3) {
        final lastSeq = int.tryParse(parts.last) ?? 0;
        nextSequence = lastSeq + 1;
      }
    }

    nextSequence += offset;
    final seqFormatted = nextSequence.toString().padLeft(3, '0');
    return '$prefix$seqFormatted';
  }
}
