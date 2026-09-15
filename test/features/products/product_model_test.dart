import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/products/models/product.dart';
import 'package:labana/features/products/models/product_price.dart';
import 'package:labana/features/products/models/recipe_item.dart';
import 'package:labana/features/products/models/recipe_version.dart';

void main() {
  group('Product Model Tests', () {
    test('fromMap & toMap bekerja dengan benar', () {
      final product = Product(
        id: 1,
        name: 'Es Teh Manis',
        status: 'active',
        createdAt: '2026-09-01T08:00:00Z',
        updatedAt: '2026-09-01T08:00:00Z',
      );

      final map = product.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Es Teh Manis');
      expect(map['status'], 'active');
      expect(map['created_at'], '2026-09-01T08:00:00Z');
      expect(map['updated_at'], '2026-09-01T08:00:00Z');

      final fromMap = Product.fromMap(map);
      expect(fromMap.id, 1);
      expect(fromMap.name, 'Es Teh Manis');
      expect(fromMap.isActive, true);
      expect(fromMap.isInactive, false);
    });

    test('copyWith memperbarui nilai spesifik', () {
      final product = Product(
        id: 1,
        name: 'Es Teh',
        status: 'active',
        createdAt: '2026-09-01T08:00:00Z',
        updatedAt: '2026-09-01T08:00:00Z',
      );

      final updated = product.copyWith(
        name: 'Es Teh Manis Jumbo',
        status: 'inactive',
      );
      expect(updated.id, 1);
      expect(updated.name, 'Es Teh Manis Jumbo');
      expect(updated.status, 'inactive');
      expect(updated.isActive, false);
      expect(updated.isInactive, true);
    });
  });

  group('ProductPrice Model Tests', () {
    test(
      'fromMap & toMap bekerja dengan benar dan harga jual bertipe int Rupiah',
      () {
        final price = ProductPrice(
          id: 10,
          productId: 1,
          sellingPrice: 5000,
          effectiveFrom: '2026-09-01',
          createdAt: '2026-09-01T08:00:00Z',
        );

        final map = price.toMap();
        expect(map['id'], 10);
        expect(map['product_id'], 1);
        expect(map['selling_price'], 5000);
        expect(map['selling_price'] is int, true);
        expect(map['effective_from'], '2026-09-01');

        final fromMap = ProductPrice.fromMap(map);
        expect(fromMap.formattedSellingPrice, 'Rp5.000');
      },
    );
  });

  group('RecipeVersion Model Tests', () {
    test('fromMap & toMap bekerja dengan benar', () {
      final version = RecipeVersion(
        id: 5,
        productId: 1,
        versionNumber: 2,
        effectiveFrom: '2026-09-15',
        hppTotal: 2150,
        status: 'active',
        createdAt: '2026-09-15T08:00:00Z',
      );

      final map = version.toMap();
      expect(map['id'], 5);
      expect(map['product_id'], 1);
      expect(map['version_number'], 2);
      expect(map['effective_from'], '2026-09-15');
      expect(map['hpp_total'], 2150);
      expect(map['status'], 'active');

      final fromMap = RecipeVersion.fromMap(map);
      expect(fromMap.isActive, true);
      expect(fromMap.isDraft, false);
      expect(fromMap.isArchived, false);
      expect(fromMap.versionLabel, 'Resep v2');
      expect(fromMap.formattedHppTotal, 'Rp2.150');
    });
  });

  group('RecipeItem Model Tests', () {
    test(
      'Komponen ingredient: fromMap & toMap tidak menyimpan field transient',
      () {
        final item = RecipeItem(
          id: 1,
          recipeVersionId: 5,
          componentType: RecipeItem.typeIngredient,
          ingredientId: 2,
          quantity: 50,
          unit: 'g',
          createdAt: '2026-09-15T08:00:00Z',
          ingredientName: 'Gula Pasir', // UI transient join
        );

        final map = item.toMap();
        expect(map.containsKey('ingredient_name'), false);
        expect(map.containsKey('label'), false);
        expect(map['ingredient_id'], 2);
        expect(map['quantity'], 50.0);
        expect(map['unit'], 'g');
        expect(map['other_cost'], null);

        expect(item.isIngredient, true);
        expect(item.isProcessed, false);
        expect(item.isOther, false);
        expect(item.formattedQuantity, '50 g');
        expect(item.displayName, 'Gula Pasir');
      },
    );

    test('Komponen processed: fromMap & toMap', () {
      final item = RecipeItem(
        id: 2,
        recipeVersionId: 5,
        componentType: RecipeItem.typeProcessed,
        processedIngredientId: 3,
        quantity: 30,
        unit: 'ml',
        createdAt: '2026-09-15T08:00:00Z',
        processedIngredientName: 'Simple Syrup',
      );

      final map = item.toMap();
      expect(map.containsKey('processed_ingredient_name'), false);
      expect(map['processed_ingredient_id'], 3);
      expect(map['quantity'], 30.0);
      expect(map['unit'], 'ml');

      expect(item.isProcessed, true);
      expect(item.displayName, 'Simple Syrup');
    });

    test('Komponen other: fromMap & toMap', () {
      final item = RecipeItem(
        id: 3,
        recipeVersionId: 5,
        componentType: RecipeItem.typeOther,
        otherCost: 500,
        createdAt: '2026-09-15T08:00:00Z',
      );

      final map = item.toMap();
      expect(map['other_cost'], 500);
      expect(map['ingredient_id'], null);
      expect(map['processed_ingredient_id'], null);
      expect(map['quantity'], null);
      expect(map['unit'], null);

      expect(item.isOther, true);
      expect(item.formattedOtherCost, 'Rp500');
      expect(item.displayName, 'Biaya Lainnya');
    });
  });
}
