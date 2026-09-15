import '../../../core/utils/unit_converter.dart';
import '../../ingredients/models/ingredient_price.dart';
import '../models/processed_component.dart';
import '../models/processed_ingredient.dart';

/// Hasil perhitungan biaya untuk satu komponen bahan olahan.
class ComponentCostResult {
  final ProcessedComponent component;
  final double calculatedCost;
  final IngredientPrice? resolvedPrice;
  final bool isResolvable;
  final String? errorMessage;
  final String? ingredientName;

  const ComponentCostResult({
    required this.component,
    required this.calculatedCost,
    this.resolvedPrice,
    required this.isResolvable,
    this.errorMessage,
    this.ingredientName,
  });

  ComponentCostResult copyWith({
    ProcessedComponent? component,
    double? calculatedCost,
    IngredientPrice? resolvedPrice,
    bool? isResolvable,
    String? errorMessage,
    String? ingredientName,
  }) {
    return ComponentCostResult(
      component: component ?? this.component,
      calculatedCost: calculatedCost ?? this.calculatedCost,
      resolvedPrice: resolvedPrice ?? this.resolvedPrice,
      isResolvable: isResolvable ?? this.isResolvable,
      errorMessage: errorMessage ?? this.errorMessage,
      ingredientName: ingredientName ?? this.ingredientName,
    );
  }
}

/// Hasil kalkulasi total biaya dan HPP per satuan hasil bahan olahan.
class ProcessedIngredientCostResult {
  final ProcessedIngredient processedIngredient;
  final List<ComponentCostResult> componentResults;
  final double totalCost;
  final double costPerResultUnit;
  final bool hasUnresolvedCost;
  final List<String> warnings;

  const ProcessedIngredientCostResult({
    required this.processedIngredient,
    required this.componentResults,
    required this.totalCost,
    required this.costPerResultUnit,
    required this.hasUnresolvedCost,
    required this.warnings,
  });
}

/// Service untuk menghitung biaya komponen dan total modal bahan olahan.
class ProcessedIngredientCalculator {
  const ProcessedIngredientCalculator();

