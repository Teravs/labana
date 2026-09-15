import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_constants.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/processed_ingredients/services/processed_dependency_validator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('ProcessedDependencyValidator In-Memory Algorithm Tests', () {
    test('1. Self-reference: A -> A ditolak dengan pesan yang sesuai', () {
      expect(
        () => ProcessedDependencyValidator.checkCycleInMemory(
          parentId: 1,
          childId: 1,
          graph: {},
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Bahan olahan tidak dapat menggunakan dirinya sendiri'),
          ),
        ),
      );
    });

    test('2. Direct cycle: A -> B, lalu B -> A ditolak', () {
      // Database saat ini: A (id: 1) punya child B (id: 2)
      final graph = {
        1: [2],
      };

      // Mencoba menambahkan B -> A (parentId: 2, childId: 1)
      expect(
        () => ProcessedDependencyValidator.checkCycleInMemory(
          parentId: 2,
          childId: 1,
          graph: graph,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('siklus ketergantungan'),
          ),
        ),
      );
    });

    test('3. Three-level cycle: A -> B -> C, lalu C -> A ditolak', () {
      // Database: A (1) -> B (2) -> C (3)
      final graph = {
        1: [2],
        2: [3],
      };

      // Mencoba C -> A (parentId: 3, childId: 1)
      expect(
        () => ProcessedDependencyValidator.checkCycleInMemory(
          parentId: 3,
          childId: 1,
          graph: graph,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('siklus ketergantungan'),
          ),
        ),
      );
    });

    test('4. Four-level cycle: A -> B -> C -> D, lalu D -> A ditolak', () {
      // Database: A (1) -> B (2) -> C (3) -> D (4)
      final graph = {
        1: [2],
        2: [3],
        3: [4],
      };

      // Mencoba D -> A (parentId: 4, childId: 1)
      expect(
        () => ProcessedDependencyValidator.checkCycleInMemory(
          parentId: 4,
          childId: 1,
          graph: graph,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('siklus ketergantungan'),
          ),
        ),
      );
    });

    test('5. Valid chain: A -> B -> C diterima', () {
      // Database: B (2) -> C (3)
      final graph = {
        2: [3],
      };

      // Mencoba A -> B (parentId: 1, childId: 2)
      final result = ProcessedDependencyValidator.checkCycleInMemory(
        parentId: 1,
        childId: 2,
        graph: graph,
      );
      expect(result, isTrue);
    });

    test('6. Valid independent branches: A -> B dan A -> C diterima', () {
      // Database: A (1) sudah punya child B (2)
      final graph = {
        1: [2],
      };

      // Menambahkan child kedua C (3) ke A (1)
      final result = ProcessedDependencyValidator.checkCycleInMemory(
        parentId: 1,
        childId: 3,
        graph: graph,
      );
      expect(result, isTrue);
    });

    test('7. Diamond DAG: A -> B -> D dan A -> C -> D diterima', () {
      // Database: B (2) -> D (4), C (3) -> D (4)
      final graph = {
        2: [4],
        3: [4],
      };

      // A (1) menambahkan B (2) dan C (3)
      final res1 = ProcessedDependencyValidator.checkCycleInMemory(
        parentId: 1,
        childId: 2,
        graph: graph,
      );
      final res2 = ProcessedDependencyValidator.checkCycleInMemory(
        parentId: 1,
        childId: 3,
        graph: graph,
      );
      expect(res1, isTrue);
      expect(res2, isTrue);
    });

    test('8. ParentId null (item baru) selalu diterima jika child valid', () {
      final graph = {
        1: [2],
      };

      final result = ProcessedDependencyValidator.checkCycleInMemory(
        parentId: null,
        childId: 1,
        graph: graph,
      );
      expect(result, isTrue);
    });
  });

  group('ProcessedDependencyValidator SQLite Integration Tests', () {
    late Database testDb;
    late ProcessedDependencyValidator validator;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: DatabaseHelper.onConfigure,
        onCreate: DatabaseHelper.onCreate,
        onUpgrade: DatabaseHelper.onUpgrade,
      );
      DatabaseHelper.instance.setTestDatabase(testDb);
      validator = ProcessedDependencyValidator();
    });

    tearDown(() async {
      await testDb.close();
      DatabaseHelper.instance.setTestDatabase(null);
    });

    Future<int> insertProcessed(String name) async {
      return await testDb.insert(TableNames.processedIngredients, {
        'name': name,
        'result_quantity': 1000.0,
        'result_unit': 'ml',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    Future<void> addProcessedComponent({
      required int parentId,
      required int childId,
    }) async {
      await testDb.insert(TableNames.processedComponents, {
        'processed_ingredient_id': parentId,
        'component_type': ProcessedComponent.typeProcessed,
        'child_processed_id': childId,
        'quantity': 100.0,
        'unit': 'ml',
      });
    }

    test('SQLite: canAddChild mendeteksi siklus dan self-reference', () async {
      final aId = await insertProcessed('Bahan A');
      final bId = await insertProcessed('Bahan B');
      final cId = await insertProcessed('Bahan C');

      // Setup relasi A -> B -> C
      await addProcessedComponent(parentId: aId, childId: bId);
      await addProcessedComponent(parentId: bId, childId: cId);

      // 1. Self-reference: A -> A
      expect(
        () => validator.canAddChild(aId, aId),
        throwsA(isA<ValidationException>()),
      );

      // 2. Direct cycle: B -> A
      expect(
        () => validator.canAddChild(bId, aId),
        throwsA(isA<ValidationException>()),
      );

      // 3. 3-level cycle: C -> A
      expect(
        () => validator.canAddChild(cId, aId),
        throwsA(isA<ValidationException>()),
      );

      // 4. Valid new branch: C -> D (item baru)
      final dId = await insertProcessed('Bahan D');
      final canAddD = await validator.canAddChild(cId, dId);
      expect(canAddD, isTrue);
    });

    test('SQLite: validateComponents memvalidasi list komponen', () async {
      final aId = await insertProcessed('Bahan A');
      final bId = await insertProcessed('Bahan B');

      await addProcessedComponent(parentId: aId, childId: bId);

      // Update B dengan komponen A -> harus ditolak
      final invalidComponents = [
        const ProcessedComponent(
          componentType: ProcessedComponent.typeProcessed,
          childProcessedId: 1, // aId
          quantity: 50.0,
          unit: 'ml',
        ),
      ];

      expect(
        () => validator.validateComponents(bId, invalidComponents),
        throwsA(isA<ValidationException>()),
      );
    });

    test('SQLite: getValidChildCandidates menyaring diri sendiri dan ancestor', () async {
      final aId = await insertProcessed('Bahan A');
      final bId = await insertProcessed('Bahan B');
      final cId = await insertProcessed('Bahan C');
      await insertProcessed('Bahan D');

      // Relasi: A -> B -> C
      await addProcessedComponent(parentId: aId, childId: bId);
      await addProcessedComponent(parentId: bId, childId: cId);

      // Kandidat untuk C:
      // - Tidak boleh C (diri sendiri)
      // - Tidak boleh A (ancestor)
      // - Tidak boleh B (ancestor)
      // - D boleh!
      final candidatesForC = await validator.getValidChildCandidates(
        currentProcessedId: cId,
      );

      final candidateNames = candidatesForC.map((c) => c.name).toList();
      expect(candidateNames, contains('Bahan D'));
      expect(candidateNames, isNot(contains('Bahan C')));
      expect(candidateNames, isNot(contains('Bahan B')));
      expect(candidateNames, isNot(contains('Bahan A')));
    });
  });
}
