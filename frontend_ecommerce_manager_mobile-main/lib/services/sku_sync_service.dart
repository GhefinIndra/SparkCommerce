// lib/services/sku_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database_service.dart';

class SKUSyncService {
  static final SKUSyncService _instance = SKUSyncService._internal();
  factory SKUSyncService() => _instance;
  SKUSyncService._internal();

  final DatabaseService _db = DatabaseService();

  // Get base URL from .env
  String get _baseUrl {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:5000';
    return '$baseUrl/api';
  }

  // Get auth token from SharedPreferences
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get auth headers
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get selected shop ID
  Future<String?> _getSelectedShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_shop_id');
  }

  /// 1. Sync Stock to Marketplace
  /// Sync stock dari SKU Master ke semua marketplace yang linked
  Future<Map<String, dynamic>> syncStockToMarketplace({
    required String sku,
    required int stock,
  }) async {
    try {

      // Get all mappings for this SKU
      final mappings = await _db.getMappingsBySKU(sku);

      if (mappings.isEmpty) {
        return {
          'success': false,
          'message': 'SKU tidak terhubung ke marketplace manapun'
        };
      }


      List<String> synced = [];
      List<String> failed = [];

      // Loop all marketplaces
      for (var mapping in mappings) {
        final marketplace = mapping['marketplace'] as String;
        final productId = mapping['product_id'] as String;
        final variationId = mapping['variation_id'] as String?;
        final warehouseId = mapping['warehouse_id'] as String?;

        
        String? shopId = mapping['shop_id'] as String?;

        if (shopId == null) {
          shopId = await _getSelectedShopId();
        }


        if (shopId == null) {
          failed.add(marketplace);
          continue;
        }

        // Call API to sync
        final result = await _syncToMarketplace(
          shopId: shopId,
          productId: productId,
          variationId: variationId,
          warehouseId: warehouseId,
          stock: stock,
          marketplace: marketplace,
        );

        if (result) {
          synced.add(marketplace);
        } else {
          failed.add(marketplace);
        }
      }

      // Update last_sync_at
      if (synced.isNotEmpty) {
        await _db.updateLastSyncAt(sku);
      }

      // Build result message
      String message = '';
      if (synced.isNotEmpty) {
        message += ' Berhasil: ${synced.join(", ")}';
      }
      if (failed.isNotEmpty) {
        if (message.isNotEmpty) message += '\n';
        message += ' Gagal: ${failed.join(", ")}';
      }

      return {
        'success': synced.isNotEmpty,
        'message': message.isEmpty ? 'Tidak ada yang di-sync' : message,
        'synced': synced,
        'failed': failed,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal sync stock: $e'
      };
    }
  }

  /// Helper: Sync to specific marketplace
  Future<bool> _syncToMarketplace({
    required String shopId,
    required String productId,
    required String? variationId,
    required String? warehouseId,
    required int stock,
    required String marketplace,
  }) async {
    try {
      if (marketplace == 'TIKTOK') {
        return await _syncToTikTok(
          shopId: shopId,
          productId: productId,
          variationId: variationId,
          warehouseId: warehouseId,
          stock: stock,
        );
      }

      if (marketplace == 'SHOPEE') {
        return await _syncToShopee(
          shopId: shopId,
          productId: productId,
          variationId: variationId,
          stock: stock,
        );
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Sync to TikTok - Using same endpoint as product detail
  Future<bool> _syncToTikTok({
    required String shopId,
    required String productId,
    required String? variationId,
    required String? warehouseId,
    required int stock,
  }) async {
    try {
      if (variationId == null || warehouseId == null) {
        return false;
      }


      final url = '$_baseUrl/shops/$shopId/products/$productId/stock';


      final body = {
        'skus': [
          {
            'id': variationId,
            'warehouse_id': warehouseId,
            'available_stock': stock,
            'quantity': stock,
          }
        ]
      };

      print(' TikTok sync stock:');
      print('   URL: $url');
      print('   Product ID: $productId');
      print('   Variation ID: $variationId');
      print('   Warehouse ID: $warehouseId');
      print('   Stock: $stock');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      print('   Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('    TikTok sync success');
          return true;
        }
      }

      print('    TikTok sync failed');
      return false;
    } catch (e) {
      print('    TikTok sync error: $e');
      return false;
    }
  }

  /// Sync to Shopee - Using Shopee update stock endpoint
  Future<bool> _syncToShopee({
    required String shopId,
    required String productId,
    required String? variationId,
    required int stock,
  }) async {
    try {
      if (variationId == null) {
        print('   ️ Shopee sync skipped: variation_id is null');
        return false;
      }

      final url = '$_baseUrl/shopee/shops/$shopId/products/$productId/stock';

      final body = {
        'skus': [
          {
            'id': variationId, // model_id for Shopee
            'available_stock': stock,
            'quantity': stock,
          }
        ]
      };

      print(' Shopee sync stock:');
      print('   URL: $url');
      print('   Product ID: $productId');
      print('   Model ID: $variationId');
      print('   Stock: $stock');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      print('   Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('    Shopee sync success');
          return true;
        }
      }

      print('    Shopee sync failed');
      return false;
    } catch (e) {
      print('    Shopee sync error: $e');
      return false;
    }
  }

  /// 2. Pull Stock from Marketplace
  /// Ambil stock terkini dari marketplace dan update ke SKU Master
  Future<Map<String, dynamic>> pullStockFromMarketplace(String sku) async {
    try {

      final mappings = await _db.getMappingsBySKU(sku);

      if (mappings.isEmpty) {
        return {
          'success': false,
          'message': 'SKU tidak terhubung ke marketplace'
        };
      }

      // Get from first marketplace (TikTok priority)
      final mapping = mappings.first;
      final marketplace = mapping['marketplace'] as String;
      final productId = mapping['product_id'] as String;
      final shopId = await _getSelectedShopId();

      if (shopId == null) {
        return {
          'success': false,
          'message': 'Shop ID tidak ditemukan. Silakan pilih toko terlebih dahulu.'
        };
      }

      if (marketplace == 'TIKTOK') {
        final stock = await _pullFromTikTok(shopId, productId);
        if (stock != null) {
          await _db.updateSKUStock(sku, stock);
          return {
            'success': true,
            'message': 'Stock berhasil diambil dari TikTok',
            'stock': stock
          };
        }
      }

      return {
        'success': false,
        'message': 'Gagal mengambil stock dari marketplace'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  /// Pull stock from TikTok
  Future<int?> _pullFromTikTok(String shopId, String productId) async {
    try {
      final url =
          '$_baseUrl/shops/$shopId/products/$productId/get-stock?marketplace=TIKTOK';


      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      ).timeout(const Duration(seconds: 30));


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data']['skus'] != null) {
          final skus = data['data']['skus'] as List;
          if (skus.isNotEmpty) {
            final stock = skus.first['stock'] as int;
            return stock;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 3. Link Product to SKU
  /// Dipanggil setelah create product untuk auto-save mapping
  Future<void> linkProductToSKU({
    required String sku,
    required String marketplace,
    required String productId,
    String? variationId,
    String? warehouseId,
    String? shopId, 
  }) async {
    try {

      await _db.insertMapping(
        sku: sku,
        marketplace: marketplace,
        productId: productId,
        variationId: variationId,
        warehouseId: warehouseId,
        shopId: shopId, 
      );

    } catch (e) {
      rethrow;
    }
  }

  /// 4. Reduce Stock from Order (Coming Soon)
  /// Auto-reduce stock ketika ada order baru dan sync ke marketplace lain
  Future<void> reduceStockFromOrder({
    required String sku,
    required int quantity,
    required String marketplace,
  }) async {
    try {
      print(' reduceStockFromOrder: SKU=$sku, Quantity=$quantity, Source=$marketplace');

      // Get current stock
      final skuData = await _db.getSKU(sku);
      if (skuData == null) {
        print('    SKU not found in SKU Master');
        return;
      }

      final currentStock = skuData['stock'] as int;
      final newStock = currentStock - quantity;

      print('    Current stock: $currentStock  New stock: $newStock');

      if (newStock < 0) {
        print('   ️ Stock cannot be negative, skipping');
        return;
      }

      // Reduce stock in SKU Master
      await _db.updateSKUStock(sku, newStock);
      print('    SKU Master stock updated to $newStock');

      // Get all mappings
      final mappings = await _db.getMappingsBySKU(sku);
      print('    Found ${mappings.length} marketplace mappings');

      // Sync to other marketplaces (skip the source marketplace)
      int syncedCount = 0;
      for (var mapping in mappings) {
        final targetMarketplace = mapping['marketplace'] as String;

        // Skip marketplace yang jadi sumber order
        if (targetMarketplace.toUpperCase() == marketplace.toUpperCase()) {
          print('   ️  Skipping $targetMarketplace (source marketplace)');
          continue;
        }

        // Try to get shop_id from mapping first, fallback to selected shop
        String? shopId = mapping['shop_id'] as String?;
        if (shopId == null || shopId.isEmpty) {
          shopId = await _getSelectedShopId();
        }

        if (shopId == null) {
          print('   ️ No shop_id found for $targetMarketplace, skipping');
          continue;
        }

        print('    Syncing to $targetMarketplace (shop: $shopId)...');
        final success = await _syncToMarketplace(
          shopId: shopId,
          productId: mapping['product_id'] as String,
          variationId: mapping['variation_id'] as String?,
          warehouseId: mapping['warehouse_id'] as String?,
          stock: newStock,
          marketplace: targetMarketplace,
        );

        if (success) {
          syncedCount++;
          print('    $targetMarketplace synced successfully');
        } else {
          print('    $targetMarketplace sync failed');
        }
      }

      print('    Sync summary: $syncedCount/${mappings.length} marketplaces synced');

    } catch (e) {
      print('    Error in reduceStockFromOrder: $e');
    }
  }
}
