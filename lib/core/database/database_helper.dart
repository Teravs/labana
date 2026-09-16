import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';
import 'database_migrations.dart';
import 'database_schema.dart';

/// Service singleton untuk mengelola koneksi, inisialisasi, dan transaksi database SQLite Labana.
class DatabaseHelper {
  DatabaseHelper._internal();

  /// Instance singleton utama DatabaseHelper.
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _database;

  /// Mengembalikan instance database aktif. Membuka database jika belum terbuka.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database di local application storage.
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, DatabaseConstants.databaseName);

    return await openDatabase(
      dbPath,
      version: DatabaseConstants.databaseVersion,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  /// Memastikan SQLite Foreign Keys aktif pada setiap pembukaan koneksi.
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Membuat seluruh skema tabel versi awal (version 1).
  static Future<void> onCreate(Database db, int version) async {
    await DatabaseSchema.createSchema(db);
  }

  /// Menjalankan migrasi bertahap jika versi database dinaikkan.
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await DatabaseMigrations.migrate(db, oldVersion, newVersion);
  }

  /// Eksekusi operasi multi-tabel dalam transaksi atomik SQLite yang aman.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Mengembalikan path absolut berkas database SQLite aktif.
  Future<String> getDatabasePath() async {
    if (_database != null &&
        _database!.isOpen &&
        _database!.path.isNotEmpty &&
        _database!.path != inMemoryDatabasePath) {
      return _database!.path;
    }
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, DatabaseConstants.databaseName);
  }

  /// Menjalankan PRAGMA wal_checkpoint(FULL) jika koneksi aktif untuk mengonsolidasikan seluruh log WAL ke file utama.
  Future<void> checkpoint() async {
    if (_database != null && _database!.isOpen) {
      try {
        await _database!.execute('PRAGMA wal_checkpoint(FULL);');
      } catch (_) {
        // Abaikan jika mode jurnal non-WAL atau database in-memory
      }
    }
  }

  /// Menutup koneksi database jika sedang terbuka.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  /// Menutup koneksi database lama dan membuka instance database baru secara bersih.
  Future<Database> reopenDatabase() async {
    await close();
    return await database;
  }

  /// Menyetel instance database khusus untuk kebutuhan unit testing (in-memory).
  void setTestDatabase(Database? testDb) {
    _database = testDb;
  }
}
