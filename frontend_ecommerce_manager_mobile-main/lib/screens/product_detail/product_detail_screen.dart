// lib/screens/product_detail/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'widgets/product_image_carousel.dart';
import 'widgets/product_sku_section.dart';
import 'widgets/product_action_buttons.dart';
import 'widgets/edit_dialogs/edit_info_dialog.dart';
import 'widgets/edit_dialogs/edit_price_dialog.dart';
import 'widgets/edit_dialogs/edit_stock_dialog.dart';
import 'widgets/edit_dialogs/edit_image_dialog.dart';
import 'models/product_detail_model.dart';

class ProductDetailScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String productId;
  final String productTitle;
  final String platform; // Platform identifier (TikTok Shop, Shopee, etc)

  const ProductDetailScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.productId,
    required this.productTitle,
    this.platform = 'TikTok Shop', // Default for backward compatibility
  }) : super(key: key);

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();

  ProductDetailModel? productDetail;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProductDetail();
  }

  // Safe setState yang check mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> _loadProductDetail() async {
    try {
      _safeSetState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Platform detection: call appropriate API based on shop platform
      final detail = widget.platform.toLowerCase().contains('shopee')
          ? await _apiService.getShopeeProductDetail(widget.shopId, widget.productId)
          : await _apiService.getProductDetail(widget.shopId, widget.productId);

      _safeSetState(() {
        productDetail = ProductDetailModel.fromJson(detail);
        _isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
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
            // Back Button - matching Dashboard style
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

            // Title and Shop Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Produk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.store_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 13,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.shopName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Button - matching Dashboard style
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
                  Icons.more_vert_rounded,
                  color: Color(0xFF1A237E),
                  size: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                offset: Offset(0, 10),
                elevation: 8,
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit_info',
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2196F3)),
                        ),
                        SizedBox(width: 12),
                        Text('Edit Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit_price',
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF2196F3).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF2196F3)),
                        ),
                        SizedBox(width: 12),
                        Text('Edit Harga', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit_stock',
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.inventory_rounded, size: 18, color: Colors.orange[700]),
                        ),
                        SizedBox(width: 12),
                        Text('Edit Stok', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit_image',
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF9C27B0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.image_rounded, size: 18, color: Color(0xFF9C27B0)),
                        ),
                        SizedBox(width: 12),
                        Text('Edit Gambar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                        ),
                        SizedBox(width: 12),
                        Text('Hapus Produk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              'Memuat detail produk...',
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
                'Gagal Memuat Detail',
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
                onPressed: _loadProductDetail,
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

    if (productDetail == null) {
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
                  Icons.search_off_rounded,
                  size: 72,
                  color: Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 28),
              Text(
                'Produk Tidak Ditemukan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Produk yang Anda cari tidak ditemukan\natau telah dihapus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  height: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildProductDetail();
  }

  Widget _buildProductDetail() {
    final detail = productDetail!;

    return RefreshIndicator(
      color: Color(0xFF2196F3),
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      onRefresh: _loadProductDetail,
      child: Column(
        children: [
          // Progress Indicator Bar
          _buildProgressBar(detail),

          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Images Carousel
                  if (detail.images.isNotEmpty)
                    ProductImageCarousel(
                      images: detail.images,
                      onEditPressed: () => _handleMenuAction('edit_image'),
                    ),

                  SizedBox(height: 20),

                  // Simplified Product Info Card
                  _buildSimpleProductInfo(detail),

                  SizedBox(height: 16),

                  // Stat Cards Row (Varian, Total Stok, COD)
                  _buildStatCardsRow(detail),

                  SizedBox(height: 20),

                  // SKUs Section
                  if (detail.skus.isNotEmpty) ProductSkuSection(skus: detail.skus),

                  SizedBox(height: 20),

                  // Tabs Section
                  _buildTabsSection(detail),

                  SizedBox(height: 24),

                  // Action Buttons
                  ProductActionButtons(
                    onEditInfo: () => _handleMenuAction('edit_info'),
                    onEditPrice: () => _handleMenuAction('edit_price'),
                    onEditStock: () => _handleMenuAction('edit_stock'),
                    onEditImage: () => _handleMenuAction('edit_image'),
                    onDelete: () => _handleMenuAction('delete'),
                    onUnlist: widget.platform.toLowerCase().contains('shopee')
                        ? () => _handleMenuAction('unlist')
                        : null,
                    platform: widget.platform,
                    isUnlisted: detail.status == 'UNLISTED' || detail.status == 'INACTIVE',
                  ),

                  SizedBox(height: 32), // Extra space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ProductDetailModel product) {
    // Calculate completion percentage based on filled data
    int totalFields = 6;
    int filledFields = 0;

    if (product.title.isNotEmpty) filledFields++;
    if (product.description.isNotEmpty) filledFields++;
    if (product.images.isNotEmpty) filledFields++;
    if (product.skus.isNotEmpty) filledFields++;
    if (product.categoryChains.isNotEmpty) filledFields++;
    if (product.brand != null) filledFields++;

    double percentage = (filledFields / totalFields).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * percentage;

        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF3949AB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSimpleProductInfo(ProductDetailModel product) {
    return Container(
      width: double.infinity,
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
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Title
          Text(
            product.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
              height: 1.3,
            ),
          ),

          SizedBox(height: 16),

          // Price and Stock Row
          Row(
            children: [
              // Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 16, color: Color(0xFF4CAF50)),
                        SizedBox(width: 4),
                        Text(
                          'Harga',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      product.priceRange,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),

              // Stock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF2196F3)),
                        SizedBox(width: 4),
                        Text(
                          'Total Stok',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${product.totalStock} pcs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Status
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              SizedBox(width: 4),
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: product.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: product.statusColor.withOpacity(0.3),
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
                        color: product.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      product.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: product.statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Description
          if (product.description.isNotEmpty) ...[
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Text(
                        'Deskripsi Produk',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    product.description.replaceAll(RegExp(r'<[^>]*>'), ''), // Remove HTML tags for simple display
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCardsRow(ProductDetailModel product) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCardNew(
            icon: Icons.apps_rounded,
            iconColor: Color(0xFF3F51B5),
            backgroundColor: Color(0xFFE8EAF6),
            value: '${product.skus.length}',
            label: 'Varian',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCardNew(
            icon: Icons.inventory_2_rounded,
            iconColor: Color(0xFF00BCD4),
            backgroundColor: Color(0xFFE0F7FA),
            value: '${product.totalStock}',
            label: 'Total Stok',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCardNew(
            icon: Icons.check_circle_rounded,
            iconColor: Color(0xFF4CAF50),
            backgroundColor: Color(0xFFE8F5E9),
            value: 'Ya',
            label: 'COD',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCardNew({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.grey[900],
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection(ProductDetailModel product) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
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
            child: Column(
              children: [
                TabBar(
                  labelColor: Color(0xFF2196F3),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Color(0xFF2196F3),
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Spesifikasi'),
                    Tab(text: 'Paket'),
                    Tab(text: 'Sistem'),
                  ],
                ),
                Container(
                  height: 300,
                  padding: EdgeInsets.all(20),
                  child: TabBarView(
                    children: [
                      // Spesifikasi Tab
                      _buildSpecificationTab(product),
                      // Paket Tab
                      _buildPackageTab(product),
                      // Sistem Tab
                      _buildSystemTab(product),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationTab(ProductDetailModel product) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info
          _buildSpecRow('Product ID', product.id),
          _buildSpecRow('Kategori', product.categoryName),
          _buildSpecRow('Brand', product.brandName),
          _buildSpecRow('Total Varian', '${product.skus.length} SKU'),

          // Package Info
          if (product.packageWeight != null)
            _buildSpecRow('Berat', product.packageWeight!.display),
          if (product.packageDimensions != null)
            _buildSpecRow('Dimensi', product.packageDimensions!.display),

          // Product Condition
          if (product.isPreOwned != null)
            _buildSpecRow('Kondisi', product.isPreOwned! ? 'Bekas' : 'Baru'),

          // Min Order
          if (product.minimumOrderQuantity != null && product.minimumOrderQuantity! > 1)
            _buildSpecRow('Min. Order', '${product.minimumOrderQuantity} unit'),

          SizedBox(height: 8),

          // COD Status
          _buildCODRow(product.isCodAllowed),

          // Product Attributes Section (Sertifikasi, dll)
          if (product.productAttributes != null && product.productAttributes!.isNotEmpty) ...[
            SizedBox(height: 16),
            _buildAttributesSection(product.productAttributes!),
          ],

          // Additional Info
          if (product.externalProductId != null) ...[
            SizedBox(height: 16),
            _buildSpecRow('External ID', product.externalProductId!),
          ],
          if (product.productTypes.isNotEmpty)
            _buildSpecRow('Tipe Produk', product.productTypes.join(', ')),
          if (product.shippingInsuranceRequirement != null)
            _buildSpecRow('Asuransi Pengiriman', _getInsuranceLabel(product.shippingInsuranceRequirement!)),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCODRow(bool isCodAllowed) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'COD',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCodAllowed ? Color(0xFF26C6DA) : Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: (isCodAllowed ? Color(0xFF26C6DA) : Colors.grey[400]!).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCodAllowed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  isCodAllowed ? 'Tersedia' : 'Tidak Tersedia',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Package Tab
  Widget _buildPackageTab(ProductDetailModel product) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Berat
          if (product.packageWeight != null) ...[
            _buildSpecRow('Berat', '${product.packageWeight!.value} ${product.packageWeight!.unit.toLowerCase()}'),
            SizedBox(height: 8),
          ],

          // Dimensi Paket
          if (product.packageDimensions != null) ...[
            _buildSpecRow('Panjang', '${product.packageDimensions!.length} ${product.packageDimensions!.unit.toLowerCase()}'),
            _buildSpecRow('Lebar', '${product.packageDimensions!.width} ${product.packageDimensions!.unit.toLowerCase()}'),
            _buildSpecRow('Tinggi', '${product.packageDimensions!.height} ${product.packageDimensions!.unit.toLowerCase()}'),
            SizedBox(height: 8),

            // Hitung Volume
            _buildSpecRow(
              'Volume',
              _calculateVolume(
                product.packageDimensions!.length,
                product.packageDimensions!.width,
                product.packageDimensions!.height,
                product.packageDimensions!.unit,
              ),
            ),
          ],

          // Jika tidak ada data paket
          if (product.packageWeight == null && product.packageDimensions == null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Informasi paket tidak tersedia',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
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

  // Build System Tab
  Widget _buildSystemTab(ProductDetailModel product) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamps
          _buildSpecRow(
            'Dibuat',
            product.createTime != null
                ? _formatTimestamp(product.createTime!)
                : '-',
          ),
          _buildSpecRow(
            'Diperbarui',
            product.updateTime != null
                ? _formatTimestamp(product.updateTime!)
                : '-',
          ),

          SizedBox(height: 16),

          // Sync Status Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6B46C1).withOpacity(0.1),
                  Color(0xFF9333EA).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF9333EA).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF9333EA),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Data disinkronkan dengan TikTok Shop',
                    style: TextStyle(
                      color: Color(0xFF6B46C1),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  // Helper: Calculate Volume
  String _calculateVolume(String length, String width, String height, String unit) {
    try {
      final l = double.parse(length);
      final w = double.parse(width);
      final h = double.parse(height);
      final volume = l * w * h;

      // Convert to appropriate unit
      if (unit.toUpperCase() == 'CENTIMETER') {
        return '${volume.toStringAsFixed(0)} cm³';
      } else if (unit.toUpperCase() == 'METER') {
        return '${volume.toStringAsFixed(2)} m³';
      }
      return '${volume.toStringAsFixed(0)} ${unit.toLowerCase()}³';
    } catch (e) {
      return '-';
    }
  }

  // Helper: Format Unix Timestamp
  String _formatTimestamp(int unixTimestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);

      // Format: DD/MM/YYYY HH:MM
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return '-';
    }
  }

  // Build Attributes Section (Sertifikasi, Nomor Registrasi, dll)
  Widget _buildAttributesSection(List<ProductAttribute> attributes) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B82F6).withOpacity(0.05),
            Color(0xFF2563EB).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xFF3B82F6).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Informasi Tambahan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...attributes.map((attr) {
            final valueText = attr.values
                .map((v) => v.name)
                .where((name) => name.isNotEmpty)
                .join(', ');

            if (valueText.isEmpty) return SizedBox.shrink();

            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      attr.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Text(
                    ': ',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Expanded(
                    child: Text(
                      valueText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Helper: Get Insurance Label
  String _getInsuranceLabel(String requirement) {
    switch (requirement.toUpperCase()) {
      case 'REQUIRED':
        return 'Wajib';
      case 'OPTIONAL':
        return 'Opsional';
      case 'NOT_SUPPORTED':
        return 'Tidak Didukung';
      default:
        return requirement;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit_info':
        _showEditInfoDialog();
        break;
      case 'edit_price':
        _showEditPriceDialog();
        break;
      case 'edit_stock':
        _showEditStockDialog();
        break;
      case 'edit_image':
        _showEditImageDialog();
        break;
      case 'delete':
        _showDeleteConfirmDialog();
        break;
      case 'unlist':
        _showUnlistConfirmDialog();
        break;
    }
  }

  void _showEditInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => EditInfoDialog(
        product: productDetail!,
        onSave: (title, description) async {
          try {
            // Platform detection: call appropriate API
            final success = widget.platform.toLowerCase().contains('shopee')
                ? await _apiService.updateShopeeProductInfo(
                    widget.shopId,
                    widget.productId,
                    title: title,
                    description: description,
                  )
                : await _apiService.updateProductInfo(
                    widget.shopId,
                    widget.productId,
                    title: title,
                    description: description,
                  );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Info produk berhasil diupdate'),
                  backgroundColor: Colors.green,
                ),
              );
              await _loadProductDetail();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal update info: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditPriceDialog() {
    showDialog(
      context: context,
      builder: (context) => EditPriceDialog(
        skus: productDetail!.skus,
        onSave: (updatedSkus) async {
          try {
            final formattedSkus = updatedSkus
                .map((sku) => {
                      'id': sku.id,
                      'price': {
                        'amount': sku.price.amount,
                        'currency': sku.price.currency,
                      },
                      'warehouse_id': sku.warehouseId,
                    })
                .toList();

            // Platform detection: call appropriate API
            final success = widget.platform.toLowerCase().contains('shopee')
                ? await _apiService.updateShopeeProductPrice(
                    widget.shopId,
                    widget.productId,
                    formattedSkus,
                  )
                : await _apiService.updateProductPrice(
                    widget.shopId,
                    widget.productId,
                    formattedSkus,
                  );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Harga produk berhasil diupdate'),
                  backgroundColor: Colors.green,
                ),
              );
              await _loadProductDetail();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal update harga: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditStockDialog() {
    showDialog(
      context: context,
      builder: (context) => EditStockDialog(
        skus: productDetail!.skus,
        onSave: (updatedSkus) async {
          try {
            final formattedSkus = updatedSkus
                .map((sku) {
                  

                  return {
                    'id': sku.id,
                    'warehouse_id': sku.warehouseId,
                    'available_stock': sku.stock,
                    'quantity': sku.stock,
                  };
                })
                .toList();


            // Platform detection: call appropriate API
            final success = widget.platform.toLowerCase().contains('shopee')
                ? await _apiService.updateShopeeProductStock(
                    widget.shopId,
                    widget.productId,
                    formattedSkus,
                  )
                : await _apiService.updateProductStock(
                    widget.shopId,
                    widget.productId,
                    formattedSkus,
                  );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Stok produk berhasil diupdate'),
                  backgroundColor: Colors.green,
                ),
              );
              await _loadProductDetail();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal update stok: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditImageDialog() {
    showDialog(
      context: context,
      builder: (context) => EditImageDialog(
        shopId: widget.shopId,
        productId: widget.productId,
        apiService: _apiService,
        platform: widget.platform, // Pass platform for detection
        onSave: () async {
          await _loadProductDetail();
        },
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Hapus Produk'),
          ],
        ),
        content: Text(
            'Apakah Anda yakin ingin menghapus produk ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteProduct();
            },
            child: Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct() async {
    if (!mounted) return;

    try {
      // Platform detection: call appropriate API
      final success = widget.platform.toLowerCase().contains('shopee')
          ? await _apiService.deleteShopeeProduct(
              widget.shopId,
              widget.productId,
            )
          : await _apiService.deleteProduct(
              widget.shopId,
              widget.productId,
            );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal hapus produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUnlistConfirmDialog() {
    final isCurrentlyUnlisted = productDetail?.status == 'UNLISTED' ||
        productDetail?.status == 'INACTIVE';
    final actionText = isCurrentlyUnlisted ? 'Aktifkan' : 'Nonaktifkan';
    final actionDescription = isCurrentlyUnlisted
        ? 'mengaktifkan kembali produk ini sehingga akan tampil di marketplace'
        : 'menonaktifkan produk ini sehingga tidak akan tampil di marketplace';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              isCurrentlyUnlisted ? Icons.visibility : Icons.visibility_off,
              color: Colors.orange,
              size: 24,
            ),
            SizedBox(width: 8),
            Text('$actionText Produk'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin $actionDescription?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _unlistProduct(!isCurrentlyUnlisted);
            },
            child: Text(actionText),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unlistProduct(bool unlist) async {
    if (!mounted) return;

    try {
      final success = await _apiService.unlistShopeeProduct(
        widget.shopId,
        widget.productId,
        unlist: unlist,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              unlist
                  ? 'Produk berhasil dinonaktifkan'
                  : 'Produk berhasil diaktifkan',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Reload product detail to update status
        await _loadProductDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
