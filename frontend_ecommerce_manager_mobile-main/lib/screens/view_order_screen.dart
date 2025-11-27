import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sku_sync_service.dart';
import '../services/transaction_sync_service.dart';
import 'order_detail_screen.dart';

class ViewOrdersScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String platform; // TikTok or Shopee

  const ViewOrdersScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.platform,
  }) : super(key: key);

  @override
  _ViewOrdersScreenState createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  final SKUSyncService _skuSyncService = SKUSyncService();
  final TransactionSyncService _transactionSyncService = TransactionSyncService();
  List<Order> orders = [];
  List<Order> filteredOrders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _selectedFilter = 'ALL'; // ALL, UNPAID, AWAITING_SHIPMENT, IN_TRANSIT, DELIVERED, CANCELLED

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadOrders();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// Auto reduce stock from order items
  /// Loop through all order items, find SKU Master using sku_id, reduce stock
  /// Only process orders that haven't been synced yet (stock_synced_at IS NULL)
  Future<void> _reduceStockFromOrders(List<Order> orders, String provider) async {
    try {
      int totalItemsProcessed = 0;
      int totalItemsReduced = 0;
      List<String> processedOrderIds = [];

      print(' Starting stock reduction for ${orders.length} orders...');

      // Get unsynced orders ONCE at the beginning
      final unsyncedOrders = await _dbService.getUnsyncedStockOrders(
        shopId: widget.shopId,
        provider: provider,
      );

      print(' Found ${unsyncedOrders.length} unsynced orders in database');

      // Create a Set of unsynced order IDs for fast lookup
      final unsyncedOrderIds = unsyncedOrders.map((o) => o['order_id'] as String).toSet();

      print(' Unsynced order IDs: $unsyncedOrderIds');

      for (var order in orders) {
        // Check if order already synced OR already processed in this session
        final isInUnsyncedList = unsyncedOrderIds.contains(order.id);
        final isAlreadyProcessed = processedOrderIds.contains(order.id);

        print(' Checking order ${order.id}:');
        print('   - In unsynced list: $isInUnsyncedList');
        print('   - Already processed in session: $isAlreadyProcessed');

        if (!isInUnsyncedList || isAlreadyProcessed) {
          print('️  Skipping order ${order.id} - already synced');
          continue;
        }

        print(' Processing order ${order.id}');
        print('   Status: ${order.orderStatusName} (${order.statusCode})');
        print('   Items: ${order.items.length}');

        for (var item in order.items) {
          totalItemsProcessed++;

          String? skuCode;

          // For Shopee, try seller_sku first, fallback to model_id
          if (provider.toUpperCase() == 'SHOPEE') {
            if (item.sellerSku.isNotEmpty) {
              print('      Seller SKU: ${item.sellerSku}');
              print('      Quantity: ${item.quantity}');
              skuCode = item.sellerSku;
            } else if (item.skuId.isNotEmpty) {
              print('      Model ID: ${item.skuId}');
              print('      Quantity: ${item.quantity}');
              skuCode = await _dbService.getSKUByVariationId(item.skuId, provider);
            }
          } else {
            // For TikTok, use sku_id (variation_id)
            if (item.skuId.isEmpty) {
              continue;
            }

            print('      SKU ID: ${item.skuId}');
            print('      Quantity: ${item.quantity}');

            skuCode = await _dbService.getSKUByVariationId(item.skuId, provider);
          }

          if (skuCode == null || skuCode.isEmpty) {
            print('      ️ SKU not found in mapping, skipping...');
            continue;
          }

          print('       Found SKU: $skuCode');

          // Reduce stock using SKUSyncService
          // This will reduce stock in SKU Master and sync to other marketplaces
          await _skuSyncService.reduceStockFromOrder(
            sku: skuCode,
            quantity: item.quantity,
            marketplace: provider,
          );

          totalItemsReduced++;
        }

        // Mark this order as stock synced
        processedOrderIds.add(order.id);
      }

      // Mark all processed orders as synced
      if (processedOrderIds.isNotEmpty) {
        await _dbService.markOrdersAsStockSynced(processedOrderIds);
        print(' Marked ${processedOrderIds.length} orders as stock synced');
      }

      print(' Stock reduction summary:');
      print('   Total items processed: $totalItemsProcessed');
      print('   Total items reduced: $totalItemsReduced');
      print('   Skipped: ${totalItemsProcessed - totalItemsReduced}');
    } catch (e) {
      print(' Error in _reduceStockFromOrders: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final provider = widget.platform.toUpperCase(); // TIKTOK or SHOPEE

      // Step 1: Get last order time from SQLite for incremental sync
      final lastOrderTime = await _dbService.getLastOrderTime(widget.shopId, provider);


      // Step 2: Fetch orders from API (backend will sync to dashboard automatically)
      // Backend already sends to dashboard in orderController.js
      List<Order> response;
      if (provider == 'SHOPEE') {
        response = await _apiService.getShopeeOrders(widget.shopId);
      } else {
        response = await _apiService.getOrders(widget.shopId);
      }

      // Step 3: Save new orders to SQLite (UPSERT - will preserve stock_synced_at)
      if (response.isNotEmpty) {
        final ordersToSave = response.map((order) {
          return {
            'order_id': order.id,
            'shop_id': widget.shopId,
            'provider': provider,
            'order_status': order.statusCode,
            'create_time': order.orderDate != null && order.orderDate!.isNotEmpty
                ? DateTime.parse(order.orderDate!).millisecondsSinceEpoch ~/ 1000
                : 0,
            'update_time': order.updateDate != null && order.updateDate!.isNotEmpty
                ? DateTime.parse(order.updateDate!).millisecondsSinceEpoch ~/ 1000
                : 0,
            'paid_time': order.paidDate != null && order.paidDate!.isNotEmpty
                ? DateTime.parse(order.paidDate!).millisecondsSinceEpoch ~/ 1000
                : null,
            'total_amount': order.totalAmount.toString(),
            'currency': order.currency,
            'buyer_user_id': '', // Not available in current Order model
            'tracking_number': order.trackingNumber ?? '',
            'synced_to_dashboard_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'raw_data': jsonEncode(order.toJson()),
          };
        }).toList();

        await _dbService.saveOrders(ordersToSave);

        // Step 4: Auto reduce stock from order items
        await _reduceStockFromOrders(response, provider);

        // Step 5: Sync transactions to dashboard (NEW - only happens here!)
        // This will only send NEW orders based on transaction_sync_log
        await _transactionSyncService.syncTransactionsToDashboard(
          shopId: widget.shopId,
          platform: provider,
          orders: response,
        );
      }

      setState(() {
        orders = response;
        _applyFilter();
        _isLoading = false;
      });

      _fadeController.forward();

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'ALL') {
        filteredOrders = List.from(orders);
      } else {
        filteredOrders = orders.where((order) {
          return order.statusCode == _selectedFilter;
        }).toList();
      }
    });
  }

  String _getFilterTitle(String filter) {
    switch (filter) {
      case 'ALL':
        return 'Semua';
      case 'UNPAID':
        return 'Belum Bayar';
      case 'AWAITING_SHIPMENT':
        return 'Siap Kirim';
      case 'IN_TRANSIT':
        return 'Dalam Pengiriman';
      case 'DELIVERED':
        return 'Selesai';
      case 'CANCELLED':
        return 'Dibatalkan';
      default:
        return 'Semua';
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'ALL':
        return Color(0xFF2196F3);
      case 'UNPAID':
        return Color(0xFFFF9800);
      case 'AWAITING_SHIPMENT':
        return Color(0xFF9C27B0);
      case 'IN_TRANSIT':
        return Color(0xFF2196F3);
      case 'DELIVERED':
        return Color(0xFF4CAF50);
      case 'CANCELLED':
        return Color(0xFFF44336);
      default:
        return Color(0xFF2196F3);
    }
  }

  int _getFilterCount(String filter) {
    switch (filter) {
      case 'ALL':
        return orders.length;
      case 'UNPAID':
        return orders.where((o) => o.statusCode == 'UNPAID').length;
      case 'AWAITING_SHIPMENT':
        return orders.where((o) => o.statusCode == 'AWAITING_SHIPMENT').length;
      case 'IN_TRANSIT':
        return orders.where((o) => o.statusCode == 'IN_TRANSIT').length;
      case 'DELIVERED':
        return orders.where((o) => o.statusCode == 'DELIVERED').length;
      case 'CANCELLED':
        return orders.where((o) => o.statusCode == 'CANCELLED').length;
      default:
        return orders.length;
    }
  }

  void _showFilterBottomSheet() {
    final filters = [
      {'label': 'Semua', 'value': 'ALL', 'icon': Icons.all_inclusive, 'color': Color(0xFF2196F3)},
      {'label': 'Belum Bayar', 'value': 'UNPAID', 'icon': Icons.payment, 'color': Color(0xFFFF9800)},
      {'label': 'Siap Kirim', 'value': 'AWAITING_SHIPMENT', 'icon': Icons.inventory_2, 'color': Color(0xFF9C27B0)},
      {'label': 'Dalam Pengiriman', 'value': 'IN_TRANSIT', 'icon': Icons.local_shipping, 'color': Color(0xFF2196F3)},
      {'label': 'Selesai', 'value': 'DELIVERED', 'icon': Icons.check_circle, 'color': Color(0xFF4CAF50)},
      {'label': 'Dibatalkan', 'value': 'CANCELLED', 'icon': Icons.cancel, 'color': Color(0xFFF44336)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF2196F3),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filter Status Pesanan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: Colors.grey[600]),
                    iconSize: 22,
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: Colors.grey[200]),
            SizedBox(height: 16),

            // Filter options
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final count = _getFilterCount(filter['value'] as String);
                final isSelected = _selectedFilter == filter['value'];
                final color = filter['color'] as Color;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? color
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                    title: Row(
                      children: [
                        Icon(
                          filter['icon'] as IconData,
                          size: 20,
                          color: isSelected ? color : Colors.grey[600],
                        ),
                        SizedBox(width: 12),
                        Text(
                          filter['label'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? color
                                : Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? color
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedFilter = filter['value'] as String;
                        _applyFilter();
                      });
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),

            SizedBox(height: 24 + MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Color(0xFF1A237E),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E), // Deep Blue
                Color(0xFF283593), // Medium Blue
                Color(0xFF3949AB), // Light Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF1A237E).withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).viewPadding.top,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Row(
          children: [
            // Back Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: 16),
            // Title & Shop Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pesanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.shopName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Refresh Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: _loadOrders,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    if (filteredOrders.isEmpty && _selectedFilter != 'ALL') {
      return _buildNoResultsState();
    }

    return _buildOrderList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2196F3).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: Color(0xFF2196F3),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Memuat pesanan...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gagal Memuat Pesanan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.refresh_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 64,
                  color: Color(0xFF2196F3).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Belum Ada Pesanan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pesanan akan muncul di sini\nketika pelanggan mulai memesan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getFilterColor(_selectedFilter).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.filter_list_off_rounded,
                size: 72,
                color: _getFilterColor(_selectedFilter),
              ),
            ),
            SizedBox(height: 28),
            Text(
              'Tidak Ada Pesanan ${_getFilterTitle(_selectedFilter)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Coba pilih filter lain atau\ntunggu pesanan baru',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _showFilterBottomSheet,
                  icon: Icon(Icons.tune_rounded, size: 20),
                  label: Text('Ubah Filter',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF2196F3),
                    side: BorderSide(color: Color(0xFF2196F3), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                if (_selectedFilter != 'ALL') ...[
                  SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilter = 'ALL';
                        _applyFilter();
                      });
                    },
                    child: Text('Lihat Semua',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildOrderList() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Filter and count header
          Container(
            margin: EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getFilterColor(_selectedFilter).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: _getFilterColor(_selectedFilter),
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${filteredOrders.length}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _getFilterColor(_selectedFilter),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            _getFilterTitle(_selectedFilter),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      if (_selectedFilter != 'ALL')
                        Text(
                          'dari ${orders.length} total pesanan',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showFilterBottomSheet,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Filter',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: RefreshIndicator(
              color: Color(0xFF2196F3),
              backgroundColor: Colors.white,
              strokeWidth: 2.5,
              onRefresh: _loadOrders,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
                physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(
                  orderId: order.orderId,
                  shopId: widget.shopId,
                  shopName: widget.shopName,
                  platform: widget.platform,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan status dan ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.receipt_rounded,
                              size: 18,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order ID',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '#${order.orderId.substring(0, 12)}...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A237E),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Color(order.statusColorInt).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(order.statusColorInt).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Color(order.statusColorInt),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            order.orderStatusName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(order.statusColorInt),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey[200],
                ),

                const SizedBox(height: 16),

                // Info pembeli dan items
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A237E).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pembeli',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            order.buyerName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.itemCount} Item Produk',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            order.itemsSummary,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Divider
                Container(
                  height: 1,
                  color: Colors.grey[200],
                ),

                const SizedBox(height: 16),

                // Footer dengan total dan waktu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.payments_outlined,
                              color: Color(0xFF4CAF50),
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Pembayaran',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  order.formattedAmount,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4CAF50),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            SizedBox(width: 4),
                            Text(
                              order.formattedCreateTime.split(' ')[0],
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          order.formattedCreateTime.split(' ').length > 1
                            ? order.formattedCreateTime.split(' ')[1]
                            : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
