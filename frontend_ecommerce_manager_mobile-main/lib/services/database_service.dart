// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static const String _databaseName = 'sku_manager.db';
  static const int _databaseVersion = 6;  // UPGRADED to 6 (add transaction_sync_log)

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,  // ADD onUpgrade handler
    );
  }

  // Handle database upgrade
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {

    if (oldVersion < 2) {
      // Upgrade to v2: Add new columns to sku_master
      await db.execute('ALTER TABLE sku_master ADD COLUMN description TEXT DEFAULT ""');
      await db.execute('ALTER TABLE sku_master ADD COLUMN price REAL DEFAULT 0.0');
      await db.execute('ALTER TABLE sku_master ADD COLUMN last_sync_at TEXT');
    }

    if (oldVersion < 3) {
      // Upgrade to v3: Add shop_id to mapping table
      await db.execute('ALTER TABLE sku_marketplace_mapping ADD COLUMN shop_id TEXT');
    }

    if (oldVersion < 4) {
      // Upgrade to v4: Recreate transaction_master with proper order fields
      await db.execute('DROP TABLE IF EXISTS transaction_master');
      await db.execute('''
        CREATE TABLE orders (
          order_id TEXT PRIMARY KEY,
          shop_id TEXT NOT NULL,
          provider TEXT NOT NULL,
          order_status TEXT NOT NULL,
          create_time INTEGER NOT NULL,
          update_time INTEGER NOT NULL,
          paid_time INTEGER,
          total_amount TEXT,
          currency TEXT,
          buyer_user_id TEXT,
          tracking_number TEXT,
          synced_to_dashboard_at INTEGER,
          raw_data TEXT
        )
      ''');
      await db.execute('CREATE INDEX idx_orders_shop_provider ON orders(shop_id, provider)');
      await db.execute('CREATE INDEX idx_orders_create_time ON orders(create_time DESC)');
    }

    if (oldVersion < 5) {
      // Upgrade to v5: Add stock_synced_at to orders table
      await db.execute('ALTER TABLE orders ADD COLUMN stock_synced_at INTEGER');
    }

    if (oldVersion < 6) {
      // Upgrade to v6: Add transaction_sync_log for dashboard sync tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_sync_log (
          shop_id TEXT NOT NULL,
          platform TEXT NOT NULL,
          last_synced_order_id TEXT,
          last_synced_order_time INTEGER,
          last_sync_at INTEGER,
          total_orders_synced INTEGER DEFAULT 0,
          last_sync_status TEXT DEFAULT 'PENDING',
          error_message TEXT,
          PRIMARY KEY (shop_id, platform)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_log_shop ON transaction_sync_log(shop_id)');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabel 1: SKU Master (Manual Input) - v3 schema
    await db.execute('''
      CREATE TABLE sku_master (
        sku TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        stock INTEGER DEFAULT 0,
        price REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_sync_at TEXT
      )
    ''');

    // Tabel 2: Orders (untuk tracking dan incremental sync)
    await db.execute('''
      CREATE TABLE orders (
        order_id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        provider TEXT NOT NULL,
        order_status TEXT NOT NULL,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL,
        paid_time INTEGER,
        total_amount TEXT,
        currency TEXT,
        buyer_user_id TEXT,
        tracking_number TEXT,
        synced_to_dashboard_at INTEGER,
        stock_synced_at INTEGER,
        raw_data TEXT
      )
    ''');

    // Tabel 3: Mapping SKU ke Marketplace
    await db.execute('''
      CREATE TABLE sku_marketplace_mapping (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        marketplace TEXT NOT NULL,
        product_id TEXT NOT NULL,
        variation_id TEXT,
        warehouse_id TEXT,
        shop_id TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(sku, marketplace)
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_sku_master ON sku_master(sku)');
    await db.execute('CREATE INDEX idx_orders_shop_provider ON orders(shop_id, provider)');
    await db.execute('CREATE INDEX idx_orders_create_time ON orders(create_time DESC)');
    await db.execute('CREATE INDEX idx_mapping_sku ON sku_marketplace_mapping(sku)');

  }

  // ============ SKU MASTER OPERATIONS ============
  
  Future<void> insertSKU({
    required String sku,
    required String name,
    required int stock,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'sku_master',
      {
        'sku': sku,
        'name': name,
        'stock': stock,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
  }

  Future<void> updateSKUStock(String sku, int newStock) async {
    final db = await database;
    await db.update(
      'sku_master',
      {
        'stock': newStock,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'sku = ?',
      whereArgs: [sku],
    );
  }

  Future<void> reduceSKUStock(String sku, int quantity) async {
    final db = await database;
    final result = await db.query(
      'sku_master',
      where: 'sku = ?',
      whereArgs: [sku],
    );
    
    if (result.isEmpty) {
      return;
    }
    
    final currentStock = result.first['stock'] as int;
    final newStock = currentStock - quantity;
    
    if (newStock < 0) {
      return;
    }
    
    await updateSKUStock(sku, newStock);
  }

  Future<Map<String, dynamic>?> getSKU(String sku) async {
    final db = await database;
    final result = await db.query(
      'sku_master',
      where: 'sku = ?',
      whereArgs: [sku],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSKUs() async {
    final db = await database;
    return await db.query('sku_master', orderBy: 'created_at DESC');
  }

  Future<void> deleteSKU(String sku) async {
    final db = await database;
    await db.delete('sku_master', where: 'sku = ?', whereArgs: [sku]);
  }

  // Update last_sync_at timestamp
  Future<void> updateLastSyncAt(String sku) async {
    final db = await database;
    await db.update(
      'sku_master',
      {'last_sync_at': DateTime.now().toIso8601String()},
      where: 'sku = ?',
      whereArgs: [sku],
    );
  }

  // ============ ORDER OPERATIONS ============

  /// Save or update orders to SQLite
  Future<void> saveOrders(List<Map<String, dynamic>> orders) async {
    final db = await database;

    print(' saveOrders: Processing ${orders.length} orders...');

    // First, count total orders in database before processing
    final beforeCount = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
    print('    Orders in DB before: ${beforeCount.first['count']}');

    // Process each order individually (can't use batch because we need to query existing first)
    for (var order in orders) {
      // Check if order already exists
      final existing = await db.query(
        'orders',
        where: 'order_id = ?',
        whereArgs: [order['order_id']],
        limit: 1,
      );

      print('    Query existing for ${order['order_id']}: found ${existing.length} rows');
      if (existing.isNotEmpty) {
        print('      Existing stock_synced_at: ${existing.first['stock_synced_at']}');
      }

      if (existing.isEmpty) {
        // New order - insert
        print('    INSERT new order: ${order['order_id']}');
        try {
          await db.insert(
            'orders',
            order,
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          print('       INSERT successful');
        } catch (e) {
          print('       INSERT failed: $e');
        }
      } else {
        // Existing order - update only non-synced fields
        // PRESERVE stock_synced_at if already set!
        final existingStockSyncedAt = existing.first['stock_synced_at'];
        final updateData = Map<String, dynamic>.from(order);

        // If stock_synced_at already exists, don't overwrite it
        if (existingStockSyncedAt != null) {
          updateData['stock_synced_at'] = existingStockSyncedAt;
          print('    UPDATE order: ${order['order_id']} (PRESERVING stock_synced_at=$existingStockSyncedAt)');
        } else {
          print('    UPDATE order: ${order['order_id']} (no stock_synced_at to preserve)');
        }

        await db.update(
          'orders',
          updateData,
          where: 'order_id = ?',
          whereArgs: [order['order_id']],
        );
      }
    }

    print(' saveOrders: All orders processed');
  }

  /// Get last order timestamp for a specific shop+provider (for incremental sync)
  Future<int?> getLastOrderTime(String shopId, String provider) async {
    final db = await database;
    final result = await db.query(
      'orders',
      columns: ['create_time'],
      where: 'shop_id = ? AND provider = ?',
      whereArgs: [shopId, provider],
      orderBy: 'create_time DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['create_time'] as int;
  }

  /// Delete old orders for a specific shop+provider (before saving new ones)
  Future<void> deleteOrdersByShopAndProvider(String shopId, String provider) async {
    final db = await database;
    await db.delete(
      'orders',
      where: 'shop_id = ? AND provider = ?',
      whereArgs: [shopId, provider],
    );
  }

  /// Get all orders for a shop+provider
  Future<List<Map<String, dynamic>>> getOrders({
    required String shopId,
    required String provider,
  }) async {
    final db = await database;
    return await db.query(
      'orders',
      where: 'shop_id = ? AND provider = ?',
      whereArgs: [shopId, provider],
      orderBy: 'create_time DESC',
    );
  }

  /// Mark orders as synced to dashboard
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = db.batch();

    for (var orderId in orderIds) {
      batch.update(
        'orders',
        {'synced_to_dashboard_at': now},
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Mark orders as stock synced (prevent double-reduce stock)
  Future<void> markOrdersAsStockSynced(List<String> orderIds) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final batch = db.batch();

    print(' Marking ${orderIds.length} orders as synced...');
    for (var orderId in orderIds) {
      print('   - Setting stock_synced_at=$now for order: $orderId');
      batch.update(
        'orders',
        {'stock_synced_at': now},
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    }

    final results = await batch.commit();
    print(' Batch commit completed. Affected rows: $results');

    // Verify the update
    for (var orderId in orderIds) {
      final verifyResult = await db.query(
        'orders',
        columns: ['order_id', 'stock_synced_at'],
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      if (verifyResult.isNotEmpty) {
        print('    Verified $orderId: stock_synced_at = ${verifyResult.first['stock_synced_at']}');
      } else {
        print('    Order $orderId not found in database!');
      }
    }
  }

  /// Get unsynced orders (stock not yet reduced)
  Future<List<Map<String, dynamic>>> getUnsyncedStockOrders({
    required String shopId,
    required String provider,
  }) async {
    final db = await database;
    return await db.query(
      'orders',
      where: 'shop_id = ? AND provider = ? AND stock_synced_at IS NULL',
      whereArgs: [shopId, provider],
      orderBy: 'create_time DESC',
    );
  }

  // ============ MARKETPLACE MAPPING OPERATIONS ============
  
  Future<void> insertMapping({
    required String sku,
    required String marketplace,
    required String productId,
    String? variationId,
    String? warehouseId,
    String? shopId, 
  }) async {
    final db = await database;

    await db.insert(
      'sku_marketplace_mapping',
      {
        'sku': sku,
        'marketplace': marketplace,
        'product_id': productId,
        'variation_id': variationId,
        'warehouse_id': warehouseId,
        'shop_id': shopId, 
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

  }

  Future<Map<String, dynamic>?> getMapping(String sku, String marketplace) async {
    final db = await database;
    final result = await db.query(
      'sku_marketplace_mapping',
      where: 'sku = ? AND marketplace = ?',
      whereArgs: [sku, marketplace],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getMappingsBySKU(String sku) async {
    final db = await database;
    return await db.query(
      'sku_marketplace_mapping',
      where: 'sku = ?',
      whereArgs: [sku],
    );
  }

  /// Get SKU code by variation_id (for order item mapping)
  Future<String?> getSKUByVariationId(String variationId, String marketplace) async {
    final db = await database;
    final result = await db.query(
      'sku_marketplace_mapping',
      columns: ['sku'],
      where: 'variation_id = ? AND marketplace = ?',
      whereArgs: [variationId, marketplace],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['sku'] as String;
  }

  // ============ TRANSACTION SYNC LOG OPERATIONS ============

  /// Get transaction sync log for a shop
  Future<Map<String, dynamic>?> getTransactionSyncLog(String shopId, String platform) async {
    final db = await database;
    final result = await db.query(
      'transaction_sync_log',
      where: 'shop_id = ? AND platform = ?',
      whereArgs: [shopId, platform],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Update transaction sync log after successful sync
  Future<void> updateTransactionSyncLog({
    required String shopId,
    required String platform,
    required String lastSyncedOrderId,
    required int lastSyncedOrderTime,
    required int totalOrdersSynced,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await db.insert(
      'transaction_sync_log',
      {
        'shop_id': shopId,
        'platform': platform,
        'last_synced_order_id': lastSyncedOrderId,
        'last_synced_order_time': lastSyncedOrderTime,
        'last_sync_at': now,
        'total_orders_synced': totalOrdersSynced,
        'last_sync_status': 'SUCCESS',
        'error_message': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mark transaction sync as failed
  Future<void> markTransactionSyncFailed({
    required String shopId,
    required String platform,
    required String errorMessage,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Get existing log
    final existing = await getTransactionSyncLog(shopId, platform);

    await db.insert(
      'transaction_sync_log',
      {
        'shop_id': shopId,
        'platform': platform,
        'last_synced_order_id': existing?['last_synced_order_id'],
        'last_synced_order_time': existing?['last_synced_order_time'],
        'last_sync_at': now,
        'total_orders_synced': existing?['total_orders_synced'] ?? 0,
        'last_sync_status': 'FAILED',
        'error_message': errorMessage,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ============ UTILITY ============

  Future<int> getSKUCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sku_master');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Reset all orders stock_synced_at (for debugging/testing)
  Future<void> resetAllOrdersStockSync() async {
    final db = await database;
    await db.update(
      'orders',
      {'stock_synced_at': null},
    );
    print(' Reset all orders stock_synced_at to NULL');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> printAllData() async {
    print('\n=== SKU MASTER ===');
    final skus = await getAllSKUs();
    for (var sku in skus) {
      print('${sku['sku']}: ${sku['name']} (Stock: ${sku['stock']})');
    }

    print('\n=== ORDERS ===');
    final db = await database;
    final orders = await db.query('orders', orderBy: 'create_time DESC');
    for (var order in orders) {
      print('${order['order_id']} - ${order['provider']}: ${order['total_amount']}');
    }

    print('\n=== SKU MAPPINGS ===');
    final mappings = await db.query('sku_marketplace_mapping');
    for (var mapping in mappings) {
      print('${mapping['sku']}  ${mapping['marketplace']} (${mapping['product_id']})');
    }
  }
}