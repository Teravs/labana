import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/recipe_version.dart';

/// Repository untuk pengelolaan data tabel `recipe_versions`.
class RecipeVersionRepository {
  final DatabaseHelper _dbHelper;

  RecipeVersionRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Mengambil semua versi resep untuk suatu produk, diurutkan dari versi terbaru.
  Future<List<RecipeVersion>> getByProductId(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.recipeVersions,
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'version_number DESC',
    );
    return results.map((m) => RecipeVersion.fromMap(m)).toList();
  }

  /// Mengambil versi resep yang saat ini aktif untuk produk tersebut.
  Future<RecipeVersion?> getActiveVersion(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.recipeVersions,
      where: 'product_id = ? AND status = ?',
      whereArgs: [productId, 'active'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return RecipeVersion.fromMap(results.first);
  }

  /// Mengambil versi resep berdasarkan [id].
  Future<RecipeVersion?> getById(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;
    final results = await exec.query(
      TableNames.recipeVersions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return RecipeVersion.fromMap(results.first);
  }

  /// Menghitung nomor versi berikutnya secara otomatis: `MAX(version_number) + 1`.
  Future<int> getNextVersionNumber(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final result = await exec.rawQuery('''
      SELECT COALESCE(MAX(version_number), 0) + 1 AS next_version
      FROM ${TableNames.recipeVersions}
      WHERE product_id = ?
    ''', [productId]);

    if (result.isNotEmpty && result.first['next_version'] != null) {
      return (result.first['next_version'] as num).toInt();
    }
    return 1;
  }

  /// Mengubah status versi resep yang sedang `active` menjadi `archived`.
  Future<int> archiveActiveVersions(
    int productId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    return await exec.update(
      TableNames.recipeVersions,
      {'status': 'archived'},
      where: 'product_id = ? AND status = ?',
      whereArgs: [productId, 'active'],
    );
  }

  /// Menyimpan satu versi resep baru.
  Future<RecipeVersion> create(
    RecipeVersion version, {
    DatabaseExecutor? executor,
  }) async {
    if (version.versionNumber <= 0) {
      throw const ValidationException('Nomor versi harus lebih besar dari 0.');
    }
    if (version.hppTotal < 0) {
      throw const ValidationException('HPP total tidak boleh negatif.');
    }
    if (version.effectiveFrom.trim().isEmpty) {
      throw const ValidationException('Tanggal efektif resep wajib diisi.');
    }

    final exec = executor ?? await _db;
    final map = version.toMap();
    final id = await exec.insert(TableNames.recipeVersions, map);
    return version.copyWith(id: id);
  }
}

