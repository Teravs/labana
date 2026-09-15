import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/unit_converter.dart';
import '../models/ingredient_price.dart';
import 'ingredient_repository.dart';

/// Repository untuk mengelola data harga bahan mentah dan riwayat perubahannya (`ingredient_prices`).
class IngredientPriceRepository {
  final DatabaseHelper _dbHelper;

  IngredientPriceRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  /// Mengambil seluruh riwayat harga suatu bahan mentah,
  /// diurutkan dari tanggal berlaku terbaru (`effective_from DESC, id DESC`).
  Future<List<IngredientPrice>> getPrices(int ingredientId) async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredientPrices,
      where: 'ingredient_id = ?',
      whereArgs: [ingredientId],
      orderBy: 'effective_from DESC, id DESC',
    );

    return results.map((map) => IngredientPrice.fromMap(map)).toList();
  }

  /// Mengambil satu record harga berdasarkan [id].
  Future<IngredientPrice?> getPriceById(int id) async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredientPrices,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return IngredientPrice.fromMap(results.first);
  }

  /// Mengambil harga pembelian default (format utama) untuk suatu bahan.
  Future<IngredientPrice?> getDefaultPrice(int ingredientId) async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredientPrices,
      where: 'ingredient_id = ? AND is_default = 1',
      whereArgs: [ingredientId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return IngredientPrice.fromMap(results.first);
  }

  /// Mengambil seluruh harga default yang ada untuk semua bahan sekaligus.
  Future<Map<int, IngredientPrice>> getAllDefaultPrices() async {
    final db = await _db;
    final results = await db.query(
      TableNames.ingredientPrices,
      where: 'is_default = 1',
    );

    final map = <int, IngredientPrice>{};
    for (final row in results) {
      final price = IngredientPrice.fromMap(row);
      map[price.ingredientId] = price;
    }
    return map;
  }

  /// Mengambil harga yang aktif pada tanggal tertentu ([targetDate] format YYYY-MM-DD).
  ///
  /// Aturan:
  /// `effective_from <= targetDate`, diurutkan `effective_from DESC, id DESC LIMIT 1`.
  /// Jika format pembelian ditentukan ([purchaseUnit] & [purchaseQuantity]), query akan memfilter format tersebut.
  /// Mengembalikan `null` jika belum ada harga yang berlaku pada tanggal tersebut.
  Future<IngredientPrice?> getPriceForDate(
    int ingredientId, {
    String? purchaseUnit,
    double? purchaseQuantity,
    double? packageQuantity,
    required String targetDate,
  }) async {
    final db = await _db;

    String whereClause = 'ingredient_id = ? AND effective_from <= ?';
    final whereArgs = <dynamic>[ingredientId, targetDate];

    if (purchaseUnit != null && purchaseQuantity != null) {
      whereClause += ' AND purchase_unit = ? AND purchase_quantity = ?';
      whereArgs.addAll([purchaseUnit, purchaseQuantity]);

      if (packageQuantity != null) {
        whereClause += ' AND package_quantity = ?';
        whereArgs.add(packageQuantity);
      } else {
        whereClause += ' AND package_quantity IS NULL';
      }
    }

    final results = await db.query(
      TableNames.ingredientPrices,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'effective_from DESC, id DESC',
      limit: 1,
    );

    if (results.isEmpty) return null;
    return IngredientPrice.fromMap(results.first);
  }

  /// Menambahkan harga pembelian baru untuk bahan mentah.
  ///
  /// Menghitung kuantitas dan satuan dasar secara otomatis via [UnitConverter].
  /// Mencegah duplikasi tanggal berlaku untuk format pembelian yang sama.
  /// Menjamin atomisitas penetapan format default melalui transaksi SQLite.
  Future<IngredientPrice> createPrice({
    required int ingredientId,
    required double purchaseQuantity,
    required String purchaseUnit,
    double? packageQuantity,
    required int price,
    required String effectiveFrom,
    bool isDefault = false,
  }) async {
    // Validasi input
    if (purchaseQuantity <= 0) {
      throw const ValidationException('Jumlah pembelian harus lebih dari 0.');
    }
    if (price < 0) {
      throw const ValidationException('Harga tidak boleh negatif.');
    }
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(effectiveFrom)) {
      throw const ValidationException(
        'Format tanggal berlaku harus YYYY-MM-DD.',
      );
    }

    // Pastikan package_quantity bernilai null jika bukan pack
    final sanitizedPackageQuantity = purchaseUnit == UnitConverter.unitPack
        ? packageQuantity
        : null;

    // Lakukan konversi satuan otomatis
    UnitConversionResult conversion;
    try {
      conversion = UnitConverter.convert(
        purchaseQuantity: purchaseQuantity,
        purchaseUnit: purchaseUnit,
        packageQuantity: sanitizedPackageQuantity,
      );
    } on UnitConversionException catch (e) {
      throw ValidationException(e.message);
    }

    final db = await _db;

    // Cek duplikasi effective date untuk format pembelian yang sama
    String dupWhere =
        'ingredient_id = ? AND purchase_unit = ? AND purchase_quantity = ? AND effective_from = ?';
    final dupArgs = <dynamic>[
      ingredientId,
      purchaseUnit,
      purchaseQuantity,
      effectiveFrom,
    ];

    if (sanitizedPackageQuantity != null) {
      dupWhere += ' AND package_quantity = ?';
      dupArgs.add(sanitizedPackageQuantity);
    } else {
      dupWhere += ' AND package_quantity IS NULL';
    }

    final duplicates = await db.query(
      TableNames.ingredientPrices,
      where: dupWhere,
      whereArgs: dupArgs,
      limit: 1,
    );

    if (duplicates.isNotEmpty) {
      throw const ValidationException(
        'Sudah ada harga dengan format pembelian dan tanggal berlaku tersebut.',
      );
    }

    // Eksekusi transaksi SQLite
    return await _dbHelper.transaction<IngredientPrice>((txn) async {
      // Jika dijadikan default, set harga lain bahan ini menjadi is_default = 0
      if (isDefault) {
        await txn.update(
          TableNames.ingredientPrices,
          {'is_default': 0},
          where: 'ingredient_id = ?',
          whereArgs: [ingredientId],
        );
      }

      final insertMap = <String, dynamic>{
        'ingredient_id': ingredientId,
        'purchase_quantity': purchaseQuantity,
        'purchase_unit': purchaseUnit,
        'base_quantity': conversion.baseQuantity,
        'base_unit': conversion.baseUnit,
        'package_quantity': sanitizedPackageQuantity,
        'price': price,
        'is_default': isDefault ? 1 : 0,
        'effective_from': effectiveFrom,
      };

      final newId = await txn.insert(TableNames.ingredientPrices, insertMap);

      return IngredientPrice(
        id: newId,
        ingredientId: ingredientId,
        purchaseQuantity: purchaseQuantity,
        purchaseUnit: purchaseUnit,
        baseQuantity: conversion.baseQuantity,
        baseUnit: conversion.baseUnit,
        packageQuantity: sanitizedPackageQuantity,
        price: price,
        isDefault: isDefault,
        effectiveFrom: effectiveFrom,
      );
    });
  }

  /// Menjadikan suatu record harga sebagai format default untuk bahan terkait.
  /// Menjamin tepat satu record yang bertanda `is_default = 1` per bahan.
  Future<void> setDefaultPrice({
    required int ingredientId,
    required int priceId,
  }) async {
    await _dbHelper.transaction<void>((txn) async {
      // Reset semua harga bahan ini
      await txn.update(
        TableNames.ingredientPrices,
        {'is_default': 0},
        where: 'ingredient_id = ?',
        whereArgs: [ingredientId],
      );

      // Set record yang dipilih menjadi default
      final updatedRows = await txn.update(
        TableNames.ingredientPrices,
        {'is_default': 1},
        where: 'id = ? AND ingredient_id = ?',
        whereArgs: [priceId, ingredientId],
      );

      if (updatedRows == 0) {
        throw const ValidationException('Data harga tidak ditemukan.');
      }
    });
  }

  /// Menghapus record harga (hanya jika diperlukan untuk koreksi input).
  Future<void> deletePrice(int id) async {
    final db = await _db;
    await db.delete(
      TableNames.ingredientPrices,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
