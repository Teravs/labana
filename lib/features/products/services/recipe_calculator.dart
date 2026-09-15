import '../../../core/utils/unit_converter.dart';
import '../../ingredients/models/ingredient_price.dart';
import '../../processed_ingredients/models/processed_component.dart';
import '../../processed_ingredients/models/processed_ingredient.dart';
import '../../processed_ingredients/services/processed_ingredient_calculator.dart';
import '../models/recipe_item.dart';

/// Hasil perhitungan biaya untuk satu item komponen resep produk.
class RecipeItemCostResult {
  final RecipeItem item;
  final double calculatedCost;
  final bool isResolvable;
  final String? errorMessage;
  final String? itemName;
  final IngredientPrice? resolvedPrice;

  const RecipeItemCostResult({
    required this.item,
    required this.calculatedCost,
    required this.isResolvable,
    this.errorMessage,
    this.itemName,
    this.resolvedPrice,
  });

  RecipeItemCostResult copyWith({
    RecipeItem? item,
    double? calculatedCost,
    bool? isResolvable,
    String? errorMessage,
    String? itemName,
    IngredientPrice? resolvedPrice,
  }) {
    return RecipeItemCostResult(
      item: item ?? this.item,
      calculatedCost: calculatedCost ?? this.calculatedCost,
      isResolvable: isResolvable ?? this.isResolvable,
      errorMessage: errorMessage ?? this.errorMessage,
      itemName: itemName ?? this.itemName,
      resolvedPrice: resolvedPrice ?? this.resolvedPrice,
    );
  }
}

/// Hasil kalkulasi total HPP resep produk beserta rinciannya.
class RecipeCalculationResult {
  final List<RecipeItemCostResult> itemResults;
  final double totalCost;
  final int hppTotal;
  final bool hasUnresolvedCost;
  final List<String> warnings;

  const RecipeCalculationResult({
    required this.itemResults,
    required this.totalCost,
    required this.hppTotal,
    required this.hasUnresolvedCost,
    required this.warnings,
  });
}

/// Service khusus untuk menghitung HPP resep produk secara deterministik
/// berdasarkan tanggal efektif resep.
///
/// Service ini hanya melakukan komputasi murni tanpa mutasi database.
class RecipeCalculator {
  const RecipeCalculator();

  /// Menghitung total HPP resep dan biaya tiap item secara deterministik.
  ///
  /// [items]: Daftar item resep produk.
  /// [calculationDate]: Tanggal efektif resep dalam format `YYYY-MM-DD`.
  /// [ingredientPricesMap]: Peta harga bahan mentah (`ingredientId -> List<IngredientPrice>`).
  /// [allProcessedIngredients]: Peta bahan olahan (`processedId -> ProcessedIngredient`).
  /// [allProcessedComponents]: Peta komponen bahan olahan (`processedId -> List<ProcessedComponent>`).
  static RecipeCalculationResult calculateRecipeCost({
    required List<RecipeItem> items,
    required String calculationDate,
    Map<int, List<IngredientPrice>>? ingredientPricesMap,
    Map<int, ProcessedIngredient>? allProcessedIngredients,
    Map<int, List<ProcessedComponent>>? allProcessedComponents,
  }) {
    if (items.isEmpty) {
      return const RecipeCalculationResult(
        itemResults: [],
        totalCost: 0.0,
        hppTotal: 0,
        hasUnresolvedCost: false,
        warnings: [],
      );
    }

    final itemResults = <RecipeItemCostResult>[];
    var totalCost = 0.0;
    var hasUnresolved = false;
    final warnings = <String>[];

    for (final item in items) {
      final result = calculateItemCost(
        item: item,
        calculationDate: calculationDate,
        ingredientPricesMap: ingredientPricesMap,
        allProcessedIngredients: allProcessedIngredients,
        allProcessedComponents: allProcessedComponents,
      );

      itemResults.add(result);
      totalCost += result.calculatedCost;

      if (!result.isResolvable) {
        hasUnresolved = true;
        if (result.errorMessage != null &&
            !warnings.contains(result.errorMessage)) {
          warnings.add(result.errorMessage!);
        }
      }
    }

    // Pembulatan ke Rupiah integer pada hasil akhir (mencegah error akumulasi)
    final hppTotal = totalCost.round();

    return RecipeCalculationResult(
      itemResults: itemResults,
      totalCost: totalCost,
      hppTotal: hppTotal,
      hasUnresolvedCost: hasUnresolved,
      warnings: warnings,
    );
  }

  /// Menghitung biaya untuk satu [RecipeItem].
  static RecipeItemCostResult calculateItemCost({
    required RecipeItem item,
    required String calculationDate,
    Map<int, List<IngredientPrice>>? ingredientPricesMap,
    Map<int, ProcessedIngredient>? allProcessedIngredients,
    Map<int, List<ProcessedComponent>>? allProcessedComponents,
  }) {
    // 1. Biaya Lainnya (typeOther)
    if (item.componentType == RecipeItem.typeOther) {
      final cost = (item.otherCost ?? 0).toDouble();
      return RecipeItemCostResult(
        item: item,
        calculatedCost: cost,
        isResolvable: true,
        itemName: item.label ?? 'Biaya Lainnya',
      );
    }

    // 2. Bahan Mentah (typeIngredient)
    if (item.componentType == RecipeItem.typeIngredient) {
      final name = item.ingredientName ?? 'Bahan Mentah';

      if (item.ingredientId == null ||
          item.quantity == null ||
          item.quantity! <= 0 ||
          item.unit == null) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Jumlah atau satuan bahan "$name" tidak valid.',
          itemName: name,
        );
      }

