import 'package:sqflite/sqflite.dart';

import '../../../core/utils/unit_converter.dart';
import '../../ingredients/data/ingredient_price_repository.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../../ingredients/models/ingredient_price.dart';
import '../../processed_ingredients/data/processed_ingredient_repository.dart';
import '../../processed_ingredients/models/processed_component.dart';
import '../../processed_ingredients/models/processed_ingredient.dart';
import '../../processed_ingredients/services/processed_ingredient_calculator.dart';
import '../data/product_price_repository.dart';
import '../data/product_repository.dart';
import '../data/recipe_item_repository.dart';
import '../data/recipe_version_repository.dart';
import '../errors/hpp_exceptions.dart';
import '../models/hpp_calculation_result.dart';
import '../models/recipe_item.dart';

/// Engine kalkulasi HPP dan Laba produk yang deterministik berbasis tanggal historis.
///
/// Seluruh kalkulasi berorientasi pada `calculationDate` eksplisit:
/// - Memilih versi resep efektif (`effective_from <= calculationDate`).
/// - Memilih harga jual efektif (`effective_from <= calculationDate`).
/// - Memilih harga bahan mentah efektif (`effective_from <= calculationDate`).
/// - Meneruskan tanggal yang sama ke bahan olahan nested secara rekursif.
/// - Menghitung pembulatan integer Rupiah secara konsisten pada hasil akhir.
class HppEngine {
  final ProductRepository _productRepo;
  final RecipeVersionRepository _recipeVersionRepo;
  final RecipeItemRepository _recipeItemRepo;
  final ProductPriceRepository _priceRepo;
  final IngredientPriceRepository _ingredientPriceRepo;
  final ProcessedIngredientRepository _processedRepo;
  final IngredientRepository _ingredientRepo;

  HppEngine({
    ProductRepository? productRepo,
    RecipeVersionRepository? recipeVersionRepo,
    RecipeItemRepository? recipeItemRepo,
    ProductPriceRepository? priceRepo,
    IngredientPriceRepository? ingredientPriceRepo,
    ProcessedIngredientRepository? processedRepo,
    IngredientRepository? ingredientRepo,
  }) : _productRepo = productRepo ?? ProductRepository(),
       _recipeVersionRepo = recipeVersionRepo ?? RecipeVersionRepository(),
       _recipeItemRepo = recipeItemRepo ?? RecipeItemRepository(),
       _priceRepo = priceRepo ?? ProductPriceRepository(),
       _ingredientPriceRepo =
           ingredientPriceRepo ?? IngredientPriceRepository(),
       _processedRepo = processedRepo ?? ProcessedIngredientRepository(),
       _ingredientRepo = ingredientRepo ?? IngredientRepository();

