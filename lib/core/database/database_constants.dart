class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'labana.db';
  static const int databaseVersion = 1;
}

class TableNames {
  TableNames._();

  static const String ingredients = 'ingredients';
  static const String ingredientPrices = 'ingredient_prices';
  static const String processedIngredients = 'processed_ingredients';
  static const String processedComponents = 'processed_components';
  static const String products = 'products';
  static const String productPrices = 'product_prices';
  static const String recipeVersions = 'recipe_versions';
  static const String recipeItems = 'recipe_items';
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String settings = 'settings';
  static const String reportArchives = 'report_archives';

  static const List<String> all = [
    ingredients,
    ingredientPrices,
    processedIngredients,
    processedComponents,
    products,
    productPrices,
    recipeVersions,
    recipeItems,
    sales,
    saleItems,
    settings,
    reportArchives,
  ];
}

