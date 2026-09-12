import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/screens/starter_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Root / Starter route
  static const String root = '/';

  // Planned feature routes for subsequent phases
  static const String home = '/home';
  static const String ingredients = '/ingredients';
  static const String processedIngredients = '/processed-ingredients';
  static const String products = '/products';
  static const String sales = '/sales';
  static const String reports = '/reports';
  static const String settings = '/settings';
}

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.root,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.root,
        name: 'root',
        builder: (BuildContext context, GoRouterState state) {
          return const StarterScreen();
        },
      ),
    ],
  );
}
