import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../ingredients/data/ingredient_repository.dart';
import '../models/processed_component.dart';
import '../models/processed_ingredient.dart';

/// Service untuk memvalidasi ketergantungan antar bahan olahan
/// dan mencegah terbentuknya siklus ketergantungan (circular dependency).
class ProcessedDependencyValidator {
  final DatabaseHelper _dbHelper;

  ProcessedDependencyValidator({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Database> get _db => _dbHelper.database;

  /// Memeriksa apakah `parentId` dapat menggunakan `childId` sebagai komponen
  /// tanpa membentuk circular dependency atau self-reference.
  ///
  /// Mengembalikan `true` jika relasi aman, atau melempar [ValidationException]
  /// jika terdeteksi siklus atau self-reference.
  Future<bool> canAddChild(
    int? parentId,
    int childId, {
    DatabaseExecutor? executor,
  }) async {
    // 1. Cek self-reference langsung
    if (parentId != null && parentId == childId) {
      throw const ValidationException(
        'Bahan olahan tidak dapat menggunakan dirinya sendiri sebagai komponen.',
      );
    }

    // Jika parentId null (misal sedang membuat bahan olahan baru),
    // bahan baru belum memiliki ID di database sehingga tidak mungkin ada
    // bahan lain yang sudah bergantung padanya.
    if (parentId == null) {
      return true;
    }

    // 2. Deteksi siklus via DFS: Periksa apakah childId dapat mencapai parentId
    final client = executor ?? await _db;
    final isReachable = await _isAncestor(
      ancestorId: parentId,
      startId: childId,
      client: client,
    );

    if (isReachable) {
      throw const ValidationException(
        'Bahan olahan ini tidak dapat dipilih karena akan membuat siklus ketergantungan.',
      );
    }

    return true;
  }

  /// Memvalidasi seluruh komponen yang akan disimpan untuk [parentId].
  ///
  /// Memeriksa self-reference dan circular dependency untuk setiap komponen
  /// bertipe `processed`.
  Future<void> validateComponents(
    int? parentId,
    List<ProcessedComponent> components, {
    DatabaseExecutor? executor,
  }) async {
    final processedComponents = components.where((c) => c.isProcessed).toList();
    if (processedComponents.isEmpty) return;

    for (final comp in processedComponents) {
      if (comp.childProcessedId != null) {
        await canAddChild(parentId, comp.childProcessedId!, executor: executor);
      }
    }
  }

  /// Mengambil daftar bahan olahan anak yang aman dipilih oleh [currentProcessedId].
  ///
  /// Menyaring:
  /// 1. Hanya bahan olahan dengan status 'active'
  /// 2. Bukan dirinya sendiri (`id != currentProcessedId`)
  /// 3. Bukan ancestor yang akan membentuk circular dependency
  Future<List<ProcessedIngredient>> getValidChildCandidates({
    int? currentProcessedId,
    DatabaseExecutor? executor,
  }) async {
    final client = executor ?? await _db;
    final results = await client.query(
      TableNames.processedIngredients,
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    final allActive = results
        .map((map) => ProcessedIngredient.fromMap(map))
        .toList();

    if (currentProcessedId == null) {
      return allActive;
    }

    final validCandidates = <ProcessedIngredient>[];
    for (final candidate in allActive) {
      if (candidate.id == null) continue;
      if (candidate.id == currentProcessedId) continue;

      try {
        final canAdd = await canAddChild(
          currentProcessedId,
          candidate.id!,
          executor: client,
        );
        if (canAdd) {
          validCandidates.add(candidate);
        }
      } on ValidationException {
        // Dilewati jika akan membentuk siklus atau self-reference
        continue;
      }
    }

    return validCandidates;
  }

  /// Traversal rekursif (DFS) untuk memeriksa apakah `ancestorId` dapat dicapai dari `startId`.
  Future<bool> _isAncestor({
    required int ancestorId,
    required int startId,
    required DatabaseExecutor client,
    Set<int>? visited,
  }) async {
    final currentVisited = visited ?? <int>{};
    if (currentVisited.contains(startId)) {
      return false; // Hindari traversal berulang pada DAG
    }
    currentVisited.add(startId);

    // Ambil seluruh child_processed_id yang digunakan oleh startId
    final rows = await client.query(
      TableNames.processedComponents,
      columns: ['child_processed_id'],
      where:
          'processed_ingredient_id = ? AND component_type = ? AND child_processed_id IS NOT NULL',
      whereArgs: [startId, ProcessedComponent.typeProcessed],
    );

    for (final row in rows) {
      final childId = row['child_processed_id'] as int?;
      if (childId == null) continue;

      // Jika menemukan ancestorId dalam rantai dependensi child, berarti terbentuk siklus
      if (childId == ancestorId) {
        return true;
      }

      final found = await _isAncestor(
        ancestorId: ancestorId,
        startId: childId,
        client: client,
        visited: currentVisited,
      );
      if (found) {
        return true;
      }
    }

    return false;
  }

  /// Helper murni in-memory untuk algoritma deteksi siklus (memudahkan unit test).
  static bool checkCycleInMemory({
    required int? parentId,
    required int childId,
    required Map<int, List<int>> graph,
  }) {
    if (parentId != null && parentId == childId) {
      throw const ValidationException(
        'Bahan olahan tidak dapat menggunakan dirinya sendiri sebagai komponen.',
      );
    }

    if (parentId == null) return true;

    final visited = <int>{};
    bool dfs(int current) {
      if (visited.contains(current)) return false;
      visited.add(current);

      final neighbors = graph[current] ?? [];
      for (final next in neighbors) {
        if (next == parentId) return true;
        if (dfs(next)) return true;
      }
      return false;
    }

    if (dfs(childId)) {
      throw const ValidationException(
        'Bahan olahan ini tidak dapat dipilih karena akan membuat siklus ketergantungan.',
      );
    }

    return true;
  }
}
