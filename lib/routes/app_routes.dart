import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/screens/home_screen.dart';
import '../features/ingredients/presentation/screens/ingredient_detail_screen.dart';
import '../features/ingredients/presentation/screens/ingredients_screen.dart';
import '../features/processed_ingredients/presentation/screens/processed_ingredient_detail_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/sales/presentation/screens/sales_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/shell/presentation/screens/app_shell.dart';

class AppRoutes {
  AppRoutes._();

  // Root route
  static const String root = '/';

  // 5 Main Navigation Routes
  static const String home = '/home';
  static const String ingredients = '/ingredients';
  static const String ingredientDetail = '/ingredients/:id';
  static const String sales = '/sales';
  static const String reports = '/reports';
  static const String settings = '/settings';

  // Processed ingredients & products
  static const String processedIngredients = '/processed-ingredients';
  static const String processedIngredientDetail = '/processed-ingredients/:id';
  static const String products = '/products';
}

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      // Redirect root '/' ke '/home'
      GoRoute(
        path: AppRoutes.root,
        redirect: (BuildContext context, GoRouterState state) => AppRoutes.home,
      ),

      // App Shell dengan 5 cabang navigasi
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return AppShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          // 1. Home
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (BuildContext context, GoRouterState state) {
                  return const HomeScreen();
                },
              ),
            ],
          ),

          // 2. Bahan
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.ingredients,
                name: 'ingredients',
                builder: (BuildContext context, GoRouterState state) {
                  return const IngredientsScreen();
                },
                routes: [
                  GoRoute(
                    path: 'processed/:id',
                    name: 'processed-ingredient-detail',
                    builder: (BuildContext context, GoRouterState state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                      return ProcessedIngredientDetailScreen(
                        processedIngredientId: id,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'ingredient-detail',
                    builder: (BuildContext context, GoRouterState state) {
                      final id =
                          int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                      return IngredientDetailScreen(ingredientId: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // 3. Penjualan
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.sales,
                name: 'sales',
                builder: (BuildContext context, GoRouterState state) {
                  return const SalesScreen();
                },
              ),
            ],
          ),

          // 4. Laporan
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.reports,
                name: 'reports',
                builder: (BuildContext context, GoRouterState state) {
                  return const ReportsScreen();
                },
              ),
            ],
          ),

          // 5. Pengaturan
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                name: 'settings',
                builder: (BuildContext context, GoRouterState state) {
                  return const SettingsScreen();
                },
              ),
            ],
          ),
        ],
      ),

      // Direct route fallback untuk /processed-ingredients/:id
      GoRoute(
        path: '/processed-ingredients/:id',
        name: 'processed-ingredient-detail-direct',
        builder: (BuildContext context, GoRouterState state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ProcessedIngredientDetailScreen(processedIngredientId: id);
        },
      ),
    ],
  );
}
