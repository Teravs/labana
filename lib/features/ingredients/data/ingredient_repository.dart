import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/ingredient.dart';

/// Exception khusus untuk error validasi input bahan mentah.
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => message;
}

/// Repository untuk operasi CRUD bahan mentah pada tabel `ingredients`.
class IngredientRepository {
  final DatabaseHelper _dbHelper;

  IngredientRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  /// Mengambil daftar bahan berdasarkan [status] ('active' atau 'inactive').
  Future<List<Ingredient>> getAll({String status = 'active'}) async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredients,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return results.map((map) => Ingredient.fromMap(map)).toList();
  }

  /// Mengambil satu bahan berdasarkan [id].
  Future<Ingredient?> getById(int id) async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredients,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return Ingredient.fromMap(results.first);
  }

  /// Menambahkan bahan mentah baru dengan status 'active'.
  Future<Ingredient> create(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama bahan wajib diisi.');
    }

    final db = await _db;

    // Cek duplikasi nama pada bahan yang aktif (case-insensitive)
    final existing = await db.query(
      TableNames.ingredients,
      where: 'LOWER(name) = LOWER(?) AND status = ?',
      whereArgs: [trimmedName, 'active'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException('Bahan dengan nama tersebut sudah ada.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = await db.insert(TableNames.ingredients, {
      'name': trimmedName,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    });

    return Ingredient(
      id: id,
      name: trimmedName,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Memperbarui nama bahan yang ada.
  Future<Ingredient> update(int id, String newName) async {
    final trimmedName = newName.trim();

    if (trimmedName.isEmpty) {
      throw const ValidationException('Nama bahan wajib diisi.');
    }

    final db = await _db;

    // Cek keberadaan bahan
    final current = await getById(id);
    if (current == null) {
      throw const ValidationException('Bahan tidak ditemukan.');
    }

    // Cek duplikasi dengan bahan aktif lainnya (case-insensitive)
    final existing = await db.query(
      TableNames.ingredients,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [trimmedName, 'active', id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException('Bahan dengan nama tersebut sudah ada.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      TableNames.ingredients,
      {
        'name': trimmedName,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return current.copyWith(
      name: trimmedName,
      updatedAt: now,
    );
  }

  /// Menonaktifkan bahan (soft deactivation: status = 'inactive').
  Future<void> deactivate(int id) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      TableNames.ingredients,
      {
        'status': 'inactive',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mengaktifkan kembali bahan nonaktif (status = 'active').
  Future<void> activate(int id) async {
    final db = await _db;

    final target = await getById(id);
    if (target == null) {
      throw const ValidationException('Bahan tidak ditemukan.');
    }

    // Cek apakah ada bahan aktif lain dengan nama yang sama
    final existing = await db.query(
      TableNames.ingredients,
      where: 'LOWER(name) = LOWER(?) AND status = ? AND id != ?',
      whereArgs: [target.name, 'active', id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw const ValidationException(
        'Bahan aktif dengan nama tersebut sudah ada.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      TableNames.ingredients,
      {
        'status': 'active',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

