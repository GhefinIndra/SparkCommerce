// lib/services/transaction_sync_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import 'database_service.dart';
import 'auth_service.dart';
import '../utils/app_config.dart';

/// Service untuk sync transaksi ke dashboard eksternal
/// Hanya dipanggil dari ViewOrdersScreen (bukan dari Home/Shop screen)
class TransactionSyncService {
  static final TransactionSyncService _instance = TransactionSyncService._internal();
  factory TransactionSyncService() => _instance;
  TransactionSyncService._internal();

  final DatabaseService _db = DatabaseService();

  // Backend API base URL - compile-time define (BASE_URL)
  static String get baseUrl => AppConfig.apiBaseUrl;

  /// Main method: Sync transactions to dashboard
  /// Should ONLY be called from ViewOrdersScreen after orders are loaded
  Future<void> syncTransactionsToDashboard({
    required String shopId,
    required String platform,
    required List<Order> orders,
  }) async {
    try {
      print(' Starting transaction sync for shop: $shopId ($platform)');

      // Step 1: Check if user has group_id
      final userProfile = await _getUserProfile();
      if (userProfile == null || userProfile['group_id'] == null || userProfile['group_id'].isEmpty) {
        print('️  User has no group_id - skipping dashboard sync');
        return;
      }

      final groupId = userProfile['group_id'] as String;
      print(' User has group_id: $groupId');

      // Step 2: Verify group exists (backend will handle URL/secret lookup)
      final groupInfo = await _getGroupInfo(groupId);
      if (groupInfo == null) {
        print('️  Group $groupId not found - skipping dashboard sync');
        await _db.markTransactionSyncFailed(
          shopId: shopId,
          platform: platform,
          errorMessage: 'Group not found',
        );
        return;
      }

      print(' Group verified: $groupId');

      // Step 3: Get last sync log to determine new orders
      final syncLog = await _db.getTransactionSyncLog(shopId, platform);
      final lastSyncedOrderTime = syncLog?['last_synced_order_time'] as int?;

      // Step 4: Filter new orders (only those created after last sync)
      List<Order> newOrders;
      if (lastSyncedOrderTime == null) {
        // First sync - send all orders
        newOrders = orders;
        print(' First sync - sending all ${orders.length} orders');
      } else {
        // Incremental sync - only new orders
        newOrders = orders.where((order) {
          return order.createdTime > lastSyncedOrderTime;
        }).toList();
        print(' Incremental sync - sending ${newOrders.length} new orders (out of ${orders.length} total)');
      }

      if (newOrders.isEmpty) {
        print(' No new orders to sync');
        return;
      }

      // Step 5: Get auth token for backend request
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('current_user_email');
      final authToken = currentEmail != null
          ? await AuthService().getStoredAuthToken(currentEmail)
          : null;

      // Step 6: Prepare payload
      final payload = {
        'group_id': groupId,
        'shop_id': shopId,
        'platform': platform,
        'transactions': newOrders.map((order) => {
          'order_id': order.id,
          'order_status': order.status,
          'total_amount': order.totalAmount,
          'currency': order.currency,
          'create_time': order.createdTime,
          'update_time': order.updatedTime,
          'paid_date': order.paidDate,
          'buyer_name': order.buyerName,
          'tracking_number': order.trackingNumber,
          'items_count': order.items.length,
          'items': order.items.map((item) => {
            'product_id': item.productId,
            'product_name': item.productName,
            'sku_id': item.skuId,
            'seller_sku': item.sellerSku,
            'quantity': item.quantity,
            'original_price': item.originalPrice,
            'price': item.price,
          }).toList(),
        }).toList(),
      };

      // Step 7: Send to backend proxy (backend will forward to dashboard)
      print(' Sending ${newOrders.length} orders to backend proxy...');
      final response = await http.post(
        Uri.parse('$baseUrl/groups/sync-transactions'),
        headers: {
          'Content-Type': 'application/json',
          'auth_token': authToken ?? '',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print(' Successfully synced ${newOrders.length} orders to dashboard');
        print(' Response status: ${response.statusCode}');

        // Step 7: Update sync log
        final latestOrder = newOrders.reduce((a, b) => a.createdTime > b.createdTime ? a : b);
        await _db.updateTransactionSyncLog(
          shopId: shopId,
          platform: platform,
          lastSyncedOrderId: latestOrder.id,
          lastSyncedOrderTime: latestOrder.createdTime,
          totalOrdersSynced: (syncLog?['total_orders_synced'] as int? ?? 0) + newOrders.length,
        );

        print(' Transaction sync completed successfully');
      } else {
        throw Exception('Dashboard returned status ${response.statusCode}: ${response.body}');
      }

    } catch (e) {
      print(' Failed to sync transactions to dashboard: $e');

      // Mark sync as failed
      await _db.markTransactionSyncFailed(
        shopId: shopId,
        platform: platform,
        errorMessage: e.toString(),
      );
    }
  }

  /// Get user profile including group_id
  Future<Map<String, dynamic>?> _getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('current_user_email');
      if (currentEmail == null) {
        print(' No current user found');
        return null;
      }

      final token = await AuthService().getStoredAuthToken(currentEmail);
      if (token == null) {
        print(' No auth token found');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'auth_token': token,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      print(' Failed to get user profile: $e');
      return null;
    }
  }

  /// Get group info by GID
  Future<Map<String, dynamic>?> _getGroupInfo(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('current_user_email');
      if (currentEmail == null) {
        print(' No current user found');
        return null;
      }

      final token = await AuthService().getStoredAuthToken(currentEmail);
      if (token == null) {
        print(' No auth token found');
        return null;
      }

      final url = '$baseUrl/groups/$groupId';
      print(' Requesting group info from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'auth_token': token,
        },
      ).timeout(const Duration(seconds: 5));

      print(' Response status: ${response.statusCode}');
      print(' Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          print(' Group info received successfully');
          return data['data'] as Map<String, dynamic>;
        } else {
          print('️  Response success=false or data=null');
        }
      } else {
        print(' Non-200 status code: ${response.statusCode}');
      }

      return null;
    } catch (e) {
      print(' Failed to get group info: $e');
      return null;
    }
  }

  /// Get sync status for a shop (for UI display)
  Future<Map<String, dynamic>?> getSyncStatus(String shopId, String platform) async {
    return await _db.getTransactionSyncLog(shopId, platform);
  }
}
