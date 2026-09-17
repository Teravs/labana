import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labana/core/theme/app_theme.dart';
import 'package:labana/features/products/models/product.dart';
import 'package:labana/features/products/models/recipe_version.dart';
import 'package:labana/features/products/presentation/widgets/product_card.dart';
import 'package:labana/features/sales/models/sale.dart';
import 'package:labana/features/sales/models/sale_item.dart';
import 'package:labana/features/sales/presentation/widgets/sale_card.dart';
import 'package:labana/features/sales/presentation/widgets/sale_item_tile.dart';

void main() {
  Widget buildTestApp(Widget child, {Size surfaceSize = const Size(320, 600)}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: surfaceSize.width, child: child),
          ),
        ),
      ),
    );
  }

  group('Stage 17 UAT Regression Tests', () {
    testWidgets(
      'UAT-07B: ProductCard tanpa harga jual tidak overflow pada layar sempit (320px)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const product = Product(
          id: 1,
          name: 'Es Kopi Susu Aren Gula Aren Signature Extra Creamy',
          createdAt: '2026-09-17',
          updatedAt: '2026-09-17',
        );

        const recipeVersion = RecipeVersion(
          id: 1,
          productId: 1,
          versionNumber: 1,
          effectiveFrom: '2026-09-17',
          hppTotal: 12500,
          createdAt: '2026-09-17',
        );

        await tester.pumpWidget(
          buildTestApp(
            const ProductCard(
              product: product,
              activeRecipeVersion: recipeVersion,
              currentPrice: null, // Harga belum diatur
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Belum ada harga'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UAT-09B: SaleCard dengan omzet Rp10.000.000 tidak overflow pada layar sempit (320px)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const sale = Sale(
          id: 1,
          transactionNumber: 'TRX-20260917-0001',
          transactionDate: '2026-09-17 14:30:00',
          totalAmount: 10000000,
          totalHpp: 6500000,
          totalProfit: 3500000,
          paymentMethod: Sale.paymentCash,
          itemCount: 200,
          createdAt: '2026-09-17T14:30:00Z',
          updatedAt: '2026-09-17T14:30:00Z',
        );

        await tester.pumpWidget(
          buildTestApp(SaleCard(sale: sale, onTap: () {})),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Omzet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'UAT-09B: SaleItemTile dengan berbagai nominal (Rp5.000 s/d Rp10.000.000) tidak overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final testNominals = [
          (5000, 3000),
          (25000, 15000),
          (125000, 80000),
          (1250000, 800000),
          (10000000, 6000000),
        ];

        for (final (price, hpp) in testNominals) {
          final item = SaleItem(
            id: 1,
            saleId: 1,
            productId: 10,
            recipeVersionId: 1,
            productName: 'Paket Minuman Komplit Premium',
            quantity: 1,
            sellingPrice: price,
            hppPerUnit: hpp,
            subtotal: price,
            totalHpp: hpp,
            totalProfit: price - hpp,
            createdAt: '2026-09-17T10:00:00Z',
          );

          // Test Mode Edit
          await tester.pumpWidget(
            buildTestApp(
              SaleItemTile(
                item: item,
                isEditable: true,
                onQuantityChanged: (_) {},
                onRemove: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Test Mode Read-only
          await tester.pumpWidget(
            buildTestApp(SaleItemTile(item: item, isEditable: false)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
