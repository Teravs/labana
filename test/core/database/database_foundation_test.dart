import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> createTestDb({int version = 1}) async {
    return await openDatabase(
      inMemoryDatabasePath,
      version: version,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
      onUpgrade: DatabaseHelper.onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Test 1: Database dapat dibuat/open
  // ---------------------------------------------------------------------------
  test('Test 1: Database dapat dibuat dan dibuka dengan benar', () async {
    final db = await createTestDb();
    expect(db.isOpen, isTrue);
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Test 2: Semua 12 tabel berhasil dibuat
  // ---------------------------------------------------------------------------
  test('Test 2: Semua 12 tabel Labana berhasil dibuat di SQLite', () async {
    final db = await createTestDb();
    final tablesResult = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY name ASC;",
    );
    final createdTableNames = tablesResult
        .map((row) => row['name'] as String)
        .toSet();

    expect(createdTableNames.length, 12);
    for (final expectedTable in TableNames.all) {
      expect(
        createdTableNames.contains(expectedTable),
        isTrue,
        reason: 'Tabel $expectedTable harus ada di database',
      );
    }
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Test 3: Foreign key aktif
  // ---------------------------------------------------------------------------
  test(
    'Test 3: SQLite Foreign Key constraints aktif (PRAGMA foreign_keys = ON)',
    () async {
      final db = await createTestDb();
      final pragmaResult = await db.rawQuery('PRAGMA foreign_keys;');
      expect(pragmaResult.isNotEmpty, isTrue);
      expect(pragmaResult.first['foreign_keys'], 1);
      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 4: Constraint status bekerja
  // ---------------------------------------------------------------------------
  test(
    'Test 4: Constraint status pada ingredients bekerja (status invalid ditolak)',
    () async {
      final db = await createTestDb();

      // Status valid: active
      final id1 = await db.insert(TableNames.ingredients, {
        'name': 'Gula Pasir',
        'status': 'active',
      });
      expect(id1, greaterThan(0));

      // Status valid: inactive
      final id2 = await db.insert(TableNames.ingredients, {
        'name': 'Gula Merah',
        'status': 'inactive',
      });
      expect(id2, greaterThan(0));

      // Status invalid: ditolak
      expect(
        () async => await db.insert(TableNames.ingredients, {
          'name': 'Gula Batu',
          'status': 'pending',
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 5: Payment method invalid ditolak
  // ---------------------------------------------------------------------------
  test(
    'Test 5: Payment method invalid pada sales ditolak oleh CHECK constraint',
    () async {
      final db = await createTestDb();

      // Payment method valid: cash, qris, transfer
      await db.insert(TableNames.sales, {
        'transaction_number': 'TRX-001',
        'transaction_date': '2026-09-12 10:00:00',
        'payment_method': 'cash',
        'total_amount': 15000,
        'total_hpp': 8000,
        'total_profit': 7000,
      });

      await db.insert(TableNames.sales, {
        'transaction_number': 'TRX-002',
        'transaction_date': '2026-09-12 10:05:00',
        'payment_method': 'qris',
        'total_amount': 25000,
        'total_hpp': 12000,
        'total_profit': 13000,
      });

      // Payment method invalid: credit_card -> harus ditolak
      expect(
        () async => await db.insert(TableNames.sales, {
          'transaction_number': 'TRX-003',
          'transaction_date': '2026-09-12 10:10:00',
          'payment_method': 'credit_card',
          'total_amount': 30000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 6: Ingredient price pack tanpa package_quantity ditolak
  // ---------------------------------------------------------------------------
  test(
    'Test 6: Ingredient price dengan unit pack tanpa package_quantity ditolak',
    () async {
      final db = await createTestDb();
      final ingredientId = await db.insert(TableNames.ingredients, {
        'name': 'Sedotan Steril',
        'status': 'active',
      });

      // unit = 'pack' tetapi package_quantity = null -> ditolak
      expect(
        () async => await db.insert(TableNames.ingredientPrices, {
          'ingredient_id': ingredientId,
          'purchase_quantity': 1.0,
          'purchase_unit': 'pack',
          'base_quantity': 100.0,
          'base_unit': 'pcs',
          'package_quantity': null,
          'price': 15000,
          'effective_from': '2026-09-12',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // unit = 'pack' dengan package_quantity valid -> sukses
      final priceId = await db.insert(TableNames.ingredientPrices, {
        'ingredient_id': ingredientId,
        'purchase_quantity': 1.0,
        'purchase_unit': 'pack',
        'base_quantity': 100.0,
        'base_unit': 'pcs',
        'package_quantity': 100.0,
        'price': 15000,
        'effective_from': '2026-09-12',
      });
      expect(priceId, greaterThan(0));

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 7: Ingredient price non-pack dengan package_quantity tidak null ditolak
  // ---------------------------------------------------------------------------
  test(
    'Test 7: Ingredient price non-pack dengan package_quantity tidak null ditolak',
    () async {
      final db = await createTestDb();
      final ingredientId = await db.insert(TableNames.ingredients, {
        'name': 'Gula Pasir',
        'status': 'active',
      });

      // purchase_unit = 'kg' (non-pack) tetapi package_quantity diisi 10.0 -> ditolak
      expect(
        () async => await db.insert(TableNames.ingredientPrices, {
          'ingredient_id': ingredientId,
          'purchase_quantity': 1.0,
          'purchase_unit': 'kg',
          'base_quantity': 1000.0,
          'base_unit': 'g',
          'package_quantity': 10.0,
          'price': 18000,
          'effective_from': '2026-09-12',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // purchase_unit = 'kg' dengan package_quantity = null -> sukses
      final priceId = await db.insert(TableNames.ingredientPrices, {
        'ingredient_id': ingredientId,
        'purchase_quantity': 1.0,
        'purchase_unit': 'kg',
        'base_quantity': 1000.0,
        'base_unit': 'g',
        'package_quantity': null,
        'price': 18000,
        'effective_from': '2026-09-12',
      });
      expect(priceId, greaterThan(0));

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 8: Recipe item ingredient tanpa ingredient_id ditolak
  // ---------------------------------------------------------------------------
  test(
    'Test 8: Recipe item component_type ingredient tanpa ingredient_id ditolak',
    () async {
      final db = await createTestDb();
      final productId = await db.insert(TableNames.products, {
        'name': 'Es Teh Manis',
        'status': 'active',
      });
      final versionId = await db.insert(TableNames.recipeVersions, {
        'product_id': productId,
        'version_number': 1,
        'effective_from': '2026-09-12',
        'status': 'active',
      });

      // component_type = 'ingredient' tapi ingredient_id = null -> ditolak
      expect(
        () async => await db.insert(TableNames.recipeItems, {
          'recipe_version_id': versionId,
          'component_type': 'ingredient',
          'ingredient_id': null,
          'processed_ingredient_id': null,
          'quantity': 20.0,
          'unit': 'g',
          'other_cost': null,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Jika ingredient_id diberikan -> sukses
      final ingredientId = await db.insert(TableNames.ingredients, {
        'name': 'Daun Teh',
        'status': 'active',
      });

      final recipeItemId = await db.insert(TableNames.recipeItems, {
        'recipe_version_id': versionId,
        'component_type': 'ingredient',
        'ingredient_id': ingredientId,
        'processed_ingredient_id': null,
        'quantity': 5.0,
        'unit': 'g',
        'other_cost': null,
      });
      expect(recipeItemId, greaterThan(0));

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 9: Recipe item other harus menggunakan other_cost
  // ---------------------------------------------------------------------------
  test(
    'Test 9: Recipe item component_type other harus menggunakan other_cost',
    () async {
      final db = await createTestDb();
      final productId = await db.insert(TableNames.products, {
        'name': 'Kopi Susu',
        'status': 'active',
      });
      final versionId = await db.insert(TableNames.recipeVersions, {
        'product_id': productId,
        'version_number': 1,
        'effective_from': '2026-09-12',
        'status': 'active',
      });

      // other_cost = null -> ditolak
      expect(
        () async => await db.insert(TableNames.recipeItems, {
          'recipe_version_id': versionId,
          'component_type': 'other',
          'ingredient_id': null,
          'processed_ingredient_id': null,
          'quantity': null,
          'unit': null,
          'other_cost': null,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // other_cost < 0 -> ditolak
      expect(
        () async => await db.insert(TableNames.recipeItems, {
          'recipe_version_id': versionId,
          'component_type': 'other',
          'ingredient_id': null,
          'processed_ingredient_id': null,
          'quantity': null,
          'unit': null,
          'other_cost': -500,
        }),
        throwsA(isA<DatabaseException>()),
      );

      // other_cost valid -> sukses
      final itemId = await db.insert(TableNames.recipeItems, {
        'recipe_version_id': versionId,
        'component_type': 'other',
        'ingredient_id': null,
        'processed_ingredient_id': null,
        'quantity': null,
        'unit': null,
        'other_cost': 500,
      });
      expect(itemId, greaterThan(0));

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 10: Foreign key ON DELETE RESTRICT bekerja
  // ---------------------------------------------------------------------------
  test(
    'Test 10: Foreign key ON DELETE RESTRICT mencegah penghapusan parent yang memiliki relasi',
    () async {
      final db = await createTestDb();

      // Buat ingredient dan harga terkait
      final ingredientId = await db.insert(TableNames.ingredients, {
        'name': 'Susu UHT',
        'status': 'active',
      });

      await db.insert(TableNames.ingredientPrices, {
        'ingredient_id': ingredientId,
        'purchase_quantity': 1.0,
        'purchase_unit': 'liter',
        'base_quantity': 1000.0,
        'base_unit': 'ml',
        'price': 20000,
        'effective_from': '2026-09-12',
      });

      // Menghapus ingredient yang masih direferensikan harus digagalkan oleh SQLite
      expect(
        () async => await db.delete(
          TableNames.ingredients,
          where: 'id = ?',
          whereArgs: [ingredientId],
        ),
        throwsA(isA<DatabaseException>()),
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 11: processed_components child relation direferensikan dengan benar
  // ---------------------------------------------------------------------------
  test(
    'Test 11: processed_components child relation dapat direferensikan dengan benar',
    () async {
      final db = await createTestDb();

      // 1. Buat parent processed_ingredient
      final parentId = await db.insert(TableNames.processedIngredients, {
        'name': 'Larutan Gula',
        'result_quantity': 5000.0,
        'result_unit': 'ml',
        'status': 'active',
      });

      // 2. Buat ingredient mentah
      final rawIngredientId = await db.insert(TableNames.ingredients, {
        'name': 'Gula Pasir',
        'status': 'active',
      });

      // 3. Buat child processed_ingredient lain
      final childProcessedId = await db
          .insert(TableNames.processedIngredients, {
            'name': 'Air Matang',
            'result_quantity': 10000.0,
            'result_unit': 'ml',
            'status': 'active',
          });

      // Insert komponen tipe ingredient
      await db.insert(TableNames.processedComponents, {
        'processed_ingredient_id': parentId,
        'component_type': 'ingredient',
        'ingredient_id': rawIngredientId,
        'child_processed_id': null,
        'quantity': 1000.0,
        'unit': 'g',
        'other_cost': null,
      });

      // Insert komponen tipe processed
      await db.insert(TableNames.processedComponents, {
        'processed_ingredient_id': parentId,
        'component_type': 'processed',
        'ingredient_id': null,
        'child_processed_id': childProcessedId,
        'quantity': 4000.0,
        'unit': 'ml',
        'other_cost': null,
      });

      // Insert komponen tipe other
      await db.insert(TableNames.processedComponents, {
        'processed_ingredient_id': parentId,
        'component_type': 'other',
        'ingredient_id': null,
        'child_processed_id': null,
        'quantity': null,
        'unit': null,
        'other_cost': 2000,
      });

      // Verifikasi 3 komponen tersimpan
      final components = await db.query(
        TableNames.processedComponents,
        where: 'processed_ingredient_id = ?',
        whereArgs: [parentId],
      );
      expect(components.length, 3);

      // Verifikasi ON DELETE CASCADE dari parent ke processed_components
      await db.delete(
        TableNames.processedIngredients,
        where: 'id = ?',
        whereArgs: [parentId],
      );

      final remainingComponents = await db.query(
        TableNames.processedComponents,
        where: 'processed_ingredient_id = ?',
        whereArgs: [parentId],
      );
      expect(remainingComponents.isEmpty, isTrue);

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Test 12: Database upgrade dari version 1 tanpa kehilangan struktur
  // ---------------------------------------------------------------------------
  test(
    'Test 12: Database dapat di-upgrade dari version 1 tanpa kehilangan struktur',
    () async {
      final databasesPath = await getDatabasesPath();
      final tempDbPath = '$databasesPath/test_labana_upgrade.db';

      // Pastikan DB sementara bersih sebelum tes
      await deleteDatabase(tempDbPath);

      // 1. Inisialisasi DB di version 1
      final dbV1 = await openDatabase(
        tempDbPath,
        version: 1,
        onConfigure: DatabaseHelper.onConfigure,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      );
      await dbV1.insert(TableNames.settings, {
        'key': 'app_theme',
        'value': 'dark',
      });
      await dbV1.close();

      // 2. Buka DB yang sama dengan versi dinaikkan ke version 2
      final dbV2 = await openDatabase(
        tempDbPath,
        version: 2,
        onConfigure: DatabaseHelper.onConfigure,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      );

      // Verifikasi tabel settings dan datanya tetap utuh
      final settingRows = await dbV2.query(TableNames.settings);
      expect(settingRows.isNotEmpty, isTrue);
      expect(settingRows.first['value'], 'dark');

      // Verifikasi seluruh 12 tabel masih ada
      final tablesResult = await dbV2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata';",
      );
      expect(tablesResult.length, 12);

      await dbV2.close();
      await deleteDatabase(tempDbPath);
    },
  );
}