  /// Menghitung HPP, harga jual, dan estimasi laba untuk produk berdasarkan [calculationDate].
  ///
  /// [productId]: ID produk yang akan dihitung.
  /// [calculationDate]: Tanggal acuan kalkulasi dalam format `YYYY-MM-DD`.
  /// [strict]: Jika `true`, melempar [MissingIngredientPriceException] bila ada bahan yang tidak memiliki harga efektif.
  ///           Jika `false`, mengembalikan hasil kalkulasi dengan `isResolvable = false` dan `hasUnresolvedCost = true`.
  Future<HppCalculationResult> calculateProductHpp({
    required int productId,
    required String calculationDate,
    DatabaseExecutor? executor,
    bool strict = false,
  }) async {
    // 1. Ambil produk
    final product = await _productRepo.getById(productId, executor: executor);
    if (product == null) {
      throw ProductNotFoundException(
        'Produk dengan ID $productId tidak ditemukan.',
        productId: productId,
      );
    }

    // 2. Ambil versi resep yang efektif pada calculationDate
    final recipeVersion = await _recipeVersionRepo.getEffectiveVersion(
      productId,
      calculationDate: calculationDate,
      executor: executor,
    );
    if (recipeVersion == null) {
      throw NoEffectiveRecipeException(
        'Tidak ada versi resep yang berlaku untuk produk "${product.name}" per tanggal $calculationDate.',
        productId: productId,
        calculationDate: calculationDate,
      );
    }

    // 3. Ambil item komponen resep untuk versi tersebut
    final recipeItems = await _recipeItemRepo.getByRecipeVersionId(
      recipeVersion.id!,
      executor: executor,
    );

    // 4. Ambil harga jual efektif pada calculationDate
    final effectivePrice = await _priceRepo.getEffectivePriceAt(
      productId,
      calculationDate: calculationDate,
      executor: executor,
    );

    // 5. Kumpulkan semua harga bahan mentah dan data bahan olahan yang dibutuhkan
    final neededIngredientIds = <int>{};
    final neededProcessedIds = <int>{};

    for (final item in recipeItems) {
      if (item.isIngredient && item.ingredientId != null) {
        neededIngredientIds.add(item.ingredientId!);
      } else if (item.isProcessed && item.processedIngredientId != null) {
        neededProcessedIds.add(item.processedIngredientId!);
      }
    }

    // Ambil data bahan mentah dan harga
    final ingredientPricesMap = <int, List<IngredientPrice>>{};
    final ingredientNamesMap = <int, String>{};

    for (final ingId in neededIngredientIds) {
      final prices = await _ingredientPriceRepo.getPrices(ingId);
      ingredientPricesMap[ingId] = prices;
      final ing = await _ingredientRepo.getById(ingId);
      if (ing != null) {
        ingredientNamesMap[ingId] = ing.name;
      }
    }

    // Ambil data bahan olahan beserta dependensinya secara lengkap
    final processedMap = <int, ProcessedIngredient>{};
    final processedComponentsMap = <int, List<ProcessedComponent>>{};

    if (neededProcessedIds.isNotEmpty) {
      // Ambil seluruh bahan olahan aktif/tersedia untuk mendukung nested hierarchy
      final allProcessed = await _processedRepo.getAll();
      for (final pi in allProcessed) {
        if (pi.id != null) {
          processedMap[pi.id!] = pi;
          final comps = await _processedRepo.getComponents(pi.id!);
          processedComponentsMap[pi.id!] = comps;

          // Periksa apakah bahan olahan anak membutuhkan harga bahan mentah tambahan
          for (final c in comps) {
            if (c.ingredientId != null &&
                !ingredientPricesMap.containsKey(c.ingredientId!)) {
              final prices = await _ingredientPriceRepo.getPrices(
                c.ingredientId!,
              );
              ingredientPricesMap[c.ingredientId!] = prices;
              final ing = await _ingredientRepo.getById(c.ingredientId!);
              if (ing != null) {
                ingredientNamesMap[c.ingredientId!] = ing.name;
              }
            }
          }
        }
      }
    }

    // 6. Jalankan kalkulasi HPP item demi item
    return calculateFromData(
      productId: productId,
      productName: product.name,
      calculationDate: calculationDate,
      recipeVersionId: recipeVersion.id!,
      recipeVersionNumber: recipeVersion.versionNumber,
      recipeItems: recipeItems,
      sellingPrice: effectivePrice?.sellingPrice,
      ingredientPricesMap: ingredientPricesMap,
      ingredientNamesMap: ingredientNamesMap,
      processedMap: processedMap,
      processedComponentsMap: processedComponentsMap,
      strict: strict,
    );
  }

