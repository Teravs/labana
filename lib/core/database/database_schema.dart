import 'package:sqflite/sqflite.dart';

/// Mengelola skema DDL untuk seluruh tabel dan indeks database Labana.
class DatabaseSchema {
  DatabaseSchema._();

  // ---------------------------------------------------------------------------
  // 1. INGREDIENTS
  // ---------------------------------------------------------------------------
  static const String createIngredientsTable = '''
CREATE TABLE ingredients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
''';

  // ---------------------------------------------------------------------------
  // 2. INGREDIENT_PRICES
  // ---------------------------------------------------------------------------
  static const String createIngredientPricesTable = '''
CREATE TABLE ingredient_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ingredient_id INTEGER NOT NULL,
    purchase_quantity REAL NOT NULL CHECK (purchase_quantity > 0),
    purchase_unit TEXT NOT NULL
        CHECK (purchase_unit IN ('g', 'kg', 'ml', 'liter', 'pcs', 'pack')),
    base_quantity REAL NOT NULL CHECK (base_quantity > 0),
    base_unit TEXT NOT NULL
        CHECK (base_unit IN ('g', 'ml', 'pcs')),
    package_quantity REAL,
    price INTEGER NOT NULL CHECK (price >= 0),
    is_default INTEGER NOT NULL DEFAULT 0
        CHECK (is_default IN (0, 1)),
    effective_from TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (ingredient_id)
        REFERENCES ingredients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (
        (purchase_unit = 'pack' AND package_quantity IS NOT NULL AND package_quantity > 0)
        OR
        (purchase_unit != 'pack' AND package_quantity IS NULL)
    )
);
''';

  static const String createIdxOneDefaultIngredientPrice = '''
CREATE UNIQUE INDEX idx_one_default_ingredient_price
ON ingredient_prices(ingredient_id)
WHERE is_default = 1;
''';

  static const String createIdxIngredientPricesIngredientDate = '''
CREATE INDEX idx_ingredient_prices_ingredient_date
ON ingredient_prices(ingredient_id, effective_from);
''';

  // ---------------------------------------------------------------------------
  // 3. PROCESSED_INGREDIENTS
  // ---------------------------------------------------------------------------
  static const String createProcessedIngredientsTable = '''
CREATE TABLE processed_ingredients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    result_quantity REAL NOT NULL CHECK (result_quantity > 0),
    result_unit TEXT NOT NULL
        CHECK (result_unit IN ('g', 'ml', 'pcs')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
''';

  // ---------------------------------------------------------------------------
  // 4. PROCESSED_COMPONENTS
  // ---------------------------------------------------------------------------
  static const String createProcessedComponentsTable = '''
CREATE TABLE processed_components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    processed_ingredient_id INTEGER NOT NULL,

    component_type TEXT NOT NULL
        CHECK (component_type IN ('ingredient', 'processed', 'other')),

    ingredient_id INTEGER,
    child_processed_id INTEGER,

    quantity REAL,
    unit TEXT,

    other_cost INTEGER,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (processed_ingredient_id)
        REFERENCES processed_ingredients(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (ingredient_id)
        REFERENCES ingredients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    FOREIGN KEY (child_processed_id)
        REFERENCES processed_ingredients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (
        (
            component_type = 'ingredient'
            AND ingredient_id IS NOT NULL
            AND child_processed_id IS NULL
            AND quantity IS NOT NULL
            AND quantity > 0
            AND unit IS NOT NULL
            AND other_cost IS NULL
        )
        OR
        (
            component_type = 'processed'
            AND ingredient_id IS NULL
            AND child_processed_id IS NOT NULL
            AND quantity IS NOT NULL
            AND quantity > 0
            AND unit IS NOT NULL
            AND other_cost IS NULL
        )
        OR
        (
            component_type = 'other'
            AND ingredient_id IS NULL
            AND child_processed_id IS NULL
            AND quantity IS NULL
            AND unit IS NULL
            AND other_cost IS NOT NULL
            AND other_cost >= 0
        )
    )
);
''';

