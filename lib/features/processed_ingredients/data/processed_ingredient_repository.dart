import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/processed_component.dart';
import '../models/processed_ingredient.dart';
import 'processed_component_repository.dart';

/// Repository untuk mengelola data bahan olahan (`processed_ingredients`).
class ProcessedIngredientRepository {
  final DatabaseHelper _dbHelper;
  final ProcessedComponentRepository _componentRepo;

  ProcessedIngredientRepository({
    DatabaseHelper? dbHelper,
    ProcessedComponentRepository? componentRepo,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _componentRepo =
           componentRepo ?? ProcessedComponentRepository(dbHelper: dbHelper);

  Future<Database> get _db => _dbHelper.database;

  static const List<String> allowedResultUnits = ['g', 'ml', 'pcs'];

  /// Mengambil semua bahan olahan berdasarkan [status] ('active' atau 'inactive').
  Future<List<ProcessedIngredient>> getAll({String status = 'active'}) async {
    final db = await _db;
    final results = await db.query(
      TableNames.processedIngredients,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return results.map((map) => ProcessedIngredient.fromMap(map)).toList();
  }

  /// Mengambil satu bahan olahan berdasarkan [id].
  Future<ProcessedIngredient?> getById(int id) async {
    final db = await _db;
    final results = await db.query(
      TableNames.processedIngredients,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ProcessedIngredient.fromMap(results.first);
  }

  /// Mengambil daftar komponen dari suatu bahan olahan.
  Future<List<ProcessedComponent>> getComponents(
    int processedIngredientId,
  ) async {
    return await _componentRepo.getByProcessedIngredientId(
      processedIngredientId,
    );
  }

  /// Menambahkan bahan olahan baru beserta komponen-komponennya secara atomik.
  Future<ProcessedIngredient> create({
    required String name,
    required double resultQuantity,
    required String resultUnit,
    required List<ProcessedComponent> components,
  }) async {
    final trimmedName = name.trim();

    // Validasi nama
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama bahan olahan wajib diisi.');
    }

    // Validasi kuantitas hasil
    if (resultQuantity <= 0) {
      throw const ValidationException(
        'Jumlah hasil olahan harus lebih besar dari 0.',
      );
    }

    // Validasi satuan hasil
    if (!allowedResultUnits.contains(resultUnit)) {
      throw ValidationException(
        'Satuan hasil "$resultUnit" tidak valid. Gunakan salah satu dari: g, ml, pcs.',
      );
    }

    // Validasi jumlah komponen
    if (components.isEmpty) {
      throw const ValidationException(
        'Bahan olahan minimal harus memiliki 1 komponen.',
      );
    }

    // Validasi masing-masing komponen
    for (final comp in components) {
      ProcessedComponentRepository.validateComponent(comp);
    }

    final db = await _db;

    // Cek duplikasi nama pada bahan olahan aktif (case-insensitive)
    final existing = await db.query(
      TableNames.processedIngredients,
      where: 'LOWER(name) = LOWER(?) AND status = ?',
      whereArgs: [trimmedName, 'active'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException(
        'Bahan olahan aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // Eksekusi transaksi atomik
    return await _dbHelper.transaction<ProcessedIngredient>((txn) async {
      final insertMap = <String, dynamic>{
        'name': trimmedName,
        'result_quantity': resultQuantity,
        'result_unit': resultUnit,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      };

      final newId = await txn.insert(
        TableNames.processedIngredients,
        insertMap,
      );

      // Sisipkan komponen
      await _componentRepo.insertComponents(newId, components, executor: txn);

      return ProcessedIngredient(
        id: newId,
        name: trimmedName,
        resultQuantity: resultQuantity,
        resultUnit: resultUnit,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  /// Memperbarui informasi bahan olahan dan mengganti komponennya secara atomik.
  Future<ProcessedIngredient> update(
    int id, {
    required String name,
    required double resultQuantity,
    required String resultUnit,
    required List<ProcessedComponent> components,
  }) async {
    final trimmedName = name.trim();

    // Validasi nama
    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama bahan olahan wajib diisi.');
    }

    // Validasi kuantitas hasil
    if (resultQuantity <= 0) {
      throw const ValidationException(
        'Jumlah hasil olahan harus lebih besar dari 0.',
      );
    }

    // Validasi satuan hasil
    if (!allowedResultUnits.contains(resultUnit)) {
      throw ValidationException(
        'Satuan hasil "$resultUnit" tidak valid. Gunakan salah satu dari: g, ml, pcs.',
      );
    }

    // Validasi komponen
    if (components.isEmpty) {
      throw const ValidationException(
        'Bahan olahan minimal harus memiliki 1 komponen.',
      );
    }

    for (final comp in components) {
      ProcessedComponentRepository.validateComponent(comp);
    }

    final db = await _db;

    // Pastikan data lama ada
    final current = await getById(id);
    if (current == null) {
      throw const ValidationException('Bahan olahan tidak ditemukan.');
    }

    // Cek duplikasi dengan bahan olahan aktif lain
    final existing = await db.query(
      TableNames.processedIngredients,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [trimmedName, 'active', id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException(
        'Bahan olahan aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // Eksekusi transaksi atomik
    return await _dbHelper.transaction<ProcessedIngredient>((txn) async {
      await txn.update(
        TableNames.processedIngredients,
        {
          'name': trimmedName,
          'result_quantity': resultQuantity,
          'result_unit': resultUnit,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // Hapus komponen lama
      await _componentRepo.deleteByProcessedIngredientId(id, executor: txn);

      // Masukkan komponen baru
      await _componentRepo.insertComponents(id, components, executor: txn);

      return ProcessedIngredient(
        id: id,
        name: trimmedName,
        resultQuantity: resultQuantity,
        resultUnit: resultUnit,
        status: current.status,
        createdAt: current.createdAt,
        updatedAt: now,
      );
    });
  }

  /// Menonaktifkan bahan olahan (soft delete).
  Future<void> deactivate(int id) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    final count = await db.update(
      TableNames.processedIngredients,
      {'status': 'inactive', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (count == 0) {
      throw const ValidationException('Bahan olahan tidak ditemukan.');
    }
  }

  /// Mengaktifkan kembali bahan olahan yang nonaktif.
  /// Mencegah konflik nama dengan bahan olahan yang sedang aktif.
  Future<void> activate(int id) async {
    final db = await _db;
    final current = await getById(id);

    if (current == null) {
      throw const ValidationException('Bahan olahan tidak ditemukan.');
    }

    final existing = await db.query(
      TableNames.processedIngredients,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [current.name, 'active', id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException(
        'Sudah ada bahan olahan aktif lain dengan nama yang sama.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      TableNames.processedIngredients,
      {'status': 'active', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus bahan olahan secara permanen (CASCADE SQLite akan menghapus komponen).
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(
      TableNames.processedIngredients,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