  /// Menghitung HPP secara deterministik dari kumpulan data yang sudah dimuat dalam memori.
  ///
  /// Menjamin isolasi penuh dari database/disk sehingga aman digunakan untuk
  /// simulasi cepat, in-memory preview, dan unit testing.
  static HppCalculationResult calculateFromData({
    required int productId,
    required String productName,
    required String calculationDate,
    required int recipeVersionId,
    required int recipeVersionNumber,
    required List<RecipeItem> recipeItems,
    int? sellingPrice,
    required Map<int, List<IngredientPrice>> ingredientPricesMap,
    Map<int, String>? ingredientNamesMap,
    Map<int, ProcessedIngredient>? processedMap,
    Map<int, List<ProcessedComponent>>? processedComponentsMap,
    bool strict = false,
  }) {
    final items = <HppCalculationItem>[];
    double preciseHppTotal = 0.0;
    bool hasUnresolvedCost = false;
    final warnings = <String>[];

    for (final item in recipeItems) {
      // 1. Biaya Lainnya (other)
      if (item.componentType == RecipeItem.typeOther) {
        final cost = (item.otherCost ?? 0).toDouble();
        final label = item.label ?? 'Biaya Lainnya';
        preciseHppTotal += cost;
        items.add(
          HppCalculationItem(
            componentType: RecipeItem.typeOther,
            label: label,
            unitCost: cost,
            totalCost: cost,
            roundedCost: cost.round(),
            isResolvable: true,
          ),
        );
        continue;
      }

      // 2. Bahan Mentah (ingredient)
      if (item.componentType == RecipeItem.typeIngredient) {
        final name =
            item.ingredientName ??
            ingredientNamesMap?[item.ingredientId] ??
            'Bahan Mentah';

        if (item.ingredientId == null ||
            item.quantity == null ||
            item.quantity! <= 0 ||
            item.unit == null) {
          hasUnresolvedCost = true;
          final errorMsg =
              'Jumlah atau satuan bahan mentah "$name" tidak valid.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.ingredientId,
              ingredientName: name,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        final prices = ingredientPricesMap[item.ingredientId!] ?? [];
        if (prices.isEmpty) {
          hasUnresolvedCost = true;
          final errorMsg =
              'Belum ada data harga untuk bahan mentah "$name" per tanggal $calculationDate.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.ingredientId,
              ingredientName: name,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        String baseUnit;
        try {
          baseUnit = UnitConverter.getBaseUnit(item.unit!);
        } catch (e) {
          hasUnresolvedCost = true;
          final errorMsg = 'Satuan "${item.unit}" tidak dikenali.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.ingredientId,
              ingredientName: name,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        // Resolusi harga bahan mentah menggunakan aturan konsisten Tahap 5
        final resolvedPrice =
            ProcessedIngredientCalculator.resolvePriceForComponent(
              availablePrices: prices,
              componentUnit: baseUnit,
              calculationDate: calculationDate,
            );

        if (resolvedPrice == null) {
          hasUnresolvedCost = true;
          final hasAnyEffective = prices.any(
            (p) => p.effectiveFrom.compareTo(calculationDate) <= 0,
          );
          final errorMsg = hasAnyEffective
              ? 'Satuan "${item.unit}" tidak cocok dengan format harga "$name".'
              : 'Belum ada harga aktif untuk "$name" per tanggal $calculationDate.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.ingredientId,
              ingredientName: name,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        try {
          final conversion = UnitConverter.convert(
            purchaseQuantity: item.quantity!,
            purchaseUnit: item.unit!,
          );
          final cost = conversion.baseQuantity * resolvedPrice.costPerBaseUnit;
          preciseHppTotal += cost;

          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: resolvedPrice.costPerBaseUnit,
              totalCost: cost,
              roundedCost: cost.round(),
              isResolvable: true,
              effectivePriceId: resolvedPrice.id,
              effectivePriceDate: resolvedPrice.effectiveFrom,
            ),
          );
        } on UnitConversionException catch (e) {
          hasUnresolvedCost = true;
          warnings.add(e.message);
          if (strict) {
            throw MissingIngredientPriceException(
              e.message,
              ingredientId: item.ingredientId,
              ingredientName: name,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeIngredient,
              componentId: item.ingredientId,
              label: name,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: resolvedPrice.costPerBaseUnit,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: e.message,
            ),
          );
        }
        continue;
      }

      // 3. Bahan Olahan (processed)
      if (item.componentType == RecipeItem.typeProcessed) {
        final childName =
            item.processedIngredientName ??
            processedMap?[item.processedIngredientId]?.name ??
            'Bahan Olahan';

        if (item.processedIngredientId == null ||
            item.quantity == null ||
            item.quantity! <= 0 ||
            item.unit == null) {
          hasUnresolvedCost = true;
          final errorMsg =
              'Jumlah atau satuan bahan olahan "$childName" tidak valid.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.processedIngredientId,
              ingredientName: childName,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeProcessed,
              componentId: item.processedIngredientId,
              label: childName,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        final child = processedMap?[item.processedIngredientId];
        if (child == null) {
          hasUnresolvedCost = true;
          final errorMsg = 'Data bahan olahan "$childName" tidak ditemukan.';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.processedIngredientId,
              ingredientName: childName,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeProcessed,
              componentId: item.processedIngredientId,
              label: childName,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
        }

        final childComponents =
            processedComponentsMap?[item.processedIngredientId] ?? [];

        // Delegasikan perhitungan rekursif ke ProcessedIngredientCalculator Tahap 7
        final childCostResult =
            ProcessedIngredientCalculator.calculateProcessedIngredientCost(
              processedIngredient: child,
              components: childComponents,
              pricesByIngredientId: ingredientPricesMap,
              ingredientNamesById: ingredientNamesMap,
              processedIngredientsById: processedMap,
              processedComponentsById: processedComponentsMap,
              calculationDate: calculationDate,
            );

        if (!UnitConverter.isCompatible(child.resultUnit, item.unit!)) {
          hasUnresolvedCost = true;
          final errorMsg =
              'Satuan "${item.unit}" tidak cocok dengan satuan hasil olahan "$childName" (${child.resultUnit}).';
          warnings.add(errorMsg);
          if (strict) {
            throw MissingIngredientPriceException(
              errorMsg,
              ingredientId: item.processedIngredientId,
              ingredientName: childName,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeProcessed,
              componentId: item.processedIngredientId,
              label: childName,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: errorMsg,
            ),
          );
          continue;
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

          if (childCostResult.hasUnresolvedCost) {
            hasUnresolvedCost = true;
            final errorMsg =
                'Sebagian biaya bahan olahan "$childName" belum lengkap per tanggal $calculationDate.';
            warnings.add(errorMsg);
            if (strict) {
              throw MissingIngredientPriceException(
                errorMsg,
                ingredientId: item.processedIngredientId,
                ingredientName: childName,
                calculationDate: calculationDate,
              );
            }
          }

          preciseHppTotal += cost;

          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeProcessed,
              componentId: item.processedIngredientId,
              label: childName,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: childCostPerBaseUnit,
              totalCost: cost,
              roundedCost: cost.round(),
              isResolvable: !childCostResult.hasUnresolvedCost,
              errorMessage: childCostResult.hasUnresolvedCost
                  ? 'Sebagian biaya olahan belum lengkap.'
                  : null,
            ),
          );
        } on UnitConversionException catch (e) {
          hasUnresolvedCost = true;
          warnings.add(e.message);
          if (strict) {
            throw MissingIngredientPriceException(
              e.message,
              ingredientId: item.processedIngredientId,
              ingredientName: childName,
              calculationDate: calculationDate,
            );
          }
          items.add(
            HppCalculationItem(
              componentType: RecipeItem.typeProcessed,
              componentId: item.processedIngredientId,
              label: childName,
              quantity: item.quantity,
              unit: item.unit,
              unitCost: 0.0,
              totalCost: 0.0,
              roundedCost: 0,
              isResolvable: false,
              errorMessage: e.message,
            ),
          );
        }
        continue;
      }
    }

    // Kebijakan Pembulatan Rupiah:
    // Jumlahkan seluruh biaya dengan precision internal (double),
    // kemudian bulatkan hasil akhir ke integer Rupiah.
    final hppTotal = preciseHppTotal.round();

    // Kalkulasi Profit & Margin
    int? profit;
    double? marginPercentage;
    bool isBelowHpp = false;

    if (sellingPrice != null) {
      profit = sellingPrice - hppTotal;
      marginPercentage = sellingPrice > 0
          ? ((profit / sellingPrice) * 100)
          : 0.0;
      isBelowHpp = sellingPrice < hppTotal;
    }

    return HppCalculationResult(
      productId: productId,
      productName: productName,
      calculationDate: calculationDate,
      recipeVersionId: recipeVersionId,
      recipeVersionNumber: recipeVersionNumber,
      hppTotal: hppTotal,
      preciseHppTotal: preciseHppTotal,
      sellingPrice: sellingPrice,
      profit: profit,
      marginPercentage: marginPercentage,
      isBelowHpp: isBelowHpp,
      items: items,
      hasUnresolvedCost: hasUnresolvedCost,
      warnings: warnings,
    );
  }
}