  static const String createIdxProcessedComponentsParent = '''
CREATE INDEX idx_processed_components_parent
ON processed_components(processed_ingredient_id);
''';

  // ---------------------------------------------------------------------------
  // 5. PRODUCTS
  // ---------------------------------------------------------------------------
  static const String createProductsTable = '''
CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
''';

  // ---------------------------------------------------------------------------
  // 6. PRODUCT_PRICES
  // ---------------------------------------------------------------------------
  static const String createProductPricesTable = '''
CREATE TABLE product_prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    selling_price INTEGER NOT NULL CHECK (selling_price >= 0),
    effective_from TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);
''';

  static const String createIdxProductPricesProductDate = '''
CREATE INDEX idx_product_prices_product_date
ON product_prices(product_id, effective_from);
''';

  // ---------------------------------------------------------------------------
  // 7. RECIPE_VERSIONS
  // ---------------------------------------------------------------------------
  static const String createRecipeVersionsTable = '''
CREATE TABLE recipe_versions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    version_number INTEGER NOT NULL CHECK (version_number > 0),
    effective_from TEXT NOT NULL,
    hpp_total INTEGER NOT NULL DEFAULT 0 CHECK (hpp_total >= 0),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'active', 'archived')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    UNIQUE(product_id, version_number)
);
''';

  static const String createIdxRecipeVersionsProductDate = '''
CREATE INDEX idx_recipe_versions_product_date
ON recipe_versions(product_id, effective_from);
''';

  // ---------------------------------------------------------------------------
  // 8. RECIPE_ITEMS
  // ---------------------------------------------------------------------------
  static const String createRecipeItemsTable = '''
CREATE TABLE recipe_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recipe_version_id INTEGER NOT NULL,

    component_type TEXT NOT NULL
        CHECK (component_type IN ('ingredient', 'processed', 'other')),

    ingredient_id INTEGER,
    processed_ingredient_id INTEGER,

    quantity REAL,
    unit TEXT,

    other_cost INTEGER,

    label TEXT,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (recipe_version_id)
        REFERENCES recipe_versions(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (ingredient_id)
        REFERENCES ingredients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    FOREIGN KEY (processed_ingredient_id)
        REFERENCES processed_ingredients(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CHECK (
        (
            component_type = 'ingredient'
            AND ingredient_id IS NOT NULL
            AND processed_ingredient_id IS NULL
            AND quantity IS NOT NULL
            AND quantity > 0
            AND unit IS NOT NULL
            AND other_cost IS NULL
        )
        OR
        (
            component_type = 'processed'
            AND ingredient_id IS NULL
            AND processed_ingredient_id IS NOT NULL
            AND quantity IS NOT NULL
            AND quantity > 0
            AND unit IS NOT NULL
            AND other_cost IS NULL
        )
        OR
        (
            component_type = 'other'
            AND ingredient_id IS NULL
            AND processed_ingredient_id IS NULL
            AND quantity IS NULL
            AND unit IS NULL
            AND other_cost IS NOT NULL
            AND other_cost >= 0
        )
    )
);
''';

  static const String createIdxRecipeItemsRecipe = '''
CREATE INDEX idx_recipe_items_recipe
ON recipe_items(recipe_version_id);
''';

  // ---------------------------------------------------------------------------
  // 9. SALES
  // ---------------------------------------------------------------------------
  static const String createSalesTable = '''
CREATE TABLE sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_number TEXT NOT NULL UNIQUE,
    transaction_date TEXT NOT NULL,

    payment_method TEXT NOT NULL DEFAULT 'cash'
        CHECK (payment_method IN ('cash', 'qris', 'transfer')),

    total_amount INTEGER NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    total_hpp INTEGER NOT NULL DEFAULT 0 CHECK (total_hpp >= 0),
    total_profit INTEGER NOT NULL DEFAULT 0,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
''';

