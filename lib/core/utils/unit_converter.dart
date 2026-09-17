/// Exception khusus untuk kesalahan dalam konversi satuan atau ketidaksesuaian kategori satuan.
class UnitConversionException implements Exception {
  final String message;
  const UnitConversionException(this.message);

  @override
  String toString() => message;
}

/// Hasil konversi dari kuantitas dan satuan pembelian ke satuan dasar.
class UnitConversionResult {
  final double baseQuantity;
  final String baseUnit;

  const UnitConversionResult({
    required this.baseQuantity,
    required this.baseUnit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitConversionResult &&
          runtimeType == other.runtimeType &&
          baseQuantity == other.baseQuantity &&
          baseUnit == other.baseUnit;

  @override
  int get hashCode => Object.hash(baseQuantity, baseUnit);

  @override
  String toString() =>
      'UnitConversionResult(baseQuantity: $baseQuantity, baseUnit: $baseUnit)';
}

/// Service/Utility untuk menangani konversi satuan bahan baku ke satuan dasar sistem.
class UnitConverter {
  UnitConverter._();

  // Daftar satuan pembelian yang didukung
  static const String unitGram = 'g';
  static const String unitKilogram = 'kg';
  static const String unitMililiter = 'ml';
  static const String unitLiter = 'liter';
  static const String unitPcs = 'pcs';
  static const String unitPack = 'pack';

  // Daftar satuan dasar sistem
  static const String baseGram = 'g';
  static const String baseMililiter = 'ml';
  static const String basePcs = 'pcs';

  /// Pilihan satuan pembelian beserta label ramah pengguna untuk dropdown UI.
  static const List<MapEntry<String, String>> purchaseUnits = [
    MapEntry(unitGram, 'Gram (g)'),
    MapEntry(unitKilogram, 'Kilogram (kg)'),
    MapEntry(unitMililiter, 'Mililiter (ml)'),
    MapEntry(unitLiter, 'Liter'),
    MapEntry(unitPcs, 'Pcs'),
    MapEntry(unitPack, 'Pack'),
  ];

  /// Mendapatkan label ramah pengguna untuk suatu satuan pembelian.
  static String getUnitLabel(String unit) {
    switch (unit) {
      case unitGram:
        return 'Gram (g)';
      case unitKilogram:
        return 'Kilogram (kg)';
      case unitMililiter:
        return 'Mililiter (ml)';
      case unitLiter:
        return 'Liter';
      case unitPcs:
        return 'Pcs';
      case unitPack:
        return 'Pack';
      default:
        return unit;
    }
  }

  /// Mendapatkan satuan dasar yang sesuai untuk satuan pembelian yang diberikan.
  static String getBaseUnit(String purchaseUnit) {
    switch (purchaseUnit) {
      case unitGram:
      case unitKilogram:
        return baseGram;
      case unitMililiter:
      case unitLiter:
        return baseMililiter;
      case unitPcs:
      case unitPack:
        return basePcs;
      default:
        throw UnitConversionException(
          'Satuan pembelian "$purchaseUnit" tidak dikenali.',
        );
    }
  }

  /// Melakukan validasi apakah dua satuan kompatibel (berada dalam kelompok yang sama: massa, volume, atau unit).
  static bool isCompatible(String unitA, String unitB) {
    try {
      final baseA = getBaseUnit(unitA);
      final baseB = getBaseUnit(unitB);
      return baseA == baseB;
    } catch (_) {
      return false;
    }
  }

  /// Melakukan konversi kuantitas dan satuan pembelian menjadi satuan dasar sistem.
  ///
  /// Aturan:
  /// - `kg` -> `purchaseQuantity * 1000 g`
  /// - `g` -> `purchaseQuantity g`
  /// - `liter` -> `purchaseQuantity * 1000 ml`
  /// - `ml` -> `purchaseQuantity ml`
  /// - `pcs` -> `purchaseQuantity pcs`
  /// - `pack` -> membutuhkan `packageQuantity > 0`, `purchaseQuantity * packageQuantity pcs`
  ///
  /// Melempar [UnitConversionException] jika data tidak valid atau unit tidak kompatibel.
  static UnitConversionResult convert({
    required double purchaseQuantity,
    required String purchaseUnit,
    double? packageQuantity,
    String? targetBaseUnit,
  }) {
    if (purchaseQuantity <= 0) {
      throw const UnitConversionException(
        'Jumlah pembelian harus lebih besar dari 0.',
      );
    }

    final expectedBase = getBaseUnit(purchaseUnit);

    // Validasi kompatibilitas jika targetBaseUnit ditentukan
    if (targetBaseUnit != null && targetBaseUnit != expectedBase) {
      throw UnitConversionException(
        'Satuan "$purchaseUnit" tidak kompatibel dengan satuan dasar "$targetBaseUnit".',
      );
    }

    double calculatedBaseQuantity;

    switch (purchaseUnit) {
      case unitKilogram:
        calculatedBaseQuantity = purchaseQuantity * 1000.0;
        break;
      case unitGram:
        calculatedBaseQuantity = purchaseQuantity;
        break;
      case unitLiter:
        calculatedBaseQuantity = purchaseQuantity * 1000.0;
        break;
      case unitMililiter:
        calculatedBaseQuantity = purchaseQuantity;
        break;
      case unitPcs:
        calculatedBaseQuantity = purchaseQuantity;
        break;
      case unitPack:
        if (packageQuantity == null || packageQuantity <= 0) {
          throw const UnitConversionException(
            'Isi per pack harus diisi dan lebih besar dari 0 untuk satuan Pack.',
          );
        }
        calculatedBaseQuantity = purchaseQuantity * packageQuantity;
        break;
      default:
        throw UnitConversionException(
          'Satuan pembelian "$purchaseUnit" tidak didukung.',
        );
    }

    return UnitConversionResult(
      baseQuantity: calculatedBaseQuantity,
      baseUnit: expectedBase,
    );
  }
}
