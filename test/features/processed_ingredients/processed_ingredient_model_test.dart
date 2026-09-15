import 'package:flutter_test/flutter_test.dart';
import 'package:labana/features/processed_ingredients/models/processed_component.dart';
import 'package:labana/features/processed_ingredients/models/processed_ingredient.dart';

void main() {
  group('ProcessedIngredient Model Tests', () {
    test('fromMap & toMap bekerja dengan benar', () {
      final map = {
        'id': 1,
        'name': 'Larutan Gula',
        'result_quantity': 5000.0,
        'result_unit': 'ml',
        'status': 'active',
        'created_at': '2026-09-15 08:00:00',
        'updated_at': '2026-09-15 08:00:00',
      };

      final item = ProcessedIngredient.fromMap(map);
      expect(item.id, 1);
      expect(item.name, 'Larutan Gula');
      expect(item.resultQuantity, 5000.0);
      expect(item.resultUnit, 'ml');
      expect(item.isActive, isTrue);
      expect(item.isInactive, isFalse);
      expect(item.formattedResultQuantity, '5.000');
      expect(item.formattedResult, '5.000 ml');

      final toMapResult = item.toMap();
      expect(toMapResult['name'], 'Larutan Gula');
      expect(toMapResult['result_quantity'], 5000.0);
      expect(toMapResult['result_unit'], 'ml');
      expect(toMapResult['status'], 'active');
    });

    test('copyWith memperbarui nilai spesifik', () {
      const item = ProcessedIngredient(
        id: 1,
        name: 'Simple Syrup',
        resultQuantity: 1000.0,
        resultUnit: 'ml',
      );

      final updated = item.copyWith(name: 'Larutan Gula', status: 'inactive');

      expect(updated.id, 1);
      expect(updated.name, 'Larutan Gula');
      expect(updated.status, 'inactive');
      expect(updated.isActive, isFalse);
      expect(updated.isInactive, isTrue);
      expect(updated.resultQuantity, 1000.0);
    });
  });

  group('ProcessedComponent Model Tests', () {
    test('Komponen ingredient: fromMap & toMap', () {
      final map = {
        'id': 10,
        'processed_ingredient_id': 1,
        'component_type': 'ingredient',
        'ingredient_id': 5,
        'child_processed_id': null,
        'quantity': 1.0,
        'unit': 'kg',
        'other_cost': null,
      };

      final component = ProcessedComponent.fromMap(map);
      expect(component.isIngredient, isTrue);
      expect(component.isOther, isFalse);
      expect(component.ingredientId, 5);
      expect(component.quantity, 1.0);
      expect(component.unit, 'kg');
      expect(component.otherCost, isNull);
      expect(component.formattedQuantity, '1');

      final toMapResult = component.toMap();
      expect(toMapResult['component_type'], 'ingredient');
      expect(toMapResult['ingredient_id'], 5);
      expect(toMapResult['quantity'], 1.0);
      expect(toMapResult['unit'], 'kg');
      expect(toMapResult['other_cost'], isNull);
    });

    test('Komponen other: fromMap & toMap', () {
      final map = {
        'id': 11,
        'processed_ingredient_id': 1,
        'component_type': 'other',
        'ingredient_id': null,
        'child_processed_id': null,
        'quantity': null,
        'unit': null,
        'other_cost': 1000,
      };

      final component = ProcessedComponent.fromMap(map);
      expect(component.isIngredient, isFalse);
      expect(component.isOther, isTrue);
      expect(component.ingredientId, isNull);
      expect(component.otherCost, 1000);
      expect(component.formattedQuantity, isNull);

      final toMapResult = component.toMap();
      expect(toMapResult['component_type'], 'other');
      expect(toMapResult['other_cost'], 1000);
      expect(toMapResult['ingredient_id'], isNull);
    });

    test(
      'Komponen processed: fromMap & toMap (childProcessedName tidak dipersist)',
      () {
        final map = {
          'id': 12,
          'processed_ingredient_id': 2,
          'component_type': 'processed',
          'ingredient_id': null,
          'child_processed_id': 1,
          'quantity': 250.0,
          'unit': 'ml',
          'other_cost': null,
          'child_processed_name': 'Larutan Gula',
        };

        final component = ProcessedComponent.fromMap(map);
        expect(component.isIngredient, isFalse);
        expect(component.isOther, isFalse);
        expect(component.isProcessed, isTrue);
        expect(component.childProcessedId, 1);
        expect(component.childProcessedName, 'Larutan Gula');
        expect(component.quantity, 250.0);
        expect(component.unit, 'ml');

        final toMapResult = component.toMap();
        expect(toMapResult['component_type'], 'processed');
        expect(toMapResult['child_processed_id'], 1);
        expect(toMapResult['quantity'], 250.0);
        expect(toMapResult['unit'], 'ml');
        expect(toMapResult.containsKey('child_processed_name'), isFalse);
      },
    );
  });
}