  /// Menentukan format harga bahan mentah yang valid secara deterministik.
  ///
  /// Mencegah ambiguitas jika bahan memiliki beberapa format harga aktif:
  /// 1. Memfilter harga dengan `effectiveFrom <= calculationDate`.
  /// 2. Memfilter harga yang satuannya kompatibel dengan [componentUnit].
  /// 3. Untuk format yang sama, mengambil record terbaru (`effectiveFrom DESC, id DESC`).
  /// 4. Memilih format default (`isDefault == true`) jika kompatibel.
  /// 5. Jika tidak ada default, memilih format yang sama persis satuannya (`purchaseUnit == componentUnit`).
  /// 6. Jika masih ada alternatif, memilih format terbaru (`effectiveFrom DESC, id DESC`).
  static IngredientPrice? resolvePriceForComponent({
    required List<IngredientPrice> availablePrices,
    required String componentUnit,
    required String calculationDate,
  }) {
    // 1. Filter tanggal efektif
    final effectivePrices = availablePrices.where((p) {
      return p.effectiveFrom.compareTo(calculationDate) <= 0;
    }).toList();

    if (effectivePrices.isEmpty) return null;

    // 2. Filter kompatibilitas satuan
    final compatiblePrices = effectivePrices.where((p) {
      return UnitConverter.isCompatible(p.purchaseUnit, componentUnit);
    }).toList();

    if (compatiblePrices.isEmpty) return null;

    // 3. Ambil record paling baru untuk setiap format pembelian unik
    final latestByFormat = <String, IngredientPrice>{};
    for (final price in compatiblePrices) {
      final key =
          '${price.purchaseQuantity}_${price.purchaseUnit}_${price.packageQuantity ?? 0}';
      if (!latestByFormat.containsKey(key)) {
        latestByFormat[key] = price;
      } else {
        final existing = latestByFormat[key]!;
        if (price.effectiveFrom.compareTo(existing.effectiveFrom) > 0 ||
            (price.effectiveFrom == existing.effectiveFrom &&
                (price.id ?? 0) > (existing.id ?? 0))) {
          latestByFormat[key] = price;
        }
      }
    }

    final activeFormats = latestByFormat.values.toList();

    // 4. Prioritaskan format default
    final defaultFormat = activeFormats.where((p) => p.isDefault).firstOrNull;
    if (defaultFormat != null) {
      return defaultFormat;
    }

    // 5. Prioritaskan format yang satuannya persis sama dengan komponen
    final exactUnitFormat = activeFormats
        .where((p) => p.purchaseUnit == componentUnit)
        .firstOrNull;
    if (exactUnitFormat != null) {
      return exactUnitFormat;
    }

    // 6. Urutkan berdasarkan effectiveFrom terbaru, lalu id terbesar
    activeFormats.sort((a, b) {
      final dateComp = b.effectiveFrom.compareTo(a.effectiveFrom);
      if (dateComp != 0) return dateComp;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return activeFormats.first;
  }

  /// Menghitung biaya untuk satu komponen.
  static ComponentCostResult calculateComponentCost({
    required ProcessedComponent component,
    List<IngredientPrice>? ingredientPrices,
    String? ingredientName,
    required String calculationDate,
  }) {
    if (component.componentType == ProcessedComponent.typeOther) {
      final cost = (component.otherCost ?? 0).toDouble();
      return ComponentCostResult(
        component: component,
        calculatedCost: cost,
        isResolvable: true,
        ingredientName: ingredientName ?? 'Biaya Lainnya',
      );
    }

    if (component.componentType == ProcessedComponent.typeIngredient) {
      if (component.quantity == null ||
          component.quantity! <= 0 ||
          component.unit == null) {
        return ComponentCostResult(
          component: component,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Jumlah atau satuan bahan tidak valid.',
          ingredientName: ingredientName,
        );
      }

      if (ingredientPrices == null || ingredientPrices.isEmpty) {
        return ComponentCostResult(
          component: component,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Belum ada data harga untuk bahan ini.',
          ingredientName: ingredientName,
        );
      }

      final resolvedPrice = resolvePriceForComponent(
        availablePrices: ingredientPrices,
        componentUnit: component.unit!,
        calculationDate: calculationDate,
      );

      if (resolvedPrice == null) {
        final hasAnyEffective = ingredientPrices.any(
          (p) => p.effectiveFrom.compareTo(calculationDate) <= 0,
        );
        final error = hasAnyEffective
            ? 'Satuan "${component.unit}" tidak kompatibel dengan format harga yang ada.'
            : 'Belum ada harga aktif per tanggal $calculationDate.';

        return ComponentCostResult(
          component: component,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: error,
          ingredientName: ingredientName,
        );
      }

      // Konversi kuantitas komponen ke satuan dasar
      try {
        final conversion = UnitConverter.convert(
          purchaseQuantity: component.quantity!,
          purchaseUnit: component.unit!,
        );

        final cost = conversion.baseQuantity * resolvedPrice.costPerBaseUnit;

        return ComponentCostResult(
          component: component,
          calculatedCost: cost,
          resolvedPrice: resolvedPrice,
          isResolvable: true,
          ingredientName: ingredientName,
        );
      } on UnitConversionException catch (e) {
        return ComponentCostResult(
          component: component,
          calculatedCost: 0.0,
          resolvedPrice: resolvedPrice,
          isResolvable: false,
          errorMessage: e.message,
          ingredientName: ingredientName,
        );
      }
    }

    return ComponentCostResult(
      component: component,
      calculatedCost: 0.0,
      isResolvable: false,
      errorMessage: 'Tipe komponen tidak didukung pada tahap ini.',
      ingredientName: ingredientName,
    );
  }

  /// Menghitung total biaya dan biaya per satuan hasil untuk bahan olahan.
  static ProcessedIngredientCostResult calculateProcessedIngredientCost({
    required ProcessedIngredient processedIngredient,
    required List<ProcessedComponent> components,
    required Map<int, List<IngredientPrice>> pricesByIngredientId,
    Map<int, String>? ingredientNamesById,
    required String calculationDate,
  }) {
    final componentResults = <ComponentCostResult>[];
    double totalCost = 0.0;
    bool hasUnresolved = false;
    final warnings = <String>[];

    for (final component in components) {
      final ingPrices = component.ingredientId != null
          ? (pricesByIngredientId[component.ingredientId!] ?? [])
          : null;
      final ingName =
          (component.ingredientId != null && ingredientNamesById != null)
          ? ingredientNamesById[component.ingredientId!]
          : null;

      final res = calculateComponentCost(
        component: component,
        ingredientPrices: ingPrices,
        ingredientName: ingName,
        calculationDate: calculationDate,
      );

      componentResults.add(res);

      if (res.isResolvable) {
        totalCost += res.calculatedCost;
      } else {
        hasUnresolved = true;
        final name = res.ingredientName ?? 'Komponen';
        warnings.add('$name: ${res.errorMessage ?? "Gagal menghitung biaya"}');
      }
    }

    final resultQty = processedIngredient.resultQuantity;
    final costPerResultUnit = resultQty > 0 ? (totalCost / resultQty) : 0.0;

    return ProcessedIngredientCostResult(
      processedIngredient: processedIngredient,
      componentResults: componentResults,
      totalCost: totalCost,
      costPerResultUnit: costPerResultUnit,
      hasUnresolvedCost: hasUnresolved,
      warnings: warnings,
    );
  }
}
