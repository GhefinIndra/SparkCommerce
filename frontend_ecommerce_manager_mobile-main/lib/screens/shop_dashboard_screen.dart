// lib/screens/shop_dashboard_screen.dart - REDESIGNED WITH HOME SCREEN THEME
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/shop.dart';
import '../services/api_service.dart';
import '../services/customer_service_api.dart';
import '../services/oauth_event_service.dart';
import 'platform_selection_screen.dart';
import 'manage_products_screen.dart';
import 'view_order_screen.dart';
import 'available_shops_screen.dart';

class ShopDashboardScreen extends StatefulWidget {
  @override
  _ShopDashboardScreenState createState() => _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends State<ShopDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<Shop> shops = [];
  Map<String, int> productCounts = {};
  Map<String, int> orderCounts = {};
  Map<String, int> chatCounts = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String? _deletingShopId;
  StreamSubscription<OAuthEvent>? _oauthEventSubscription;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _listenToOAuthEvents();
  }

  @override
  void dispose() {
    _oauthEventSubscription?.cancel();
    super.dispose();
  }

  void _listenToOAuthEvents() {
    _oauthEventSubscription = OAuthEventService().eventStream.listen((event) {
      print('🎧 ShopDashboard: Received OAuth event');
      print('   Success: ${event.success}');
      print('   Platform: ${event.platform}');
      print('   Seller: ${event.seller}');
      
      if (event.success) {
        // Auto refresh shop list
        print('   ♻️ Auto-refreshing shop list...');
        _loadShops();
        
        // Show success dialog
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _showSuccessDialog(
              platform: event.platform,
              seller: event.seller,
              openId: event.openId,
            );
          }
        });
      } else {
        // Show error snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.errorMessage ?? 'OAuth gagal',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.all(16),
            ),
          );
        }
      }
    });
  }

  void _showSuccessDialog({
    required String platform,
    required String seller,
    required String openId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success animation icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 64,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Berhasil Terhubung!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Toko $platform Anda berhasil ditambahkan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    seller,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2196F3),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'OK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadShops() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final loadedShops = await _apiService.getShops();
      await _loadShopStats(loadedShops);

      setState(() {
        shops = loadedShops;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadShopStats(List<Shop> shops) async {
    for (Shop shop in shops) {
      try {

        // Call appropriate API based on platform
        final productResponse = shop.platform.toLowerCase().contains('shopee')
            ? await _apiService.getShopeeProducts(shop.id)
            : await _apiService.getProducts(shop.id);

        List<dynamic> productsData = [];

        if (productResponse is Map<String, dynamic>) {
          if (productResponse.containsKey('products')) {
            final products = productResponse['products'];
            if (products is List) {
              productsData = products;
            }
          }
        }


        int activeProductsCount = 0;
        for (var product in productsData) {
          if (product is Map<String, dynamic>) {
            bool isActive = false;

            if (product.containsKey('status')) {
              final status = product['status'].toString().toUpperCase();

              // Platform-specific status checking
              if (shop.platform.toLowerCase().contains('shopee')) {
                // Shopee status: NORMAL is active
                isActive = status == 'NORMAL';
              } else {
                // TikTok status: ACTIVATE or ACTIVE
                isActive = status == 'ACTIVATE' || status == 'ACTIVE';
              }
            } else {
              isActive = true;
            }

            if (isActive) {
              activeProductsCount++;
            }
          }
        }

        productCounts[shop.id] = activeProductsCount;

        // Load order count based on platform
        try {
          final ordersResponse = shop.platform.toLowerCase().contains('shopee')
              ? await _apiService.getShopeeOrders(shop.id)
              : await _apiService.getOrders(shop.id);
          orderCounts[shop.id] = ordersResponse.length;
        } catch (e) {
          orderCounts[shop.id] = 0;
        }

        try {
          final chatResponse = await _loadChatCount(shop.id);
          chatCounts[shop.id] = chatResponse;
        } catch (e) {
          chatCounts[shop.id] = 0;
        }
      } catch (e) {
        productCounts[shop.id] = 0;
        orderCounts[shop.id] = 0;
        chatCounts[shop.id] = 0;
      }
    }
  }

  Future<int> _loadChatCount(String shopId) async {
    try {
      final result = await CustomerServiceApiService.getConversations(shopId);

      if (result['success']) {
        final conversations = result['conversations'] as List?;
        if (conversations != null) {
          int unreadCount = 0;
          for (var conv in conversations) {
            if (conv.unreadCount > 0) {
              unreadCount++;
            }
          }
          return unreadCount;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _openClaimShops() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableShopsScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadShops();
    }
  }

  Future<void> _addNewShop() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlatformSelectionScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadShops();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[400] : Colors.green[600],
      ),
    );
  }

  Future<void> _confirmDeleteShop(Shop shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red[400],
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Hapus Toko',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toko ini akan dihapus dari aplikasi dan database. Akses OAuth akan dicabut.',
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name.isNotEmpty ? shop.name : shop.sellerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red[700],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ID: ${shop.id}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      shop.platform,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[500],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Hapus',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingShopId = shop.id;
    });

    try {
      final success =
          await _apiService.deleteShop(shop.id, platform: shop.platform);

      if (success) {
        _showMessage('Toko berhasil dihapus');
        await _loadShops();
      } else {
        _showMessage('Gagal menghapus toko', isError: true);
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingShopId = null;
        });
      }
    }
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
        backgroundColor: Color(0xFF1A237E), // Deep Blue base
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
              // Premium Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).viewPadding.top,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Row(
                    children: [
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
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Toko Saya',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              '${shops.length} toko terhubung',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.add_rounded,
                            color: Color(0xFF1A237E),
                            size: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          offset: Offset(0, 10),
                          elevation: 8,
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'oauth',
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2196F3).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.link_rounded,
                                      size: 20,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'OAuth Toko',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Link via OAuth normal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'claim',
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.store_outlined,
                                      size: 20,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Klaim Toko',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Untuk testing sandbox',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (String choice) {
                            if (choice == 'oauth') {
                              _addNewShop();
                            } else if (choice == 'claim') {
                              _openClaimShops();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content with Curved Divider
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

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Memuat toko...',
              style: TextStyle(
                color: Color(0xFF1A237E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.all(24),
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: Colors.red[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Gagal Memuat Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _loadShops,
                icon: Icon(Icons.refresh_rounded, size: 22),
                label: Text(
                  'Coba Lagi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (shops.isEmpty) {
      return _buildEmptyState();
    }

    return _buildShopList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1A237E).withOpacity(0.1),
                    Color(0xFF3949AB).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.store_outlined,
                size: 72,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 28),
            Text(
              'Belum Ada Toko',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tambahkan toko pertama Anda\nuntuk mulai mengelola bisnis online',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addNewShop,
              icon: Icon(Icons.add_rounded, size: 22),
              label: Text(
                'Tambah Toko',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopList() {
    return RefreshIndicator(
      color: Color(0xFF2196F3),
      onRefresh: _loadShops,
      child: ListView.builder(
        padding: EdgeInsets.all(24),
        physics: BouncingScrollPhysics(),
        itemCount: shops.length,
        itemBuilder: (context, index) {
          final shop = shops[index];
          return _buildShopCard(shop);
        },
      ),
    );
  }

  Widget _buildShopCard(Shop shop) {
    final productCount = productCounts[shop.id] ?? 0;
    final orderCount = orderCounts[shop.id] ?? 0;
    final chatCount = chatCounts[shop.id] ?? 0;
    final isDeleting = _deletingShopId == shop.id;

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Gradient
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1A237E).withOpacity(0.05),
                  Color(0xFF3949AB).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A237E),
                        Color(0xFF3949AB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF1A237E).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name.isNotEmpty ? shop.name : shop.sellerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Shop ID Display - Clean and simple
                      Text(
                        shop.id,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Platform and Region badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2196F3),
                                  Color(0xFF42A5F5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  shop.platform,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (shop.region.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                shop.region,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                isDeleting
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.red[400]!,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red[400],
                        ),
                        tooltip: 'Hapus toko dari daftar',
                        onPressed: () => _confirmDeleteShop(shop),
                      ),
              ],
            ),
          ),

          // Stats & Actions
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Last Sync Info - Simple and clean
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Sync: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        shop.lastSync.isNotEmpty ? shop.lastSync : "Baru saja",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        'Produk',
                        productCount.toString(),
                        Icons.inventory_rounded,
                        Color(0xFF2196F3),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        'Pesanan',
                        orderCount.toString(),
                        Icons.receipt_long_rounded,
                        Color(0xFF00BCD4),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatBox(
                        'Chat',
                        chatCount.toString(),
                        Icons.chat_rounded,
                        chatCount > 0 ? Colors.orange[700]! : Color(0xFF9C27B0),
                        showBadge: chatCount > 0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Action Buttons
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            label: 'Kelola Produk',
                            icon: Icons.inventory_rounded,
                            gradient: [Color(0xFF1A237E), Color(0xFF3949AB)],
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ManageProductsScreen(
                                    shopId: shop.id,
                                    shopName: shop.name.isNotEmpty
                                        ? shop.name
                                        : shop.sellerName,
                                    platform: shop.platform, // Pass platform for API detection
                                  ),
                                ),
                              );
                              if (result == true) await _loadShops();
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            label: 'Lihat Pesanan',
                            icon: Icons.receipt_long_rounded,
                            gradient: [Color(0xFF2196F3), Color(0xFF42A5F5)],
                            onTap: () async {
                              // Navigate to different order screen based on platform
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewOrdersScreen(
                                    shopId: shop.id,
                                    shopName: shop.name.isNotEmpty
                                        ? shop.name
                                        : shop.sellerName,
                                    platform: shop.platform, // Pass platform for multi-platform support
                                  ),
                                ),
                              );
                              if (result == true) await _loadShops();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      label: 'Lihat Pesan',
                      icon: Icons.chat_rounded,
                      gradient: chatCount > 0
                          ? [Colors.orange[700]!, Colors.orange[500]!]
                          : [Color(0xFF9C27B0), Color(0xFFAB47BC)],
                      badgeCount: chatCount,
                      onTap: () async {
                        // Chat feature coming soon for all platforms
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFF9C27B0),
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Fitur chat masih dalam pengembangan dan akan segera hadir!',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: Colors.grey[700],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool showBadge = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              if (showBadge)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            color: gradient[0].withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: gradient[0].withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: gradient[0],
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gradient[0],
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
