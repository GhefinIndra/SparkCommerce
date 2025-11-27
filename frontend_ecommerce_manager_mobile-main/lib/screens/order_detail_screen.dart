import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/sku_sync_service.dart';
import '../models/order.dart';
import 'shipping_action_widget.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String shopName;
  final String platform; // TikTok or Shopee

  const OrderDetailScreen({
    Key? key,
    required this.orderId,
    required this.shopId,
    required this.shopName,
    required this.platform,
  }) : super(key: key);

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final SKUSyncService _syncService = SKUSyncService();
  Order? order; 
  bool _isLoading = true;
  String _errorMessage = '';
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  bool _hasReducedStock = false; // Track if stock already reduced

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadOrderDetail();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController!, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    _slideController?.dispose();
    super.dispose();
  }

  Future<void> _loadOrderDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      
      final orderResult = widget.platform.toUpperCase() == 'SHOPEE'
          ? await _apiService.getShopeeOrderDetail(widget.shopId, widget.orderId)
          : await _apiService.getOrderDetail(widget.shopId, widget.orderId);

      setState(() {
        order = orderResult;
        _isLoading = false;
      });

      _fadeController?.forward();
      _slideController?.forward();

      if (order != null && !_hasReducedStock) {
        await _reduceStockFromOrder(order!, widget.platform.toUpperCase());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Auto-reduce stock dari SKU Master berdasarkan order items
  Future<void> _reduceStockFromOrder(Order order, String provider) async {
    try {
      // Only reduce stock for certain statuses (platform agnostic)
      final reduceableStatuses = [
        'AWAITING_SHIPMENT',
        'READY_TO_SHIP',
        'PARTIALLY_SHIPPING',
        'AWAITING_COLLECTION',
        'IN_TRANSIT',
        'SHIPPED',
        'DELIVERED',
        'COMPLETED'
      ];

      if (!reduceableStatuses.contains(order.statusCode)) {
        return;
      }


      int reducedCount = 0;
      int skippedCount = 0;

      for (var item in order.items) {
        // For Shopee, try seller_sku first
        if (provider == 'SHOPEE' && item.sellerSku.isNotEmpty) {
          try {
            await _syncService.reduceStockFromOrder(
              sku: item.sellerSku,
              quantity: item.quantity,
              marketplace: provider,
            );
            reducedCount++;
            continue;
          } catch (e) {
            skippedCount++;
            continue;
          }
        }

        // For TikTok or fallback
        if (item.sellerSku.isEmpty) {
          skippedCount++;
          continue;
        }

        try {
          await _syncService.reduceStockFromOrder(
            sku: item.sellerSku,
            quantity: item.quantity,
            marketplace: provider,
          );
          reducedCount++;
        } catch (e) {
          skippedCount++;
        }
      }

      if (reducedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(' Stock berhasil dikurangi untuk $reducedCount item'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      if (skippedCount > 0) {
      }

      setState(() {
        _hasReducedStock = true;
      });
    } catch (e) {
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
                    'Detail Pesanan',
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
                onPressed: _loadOrderDetail,
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

    if (order == null) {
      return _buildNotFoundState();
    }

    return RefreshIndicator(
      color: Color(0xFF2196F3),
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      onRefresh: _loadOrderDetail,
      child: _fadeAnimation != null && _slideAnimation != null
          ? FadeTransition(
              opacity: _fadeAnimation!,
              child: SlideTransition(
                position: _slideAnimation!,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderStatusCard(),
                      const SizedBox(height: 20),
                      _buildOrderInfoCard(),
                      const SizedBox(height: 20),
                      _buildBuyerInfoCard(),
                      const SizedBox(height: 20),
                      _buildShippingInfoCard(),
                      const SizedBox(height: 20),
                      _buildOrderItemsCard(),
                      const SizedBox(height: 20),
                      _buildPaymentInfoCard(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderStatusCard(),
                  const SizedBox(height: 20),
                  _buildOrderInfoCard(),
                  const SizedBox(height: 20),
                  _buildBuyerInfoCard(),
                  const SizedBox(height: 20),
                  _buildShippingInfoCard(),
                  const SizedBox(height: 20),
                  _buildOrderItemsCard(),
                  const SizedBox(height: 20),
                  _buildPaymentInfoCard(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
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
            'Memuat detail pesanan...',
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
              'Gagal Memuat Detail',
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
                onPressed: _loadOrderDetail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

  Widget _buildNotFoundState() {
    return Center(
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.orange[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Pesanan Tidak Ditemukan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Data pesanan tidak dapat ditemukan\natau mungkin sudah dihapus',
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
    );
  }

  Widget _buildOrderStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(order!.statusColorInt),
                  Color(order!.statusColorInt).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Color(order!.statusColorInt).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              order!.orderStatusName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded,
                    size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order ID: ${order!.orderId}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order!.orderId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order ID berhasil disalin'),
                          backgroundColor: Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.copy_rounded,
                          size: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return _buildInfoCard(
      title: 'Informasi Pesanan',
      icon: Icons.info_outline_rounded,
      iconColor: Colors.blue,
      children: [
        _buildInfoRow('Tanggal Pesanan', order!.formattedCreateTime,
            Icons.schedule_rounded),
        _buildInfoRow('Terakhir Update', order!.formattedUpdateTime,
            Icons.update_rounded),
        _buildInfoRow('Tipe Pengiriman', order!.fulfillmentType,
            Icons.local_shipping_rounded),
        _buildInfoRow(
            'Metode Pembayaran', order!.paymentMethod, Icons.payment_rounded),
        if (order!.buyerMessage.isNotEmpty)
          _buildInfoRow(
              'Pesan Pembeli', order!.buyerMessage, Icons.message_rounded),
        if (order!.sellerNote.isNotEmpty)
          _buildInfoRow(
              'Catatan Penjual', order!.sellerNote, Icons.note_rounded),
      ],
    );
  }

  Widget _buildBuyerInfoCard() {
    return _buildInfoCard(
      title: 'Informasi Pembeli',
      icon: Icons.person_outline_rounded,
      iconColor: Colors.purple,
      children: [
        _buildInfoRow('Nama', order!.buyerName, Icons.account_circle_rounded),
        _buildInfoRow('Telepon', order!.buyerPhone, Icons.phone_rounded,
            copyable: true),
        _buildInfoRow(
            'Alamat', order!.customerAddress, Icons.location_on_rounded),
      ],
    );
  }

  Widget _buildShippingInfoCard() {
    return _buildInfoCard(
      title: 'Informasi Pengiriman',
      icon: Icons.local_shipping_rounded,
      iconColor: Colors.orange,
      children: [
        _buildInfoRow(
            'Kurir', order!.shippingProvider, Icons.delivery_dining_rounded),
        _buildInfoRow('Tipe Layanan', order!.deliveryType, Icons.speed_rounded),
        if (order!.trackingNumber.isNotEmpty)
          _buildInfoRow(
              'No. Resi', order!.trackingNumber, Icons.qr_code_rounded,
              copyable: true),
      ],
    );
  }

  Widget _buildOrderItemsCard() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF2196F3).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shopping_bag_rounded,
                      color: Color(0xFF2196F3), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Produk Pesanan (${order!.itemCount})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          
          ...order!.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildOrderItem(item, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item, int index) {
    return Container(
      margin: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: index == order!.items.length - 1 ? 20 : 0,
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: index < order!.items.length - 1
            ? Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: item.skuImage.isNotEmpty
                  ? Image.network(
                      item.skuImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.grey[400],
                          size: 32),
                    )
                  : Icon(Icons.image_rounded,
                      color: Colors.grey[400], size: 32),
            ),
          ),
          const SizedBox(width: 16),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.sellerSku.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SKU: ${item.sellerSku}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Price and Quantity Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Harga Satuan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            item.formattedPrice,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kuantitas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _formatItemTotal(item.price, item.quantity),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (item.itemStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Status: ${item.itemStatus}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Rincian Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildPriceRow('Subtotal', order!.subTotal),
                const SizedBox(height: 8),
                _buildPriceRow('Ongkos Kirim', order!.shippingFee),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF4CAF50).withOpacity(0.1),
                        Color(0xFF4CAF50).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF4CAF50).withOpacity(0.2),
                    ),
                  ),
                  child: _buildPriceRow('Total', order!.totalAmount,
                      isTotal: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData rowIcon,
      {bool copyable = false, bool isLink = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(rowIcon, size: 16, color: Colors.grey[600]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'N/A' : value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isLink ? Colors.blue[600] : Colors.grey[800],
                    fontWeight: FontWeight.w600,
                    decoration: isLink ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
          if (copyable && value.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label berhasil disalin'),
                      backgroundColor: Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.copy_rounded,
                      size: 14, color: Colors.grey[500]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? Colors.grey[800] : Colors.grey[600],
          ),
        ),
        Text(
          _formatPrice(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? Color(0xFF4CAF50) : Colors.grey[800],
            letterSpacing: isTotal ? -0.5 : 0,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        
        ShippingActionWidget(
          order: order!,
          shopId: widget.shopId,
          shopName: widget.shopName,
          onShippingSuccess: () {
            // Refresh order detail after successful shipping
            _loadOrderDetail();
          },
        ),

        // Keep other action buttons if needed
        const SizedBox(height: 20),
        _buildOtherActions(),
      ],
    );
  }

  Widget _buildOtherActions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.more_horiz, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Aksi Lainnya',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Order Status Update Button (for non-shipping status updates)
          if (!order!.canShip) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _showComingSoonDialog('Update Status Order');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.update, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Update Status',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Cancel Order Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: order!.canCancel
                  ? () {
                      _showComingSoonDialog('Batalkan Pesanan');
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: order!.canCancel ? Colors.red : Colors.grey,
                side: BorderSide(
                  color: order!.canCancel ? Colors.red : Colors.grey[300]!,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cancel_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Batalkan Pesanan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          if (!order!.canCancel) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesanan tidak dapat dibatalkan pada status ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Fitur $feature akan segera tersedia!\nTerima kasih atas kesabarannya.',
          style: TextStyle(
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00AA5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatPrice(String? amount) {
    if (amount == null || amount.isEmpty || amount == '0') return 'Rp 0';

    try {
      final price = double.parse(amount);
      return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $amount';
    }
  }

  String _formatItemTotal(String price, int quantity) {
    try {
      final itemPrice = double.parse(price);
      final total = itemPrice * quantity;
      return 'Rp ${total.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $price';
    }
  }
}
