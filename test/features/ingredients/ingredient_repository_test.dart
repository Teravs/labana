import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/database/database_helper.dart';
import 'package:labana/features/ingredients/data/ingredient_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late IngredientRepository repository;

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
    repository = IngredientRepository();
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.instance.setTestDatabase(null);
  });

  group('IngredientRepository CRUD Tests', () {
    test('Create: Menambahkan bahan mentah baru dan tersimpan di database',
        () async {
      final ingredient = await repository.create('Gula Pasir');

      expect(ingredient.id, isNotNull);
      expect(ingredient.name, 'Gula Pasir');
      expect(ingredient.status, 'active');

      final saved = await repository.getById(ingredient.id!);
      expect(saved, isNotNull);
      expect(saved!.name, 'Gula Pasir');
      expect(saved.status, 'active');
    });

    test('Read: getAll(status: active) hanya mengembalikan bahan aktif',
        () async {
      final item1 = await repository.create('Gula Pasir');
      final item2 = await repository.create('Teh Celup');
      final item3 = await repository.create('Susu Kental Manis');

      // Nonaktifkan 1 item
      await repository.deactivate(item2.id!);

      final activeList = await repository.getAll(status: 'active');
      expect(activeList.length, 2);
      expect(activeList.map((i) => i.id), containsAll([item1.id, item3.id]));
      expect(activeList.map((i) => i.id), isNot(contains(item2.id)));

      final inactiveList = await repository.getAll(status: 'inactive');
      expect(inactiveList.length, 1);
      expect(inactiveList.first.id, item2.id);
    });

    test('Update: Mengubah nama bahan mentah berhasil memperbarui nama',
        () async {
      final created = await repository.create('Gula');

      final updated = await repository.update(created.id!, 'Gula Pasir Premium');
      expect(updated.name, 'Gula Pasir Premium');

      final fetched = await repository.getById(created.id!);
      expect(fetched!.name, 'Gula Pasir Premium');
    });

    test('Deactivate: Mengubah status bahan menjadi inactive', () async {
      final created = await repository.create('Kopi Arabika');

      await repository.deactivate(created.id!);

      final fetched = await repository.getById(created.id!);
      expect(fetched!.status, 'inactive');

      final activeList = await repository.getAll(status: 'active');
      expect(activeList.any((i) => i.id == created.id), isFalse);
    });

    test('Activate: Mengaktifkan kembali bahan inactive menjadi active',
        () async {
      final created = await repository.create('Sirup Vanila');
      await repository.deactivate(created.id!);

      expect((await repository.getById(created.id!))!.status, 'inactive');

      await repository.activate(created.id!);

      final fetched = await repository.getById(created.id!);
      expect(fetched!.status, 'active');

      final activeList = await repository.getAll(status: 'active');
      expect(activeList.any((i) => i.id == created.id), isTrue);
    });
  });

  group('IngredientRepository Validation Tests', () {
    test('Nama kosong ditolak dengan pesan yang sesuai', () async {
      expect(
        () => repository.create(''),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Nama bahan wajib diisi.',
          ),
        ),
      );
    });

    test('Nama hanya whitespace ditolak', () async {
      expect(
        () => repository.create('    '),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Nama bahan wajib diisi.',
          ),
        ),
      );
    });

    test('Nama dengan spasi di awal/akhir di-trim otomatis', () async {
      final ingredient = await repository.create('   Air Mineral   ');
      expect(ingredient.name, 'Air Mineral');
    });

    test('Duplicate active name ditolak', () async {
      await repository.create('Gula');

      expect(
        () => repository.create('Gula'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Bahan dengan nama tersebut sudah ada.',
          ),
        ),
      );
    });

    test('Duplicate active name case-insensitive ditolak', () async {
      await repository.create('Gula');

      expect(
        () => repository.create('gula'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Bahan dengan nama tersebut sudah ada.',
          ),
        ),
      );

      expect(
        () => repository.create('GULA'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Bahan dengan nama tersebut sudah ada.',
          ),
        ),
      );
    });

    test('Update ke nama yang sudah dipakai bahan aktif lain ditolak', () async {
      final item1 = await repository.create('Gula');
      final item2 = await repository.create('Garam');

      expect(
        () => repository.update(item2.id!, 'gula'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Bahan dengan nama tersebut sudah ada.',
          ),
        ),
      );

      // Tapi mengubah diri sendiri dengan casing sama/berbeda diperbolehkan
      final updatedSelf = await repository.update(item1.id!, 'Gula Pasir');
      expect(updatedSelf.name, 'Gula Pasir');
    });

    test('Aktivasi ditolak jika nama sudah digunakan oleh bahan aktif lain',
        () async {
      final item1 = await repository.create('Susu');
      await repository.deactivate(item1.id!);

      // Buat bahan aktif baru bernama Susu
      await repository.create('Susu');

      // Coba aktifkan kembali item1 yang nonaktif
      expect(
        () => repository.activate(item1.id!),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'Bahan aktif dengan nama tersebut sudah ada.',
          ),
        ),
      );
    });
  });
}