  static const String createIdxSalesTransactionDate = '''
CREATE INDEX idx_sales_transaction_date
ON sales(transaction_date);
''';

  // ---------------------------------------------------------------------------
  // 10. SALE_ITEMS
  // ---------------------------------------------------------------------------
  static const String createSaleItemsTable = '''
CREATE TABLE sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER NOT NULL,

    product_id INTEGER NOT NULL,
    recipe_version_id INTEGER NOT NULL,

    product_name TEXT NOT NULL,

    quantity REAL NOT NULL CHECK (quantity > 0),

    selling_price INTEGER NOT NULL CHECK (selling_price >= 0),
    hpp_per_unit INTEGER NOT NULL CHECK (hpp_per_unit >= 0),

    subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
    total_hpp INTEGER NOT NULL CHECK (total_hpp >= 0),
    total_profit INTEGER NOT NULL,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (sale_id)
        REFERENCES sales(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    FOREIGN KEY (recipe_version_id)
        REFERENCES recipe_versions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);
''';

  static const String createIdxSaleItemsSale = '''
CREATE INDEX idx_sale_items_sale
ON sale_items(sale_id);
''';

  static const String createIdxSaleItemsProduct = '''
CREATE INDEX idx_sale_items_product
ON sale_items(product_id);
''';

  // ---------------------------------------------------------------------------
  // 11. SETTINGS
  // ---------------------------------------------------------------------------
  static const String createSettingsTable = '''
CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
''';

  // ---------------------------------------------------------------------------
  // 12. REPORT_ARCHIVES
  // ---------------------------------------------------------------------------
  static const String createReportArchivesTable = '''
CREATE TABLE report_archives (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    report_type TEXT NOT NULL
        CHECK (report_type IN ('daily', 'weekly', 'monthly')),

    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,

    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,

    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (period_end >= period_start)
);
''';

  static const String createIdxReportArchivesPeriod = '''
CREATE INDEX idx_report_archives_period
ON report_archives(period_start, period_end);
''';

  // ---------------------------------------------------------------------------
  // SCHEMA CREATION RUNNER
  // ---------------------------------------------------------------------------
  /// Mengeksekusi pembuatan seluruh tabel dan indeks dalam urutan foreign key yang aman.
  static Future<void> createSchema(DatabaseExecutor db) async {
    final batch = db.batch();

    // 1. ingredients
    batch.execute(createIngredientsTable);

    // 2. ingredient_prices
    batch.execute(createIngredientPricesTable);
    batch.execute(createIdxOneDefaultIngredientPrice);
    batch.execute(createIdxIngredientPricesIngredientDate);

    // 3. processed_ingredients
    batch.execute(createProcessedIngredientsTable);

    // 4. processed_components
    batch.execute(createProcessedComponentsTable);
    batch.execute(createIdxProcessedComponentsParent);

    // 5. products
    batch.execute(createProductsTable);

    // 6. product_prices
    batch.execute(createProductPricesTable);
    batch.execute(createIdxProductPricesProductDate);

    // 7. recipe_versions
    batch.execute(createRecipeVersionsTable);
    batch.execute(createIdxRecipeVersionsProductDate);

    // 8. recipe_items
    batch.execute(createRecipeItemsTable);
    batch.execute(createIdxRecipeItemsRecipe);

    // 9. sales
    batch.execute(createSalesTable);
    batch.execute(createIdxSalesTransactionDate);

    // 10. sale_items
    batch.execute(createSaleItemsTable);
    batch.execute(createIdxSaleItemsSale);
    batch.execute(createIdxSaleItemsProduct);

    // 11. settings
    batch.execute(createSettingsTable);

    // 12. report_archives
    batch.execute(createReportArchivesTable);
    batch.execute(createIdxReportArchivesPeriod);

    await batch.commit(noResult: true);
  }
}
