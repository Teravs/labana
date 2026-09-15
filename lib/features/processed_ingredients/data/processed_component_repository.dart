import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/processed_component.dart';

/// Repository untuk mengelola data komponen bahan olahan (`processed_components`).
class ProcessedComponentRepository {
  final DatabaseHelper _dbHelper;

  ProcessedComponentRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  /// Mengambil semua komponen untuk satu bahan olahan tertentu,
  /// lengkap dengan nama bahan mentah jika bertipe `ingredient`.
  Future<List<ProcessedComponent>> getByProcessedIngredientId(
    int processedIngredientId, {
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? await _db;
    final results = await client.rawQuery(
      '''
      SELECT 
        pc.id,
        pc.processed_ingredient_id,
        pc.component_type,
        pc.ingredient_id,
        pc.child_processed_id,
        pc.quantity,
        pc.unit,
        pc.other_cost,
        pc.created_at,
        i.name AS ingredient_name,
        child.name AS child_processed_name
      FROM ${TableNames.processedComponents} pc
      LEFT JOIN ${TableNames.ingredients} i ON pc.ingredient_id = i.id
      LEFT JOIN ${TableNames.processedIngredients} child ON pc.child_processed_id = child.id
      WHERE pc.processed_ingredient_id = ?
      ORDER BY pc.id ASC
      ''',
      [processedIngredientId],
    );

    return results.map((map) => ProcessedComponent.fromMap(map)).toList();
  }

  /// Memvalidasi integritas satu komponen sebelum disimpan.
  static void validateComponent(ProcessedComponent component) {
    if (component.componentType == ProcessedComponent.typeIngredient) {
      if (component.ingredientId == null) {
        throw const ValidationException(
          'Bahan mentah harus dipilih untuk komponen bertipe bahan mentah.',
        );
      }
      if (component.childProcessedId != null) {
        throw const ValidationException(
          'Bahan olahan anak tidak boleh diisi pada komponen bahan mentah.',
        );
      }
      if (component.quantity == null || component.quantity! <= 0) {
        throw const ValidationException(
          'Jumlah penggunaan bahan mentah harus lebih besar dari 0.',
        );
      }
      if (component.unit == null || component.unit!.trim().isEmpty) {
        throw const ValidationException(
          'Satuan penggunaan bahan mentah wajib diisi.',
        );
      }
      if (component.otherCost != null) {
        throw const ValidationException(
          'Biaya lainnya tidak boleh diisi pada komponen bahan mentah.',
        );
      }
    } else if (component.componentType == ProcessedComponent.typeProcessed) {
      if (component.childProcessedId == null) {
        throw const ValidationException(
          'Bahan olahan anak harus dipilih untuk komponen bertipe bahan olahan.',
        );
      }
      if (component.ingredientId != null) {
        throw const ValidationException(
          'Bahan mentah tidak boleh diisi pada komponen bahan olahan.',
        );
      }
      if (component.quantity == null || component.quantity! <= 0) {
        throw const ValidationException(
          'Jumlah penggunaan bahan olahan harus lebih besar dari 0.',
        );
      }
      if (component.unit == null || component.unit!.trim().isEmpty) {
        throw const ValidationException(
          'Satuan penggunaan bahan olahan wajib diisi.',
        );
      }
      if (component.otherCost != null) {
        throw const ValidationException(
          'Biaya lainnya tidak boleh diisi pada komponen bahan olahan.',
        );
      }
    } else if (component.componentType == ProcessedComponent.typeOther) {
      if (component.otherCost == null || component.otherCost! < 0) {
        throw const ValidationException(
          'Nominal biaya lainnya harus diisi dan tidak boleh negatif.',
        );
      }
      if (component.ingredientId != null) {
        throw const ValidationException(
          'Bahan mentah tidak boleh diisi pada komponen biaya lainnya.',
        );
      }
      if (component.childProcessedId != null) {
        throw const ValidationException(
          'Bahan olahan anak tidak boleh diisi pada komponen biaya lainnya.',
        );
      }
      if (component.quantity != null || component.unit != null) {
        throw const ValidationException(
          'Jumlah dan satuan tidak boleh diisi pada komponen biaya lainnya.',
        );
      }
    } else {
      throw ValidationException(
        'Tipe komponen "${component.componentType}" tidak didukung.',
      );
    }
  }

  /// Menyisipkan daftar komponen ke dalam tabel `processed_components`.
  Future<void> insertComponents(
    int processedIngredientId,
    List<ProcessedComponent> components, {
    required DatabaseExecutor executor,
  }) async {
    for (final comp in components) {
      validateComponent(comp);

      final insertMap = <String, dynamic>{
        'processed_ingredient_id': processedIngredientId,
        'component_type': comp.componentType,
        'ingredient_id': comp.ingredientId,
        'child_processed_id': comp.childProcessedId,
        'quantity': comp.quantity,
        'unit': comp.unit,
        'other_cost': comp.otherCost,
      };

      await executor.insert(TableNames.processedComponents, insertMap);
    }
  }

  /// Menghapus seluruh komponen milik suatu bahan olahan.
  Future<int> deleteByProcessedIngredientId(
    int processedIngredientId, {
    required DatabaseExecutor executor,
  }) async {
    return await executor.delete(
      TableNames.processedComponents,
      where: 'processed_ingredient_id = ?',
      whereArgs: [processedIngredientId],
    );
  }
}
