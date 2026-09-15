import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/data/processed_component_repository.dart';
import 'package:labana/features/processed_ingredients/data/processed_ingredient_repository.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late IngredientRepository ingredientRepo;
  late ProcessedIngredientRepository processedRepo;
  late ProcessedComponentRepository componentRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: DatabaseHelper.onConfigure,
      onCreate: DatabaseHelper.onCreate,
      onUpgrade: DatabaseHelper.onUpgrade,
    );
    DatabaseHelper.instance.setTestDatabase(db);
    ingredientRepo = IngredientRepository();
    componentRepo = ProcessedComponentRepository();
    processedRepo = ProcessedIngredientRepository(componentRepo: componentRepo);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('ProcessedIngredientRepository Tests', () {
    test('Create bahan olahan beserta komponen secara atomik', () async {
      final gula = await ingredientRepo.create('Gula Pasir');

      final components = [
        ProcessedComponent(
          componentType: ProcessedComponent.typeIngredient,
          ingredientId: gula.id,
          quantity: 500,
          unit: 'g',
        ),
        const ProcessedComponent(
          componentType: ProcessedComponent.typeOther,
          otherCost: 0,
        ),
      ];

      final created = await processedRepo.create(
        name: 'Simple Syrup',
        resultQuantity: 750,
        resultUnit: 'ml',
        components: components,
      );

      expect(created.id, isNotNull);
      expect(created.name, 'Simple Syrup');
      expect(created.resultQuantity, 750.0);
      expect(created.resultUnit, 'ml');
      expect(created.status, 'active');

      final savedComponents = await processedRepo.getComponents(created.id!);
      expect(savedComponents.length, 2);
      expect(
        savedComponents[0].componentType,
        ProcessedComponent.typeIngredient,
      );
      expect(savedComponents[0].ingredientId, gula.id);
      expect(savedComponents[0].ingredientName, 'Gula Pasir');
      expect(savedComponents[0].quantity, 500.0);
      expect(savedComponents[0].unit, 'g');
      expect(savedComponents[1].componentType, ProcessedComponent.typeOther);
      expect(savedComponents[1].otherCost, 0);
    });

    test('Update bahan olahan dan replace komponen secara atomik', () async {
      final susu = await ingredientRepo.create('Susu UHT');
      final skm = await ingredientRepo.create('Kental Manis');

      final created = await processedRepo.create(
        name: 'Milk Base',
        resultQuantity: 1000,
        resultUnit: 'ml',
        components: [
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: susu.id,
            quantity: 1000,
            unit: 'ml',
          ),
        ],
      );

      // Lakukan update: tambahkan SKM & ubah kuantitas hasil
      final updated = await processedRepo.update(
        created.id!,
        name: 'Milk Base Special',
        resultQuantity: 1200,
        resultUnit: 'ml',
        components: [
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: susu.id,
            quantity: 1000,
            unit: 'ml',
          ),
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: skm.id,
            quantity: 200,
            unit: 'ml',
          ),
        ],
      );

      expect(updated.name, 'Milk Base Special');
      expect(updated.resultQuantity, 1200.0);

      final components = await processedRepo.getComponents(created.id!);
      expect(components.length, 2);
      expect(components[1].ingredientName, 'Kental Manis');
    });

    test(
      'Mencegah duplikasi nama bahan olahan aktif (case-insensitive)',
      () async {
        final gula = await ingredientRepo.create('Gula');

        await processedRepo.create(
          name: 'Sirup Pandan',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 200,
              unit: 'g',
            ),
          ],
        );

        expect(
          () => processedRepo.create(
            name: '  sirup pandan  ',
            resultQuantity: 600,
            resultUnit: 'ml',
            components: [
              ProcessedComponent(
                componentType: ProcessedComponent.typeIngredient,
                ingredientId: gula.id,
                quantity: 250,
                unit: 'g',
              ),
            ],
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test('Deaktivasi dan reaktivasi bahan olahan (soft delete)', () async {
      final gula = await ingredientRepo.create('Gula Pasir');

      final item = await processedRepo.create(
        name: 'Sirup Aren',
        resultQuantity: 500,
        resultUnit: 'ml',
        components: [
          ProcessedComponent(
            componentType: ProcessedComponent.typeIngredient,
            ingredientId: gula.id,
            quantity: 200,
            unit: 'g',
          ),
        ],
      );

      // Deaktivasi
      await processedRepo.deactivate(item.id!);
      final activeList = await processedRepo.getAll(status: 'active');
      final inactiveList = await processedRepo.getAll(status: 'inactive');
      expect(activeList.any((i) => i.id == item.id), isFalse);
      expect(inactiveList.any((i) => i.id == item.id), isTrue);

      // Reaktivasi
      await processedRepo.activate(item.id!);
      final activeAfter = await processedRepo.getAll(status: 'active');
      expect(activeAfter.any((i) => i.id == item.id), isTrue);
    });

    test(
      'Mencegah reaktivasi jika sudah ada bahan aktif lain dengan nama sama',
      () async {
        final gula = await ingredientRepo.create('Gula');

        final item1 = await processedRepo.create(
          name: 'Sirup Lemon',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 200,
              unit: 'g',
            ),
          ],
        );

        // Nonaktifkan item 1
        await processedRepo.deactivate(item1.id!);

        // Buat item 2 dengan nama yang sama
        await processedRepo.create(
          name: 'Sirup Lemon',
          resultQuantity: 400,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 150,
              unit: 'g',
            ),
          ],
        );

        // Coba reaktivasi item 1 -> harus gagal
        expect(
          () => processedRepo.activate(item1.id!),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'Validasi input: hasil <= 0, komponen kosong, dan nested processed',
      () async {
        final gula = await ingredientRepo.create('Gula');

        // Hasil olahan <= 0
        expect(
          () => processedRepo.create(
            name: 'Sirup Nol',
            resultQuantity: 0,
            resultUnit: 'ml',
            components: [
              ProcessedComponent(
                componentType: ProcessedComponent.typeIngredient,
                ingredientId: gula.id,
                quantity: 100,
                unit: 'g',
              ),
            ],
          ),
          throwsA(isA<ValidationException>()),
        );

        // Komponen kosong
        expect(
          () => processedRepo.create(
            name: 'Sirup Kosong',
            resultQuantity: 500,
            resultUnit: 'ml',
            components: [],
          ),
          throwsA(isA<ValidationException>()),
        );

        // Satuan hasil tidak valid
        expect(
          () => processedRepo.create(
            name: 'Sirup Galon',
            resultQuantity: 1,
            resultUnit: 'galon',
            components: [
              ProcessedComponent(
                componentType: ProcessedComponent.typeIngredient,
                ingredientId: gula.id,
                quantity: 100,
                unit: 'g',
              ),
            ],
          ),
          throwsA(isA<ValidationException>()),
        );

        // Nested processed ingredient (childProcessedId != null)
        expect(
          () => processedRepo.create(
            name: 'Sirup Nested',
            resultQuantity: 500,
            resultUnit: 'ml',
            components: [
              const ProcessedComponent(
                componentType: ProcessedComponent.typeIngredient,
                childProcessedId: 99,
                quantity: 100,
                unit: 'ml',
              ),
            ],
          ),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'Cascade delete: menghapus bahan olahan otomatis menghapus komponennya',
      () async {
        final gula = await ingredientRepo.create('Gula Pasir');

        final created = await processedRepo.create(
          name: 'Sirup Hapus',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 200,
              unit: 'g',
            ),
          ],
        );

        expect((await processedRepo.getComponents(created.id!)).length, 1);

        await processedRepo.delete(created.id!);

        expect(await processedRepo.getById(created.id!), isNull);
        expect((await processedRepo.getComponents(created.id!)).length, 0);
      },
    );

    test(
      'Tahap 7: Create dan get bahan olahan dengan nested component',
      () async {
        final gula = await ingredientRepo.create('Gula');

        // 1. Buat child: Simple Syrup
        final child = await processedRepo.create(
          name: 'Simple Syrup',
          resultQuantity: 1000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 500,
              unit: 'g',
            ),
          ],
        );

        // 2. Buat parent: Sweet Tea Base menggunakan Simple Syrup sebagai nested component
        final parent = await processedRepo.create(
          name: 'Sweet Tea Base',
          resultQuantity: 2000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: child.id,
              quantity: 200,
              unit: 'ml',
            ),
            const ProcessedComponent(
              componentType: ProcessedComponent.typeOther,
              otherCost: 2000,
            ),
          ],
        );

        expect(parent.id, isNotNull);
        final components = await processedRepo.getComponents(parent.id!);
        expect(components.length, 2);

        final processedComp = components.firstWhere((c) => c.isProcessed);
        expect(processedComp.childProcessedId, child.id);
        expect(processedComp.childProcessedName, 'Simple Syrup');
        expect(processedComp.quantity, 200);
        expect(processedComp.unit, 'ml');
      },
    );

    test(
      'Tahap 7: Mencegah circular dependency pada repository (create dan update)',
      () async {
        final gula = await ingredientRepo.create('Gula');

        // A -> B
        final itemA = await processedRepo.create(
          name: 'Olahan A',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 100,
              unit: 'g',
            ),
          ],
        );

        final itemB = await processedRepo.create(
          name: 'Olahan B',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: itemA.id,
              quantity: 100,
              unit: 'ml',
            ),
          ],
        );

        // Coba update A agar menggunakan B -> Harus ditolak (A -> B -> A cycle)
        expect(
          () => processedRepo.update(
            itemA.id!,
            name: itemA.name,
            resultQuantity: itemA.resultQuantity,
            resultUnit: itemA.resultUnit,
            components: [
              ProcessedComponent(
                componentType: ProcessedComponent.typeProcessed,
                childProcessedId: itemB.id,
                quantity: 50,
                unit: 'ml',
              ),
            ],
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('siklus ketergantungan'),
            ),
          ),
        );
      },
    );

    test(
      'Tahap 7: Mencegah penghapusan bahan olahan jika masih dirujuk sebagai child',
      () async {
        final gula = await ingredientRepo.create('Gula');

        final child = await processedRepo.create(
          name: 'Sirup Utama',
          resultQuantity: 500,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeIngredient,
              ingredientId: gula.id,
              quantity: 100,
              unit: 'g',
            ),
          ],
        );

        await processedRepo.create(
          name: 'Minuman Jadi',
          resultQuantity: 1000,
          resultUnit: 'ml',
          components: [
            ProcessedComponent(
              componentType: ProcessedComponent.typeProcessed,
              childProcessedId: child.id,
              quantity: 100,
              unit: 'ml',
            ),
          ],
        );

        // Coba hapus child -> Harus ditolak
        expect(
          () => processedRepo.delete(child.id!),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              contains('masih digunakan oleh bahan olahan lain'),
            ),
          ),
        );
      },
    );
  });
}
