import 'package:sqflite/sqflite.dart';

/// Mengelola migrasi skema database bertahap dari satu versi ke versi berikutnya.
class DatabaseMigrations {
  DatabaseMigrations._();

  /// Menjalankan migrasi secara berurutan dari [oldVersion] ke [newVersion].
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (
      int targetVersion = oldVersion + 1;
      targetVersion <= newVersion;
      targetVersion++
    ) {
      await _applyMigration(db, targetVersion);
    }
  }

  static Future<void> _applyMigration(Database db, int targetVersion) async {
    switch (targetVersion) {
      case 2:
        // Tambah kolom label untuk menyimpan nama biaya lainnya (typeOther) jika belum ada.
        final columns = await db.rawQuery('PRAGMA table_info(recipe_items)');
        final hasLabel = columns.any((col) => col['name'] == 'label');
        if (!hasLabel) {
          await db.execute(
            'ALTER TABLE recipe_items ADD COLUMN label TEXT',
          );
        }
        break;
      default:
        break;
    }
  }
}
