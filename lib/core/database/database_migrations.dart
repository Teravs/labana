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
    for (int targetVersion = oldVersion + 1;
        targetVersion <= newVersion;
        targetVersion++) {
      await _applyMigration(db, targetVersion);
    }
  }

  static Future<void> _applyMigration(Database db, int targetVersion) async {
    switch (targetVersion) {
      // Tempat penambahan migrasi versi masa depan (misal: case 2: ...).
      // Saat ini skema awal dimulai pada versi 1 (ditangani oleh onCreate).
      default:
        break;
    }
  }
}

