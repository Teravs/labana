import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/recipe_item.dart';

/// Repository untuk pengelolaan data tabel `recipe_items`.
class RecipeItemRepository {
  final DatabaseHelper _dbHelper;

  RecipeItemRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// Memvalidasi integritas data [RecipeItem] sesuai dengan aturan database.
  ///
  /// Menolak item jika:
  /// - Tipe komponen tidak dikenal.
  /// - Field yang tidak sesuai dengan tipe terisi/tidak terisi.
  /// - Kuantitas <= 0 untuk bahan mentah/olahan.
  /// - Biaya < 0 untuk biaya lainnya.
  static void validateItem(RecipeItem item) {
    switch (item.componentType) {
      case RecipeItem.typeIngredient:
        if (item.ingredientId == null) {
          throw const ValidationException(
            'Bahan mentah wajib dipilih untuk komponen bahan mentah.',
          );
        }
        if (item.processedIngredientId != null) {
          throw const ValidationException(
            'ID bahan olahan harus kosong untuk komponen bahan mentah.',
          );
        }
        if (item.otherCost != null) {
          throw const ValidationException(
            'Biaya lainnya harus kosong untuk komponen bahan mentah.',
          );
        }
        if (item.quantity == null || item.quantity! <= 0) {
          throw const ValidationException(
            'Jumlah bahan mentah harus lebih besar dari 0.',
          );
        }
        if (item.unit == null || item.unit!.trim().isEmpty) {
          throw const ValidationException(
            'Satuan bahan mentah wajib ditentukan.',
          );
        }
        break;

      case RecipeItem.typeProcessed:
        if (item.processedIngredientId == null) {
          throw const ValidationException(
            'Bahan olahan wajib dipilih untuk komponen bahan olahan.',
          );
        }
        if (item.ingredientId != null) {
          throw const ValidationException(
            'ID bahan mentah harus kosong untuk komponen bahan olahan.',
          );
        }
        if (item.otherCost != null) {
          throw const ValidationException(
            'Biaya lainnya harus kosong untuk komponen bahan olahan.',
          );
        }
        if (item.quantity == null || item.quantity! <= 0) {
          throw const ValidationException(
            'Jumlah bahan olahan harus lebih besar dari 0.',
          );
        }
        if (item.unit == null || item.unit!.trim().isEmpty) {
          throw const ValidationException(
            'Satuan bahan olahan wajib ditentukan.',
          );
        }
        break;

      case RecipeItem.typeOther:
        if (item.ingredientId != null || item.processedIngredientId != null) {
          throw const ValidationException(
            'ID bahan harus kosong untuk komponen biaya lainnya.',
          );
        }
        if (item.quantity != null || item.unit != null) {
          throw const ValidationException(
            'Jumlah dan satuan harus kosong untuk komponen biaya lainnya.',
          );
        }
        if (item.otherCost == null || item.otherCost! < 0) {
          throw const ValidationException(
            'Nominal biaya lainnya tidak boleh negatif.',
          );
        }
        break;

      default:
        throw ValidationException(
          'Tipe komponen "${item.componentType}" tidak valid.',
        );
    }
  }

  /// Memvalidasi bahwa bahan sumber (ingredient atau processed) aktif di database.
  /// Digunakan saat membuat resep baru.
  static Future<void> validateSourcesActive(
    RecipeItem item,
    DatabaseExecutor executor,
  ) async {
    if (item.isIngredient && item.ingredientId != null) {
      final res = await executor.query(
        TableNames.ingredients,
        columns: ['status', 'name'],
        where: 'id = ?',
        whereArgs: [item.ingredientId],
        limit: 1,
      );
      if (res.isEmpty) {
        throw const ValidationException('Bahan mentah tidak ditemukan.');
      }
      if (res.first['status'] != 'active') {
        final name = res.first['name'] as String? ?? 'Bahan mentah';
        throw ValidationException(
          'Bahan mentah "$name" tidak aktif dan tidak dapat digunakan untuk resep baru.',
        );
      }
    }

    if (item.isProcessed && item.processedIngredientId != null) {
      final res = await executor.query(
        TableNames.processedIngredients,
        columns: ['status', 'name'],
        where: 'id = ?',
        whereArgs: [item.processedIngredientId],
        limit: 1,
      );
      if (res.isEmpty) {
        throw const ValidationException('Bahan olahan tidak ditemukan.');
      }
      if (res.first['status'] != 'active') {
        final name = res.first['name'] as String? ?? 'Bahan olahan';
        throw ValidationException(
          'Bahan olahan "$name" tidak aktif dan tidak dapat digunakan untuk resep baru.',
        );
      }
    }
  }

  /// Mengambil semua komponen resep berdasarkan [recipeVersionId].
  ///
  /// Dilengkapi LEFT JOIN dengan tabel `ingredients` dan `processed_ingredients`
  /// sehingga nama bahan tetap terbaca walaupun master bahannya sudah berstatus inactive.
  Future<List<RecipeItem>> getByRecipeVersionId(
    int recipeVersionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    final results = await exec.rawQuery('''
      SELECT 
        ri.*,
        i.name AS ingredient_name,
        pi.name AS processed_ingredient_name
      FROM ${TableNames.recipeItems} ri
      LEFT JOIN ${TableNames.ingredients} i 
        ON ri.ingredient_id = i.id
      LEFT JOIN ${TableNames.processedIngredients} pi 
        ON ri.processed_ingredient_id = pi.id
      WHERE ri.recipe_version_id = ?
      ORDER BY ri.id ASC
    ''', [recipeVersionId]);

    return results.map((m) => RecipeItem.fromMap(m)).toList();
  }

  /// Menyimpan satu item resep baru.
  Future<RecipeItem> create(RecipeItem item, {DatabaseExecutor? executor}) async {
    validateItem(item);
    final exec = executor ?? await _db;
    await validateSourcesActive(item, exec);

    final map = item.toMap();
    final id = await exec.insert(TableNames.recipeItems, map);
    return item.copyWith(id: id);
  }

  /// Menyimpan beberapa item resep sekaligus secara batch/transaksional.
  Future<List<RecipeItem>> createMany(
    List<RecipeItem> items, {
    DatabaseExecutor? executor,
    bool validateActive = true,
  }) async {
    final exec = executor ?? await _db;
    final created = <RecipeItem>[];

    for (final item in items) {
      validateItem(item);
      if (validateActive) {
        await validateSourcesActive(item, exec);
      }
      final map = item.toMap();
      final id = await exec.insert(TableNames.recipeItems, map);
      created.add(item.copyWith(id: id));
    }

    return created;
  }

  /// Menghapus satu item resep berdasarkan [id].
  Future<int> delete(int id, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await _db;
    return await exec.delete(
      TableNames.recipeItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus semua item resep untuk [recipeVersionId].
  Future<int> deleteByRecipeVersionId(
    int recipeVersionId, {
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? await _db;
    return await exec.delete(
      TableNames.recipeItems,
      where: 'recipe_version_id = ?',
      whereArgs: [recipeVersionId],
    );
  }
}