      final prices = ingredientPricesMap?[item.ingredientId] ?? [];
      if (prices.isEmpty) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Belum ada data harga untuk "$name".',
          itemName: name,
        );
      }

      String baseUnit;
      try {
        baseUnit = UnitConverter.getBaseUnit(item.unit!);
      } catch (e) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Satuan "${item.unit}" tidak dikenali.',
          itemName: name,
        );
      }

      final resolvedPrice =
          ProcessedIngredientCalculator.resolvePriceForComponent(
            availablePrices: prices,
            componentUnit: baseUnit,
            calculationDate: calculationDate,
          );

      if (resolvedPrice == null) {
        final hasAnyEffective = prices.any(
          (p) => p.effectiveFrom.compareTo(calculationDate) <= 0,
        );
        final error = hasAnyEffective
            ? 'Satuan "${item.unit}" tidak cocok dengan format harga "$name".'
            : 'Belum ada harga aktif untuk "$name" per tanggal $calculationDate.';

        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: error,
          itemName: name,
        );
      }

      try {
        final conversion = UnitConverter.convert(
          purchaseQuantity: item.quantity!,
          purchaseUnit: item.unit!,
        );

        final cost = conversion.baseQuantity * resolvedPrice.costPerBaseUnit;

        return RecipeItemCostResult(
          item: item,
          calculatedCost: cost,
          resolvedPrice: resolvedPrice,
          isResolvable: true,
          itemName: name,
        );
      } on UnitConversionException catch (e) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          resolvedPrice: resolvedPrice,
          isResolvable: false,
          errorMessage: e.message,
          itemName: name,
        );
      }
    }

    // 3. Bahan Olahan (typeProcessed)
    if (item.componentType == RecipeItem.typeProcessed) {
      final childName =
          item.processedIngredientName ??
          allProcessedIngredients?[item.processedIngredientId]?.name ??
          'Bahan Olahan';

      if (item.processedIngredientId == null ||
          item.quantity == null ||
          item.quantity! <= 0 ||
          item.unit == null) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage:
              'Jumlah atau satuan bahan olahan "$childName" tidak valid.',
          itemName: childName,
        );
      }

      final child = allProcessedIngredients?[item.processedIngredientId];
      if (child == null) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: 'Data bahan olahan "$childName" tidak ditemukan.',
          itemName: childName,
        );
      }

      final childComponents =
          allProcessedComponents?[item.processedIngredientId] ?? [];

      // Gunakan public API existing dari ProcessedIngredientCalculator
      final childCostResult =
          ProcessedIngredientCalculator.calculateProcessedIngredientCost(
            processedIngredient: child,
            components: childComponents,
            pricesByIngredientId: ingredientPricesMap ?? {},
            processedIngredientsById: allProcessedIngredients,
            processedComponentsById: allProcessedComponents,
            calculationDate: calculationDate,
          );

      if (!UnitConverter.isCompatible(child.resultUnit, item.unit!)) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage:
              'Satuan "${item.unit}" tidak cocok dengan satuan hasil olahan "$childName" (${child.resultUnit}).',
          itemName: childName,
        );
      }

      try {
        final childConversion = UnitConverter.convert(
          purchaseQuantity: child.resultQuantity,
          purchaseUnit: child.resultUnit,
        );
        final childBaseQty = childConversion.baseQuantity;
        final childCostPerBaseUnit = childBaseQty > 0
            ? (childCostResult.totalCost / childBaseQty)
            : 0.0;

        final compConversion = UnitConverter.convert(
          purchaseQuantity: item.quantity!,
          purchaseUnit: item.unit!,
        );
        final compBaseQty = compConversion.baseQuantity;

        final cost = compBaseQty * childCostPerBaseUnit;

        return RecipeItemCostResult(
          item: item,
          calculatedCost: cost,
          isResolvable: !childCostResult.hasUnresolvedCost,
          errorMessage: childCostResult.hasUnresolvedCost
              ? 'Sebagian biaya bahan olahan "$childName" belum lengkap.'
              : null,
          itemName: childName,
        );
      } on UnitConversionException catch (e) {
        return RecipeItemCostResult(
          item: item,
          calculatedCost: 0.0,
          isResolvable: false,
          errorMessage: e.message,
          itemName: childName,
        );
      }
    }

    return RecipeItemCostResult(
      item: item,
      calculatedCost: 0.0,
      isResolvable: false,
      errorMessage: 'Tipe komponen tidak dikenali.',
    );
  }

  /// Menghitung estimasi laba: `harga_jual - HPP`.
  static int calculateProfit({
    required int sellingPrice,
    required int hppTotal,
  }) {
    return sellingPrice - hppTotal;
  }

  /// Menghitung persentase margin laba: `((harga_jual - HPP) / harga_jual) * 100`.
  /// Mengembalikan 0.0 jika harga jual <= 0.
  static double calculateProfitMargin({
    required int sellingPrice,
    required int hppTotal,
  }) {
    if (sellingPrice <= 0) return 0.0;
    return ((sellingPrice - hppTotal) / sellingPrice) * 100;
  }

  /// Memeriksa apakah harga jual berada di bawah HPP.
  static bool isSellingBelowHpp({
    required int sellingPrice,
    required int hppTotal,
  }) {
    return sellingPrice < hppTotal;
  }
}
