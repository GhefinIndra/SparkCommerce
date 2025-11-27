// lib/screens/manage_products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail/product_detail_screen.dart';
import 'create_product/create_product_screen.dart';

enum ProductStatusFilter { all, active, inactive, deleted, draft }

class ManageProductsScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String platform; // Add platform parameter

  const ManageProductsScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    this.platform = 'TikTok Shop', // Default to TikTok for backward compatibility
  }) : super(key: key);

  @override
  _ManageProductsScreenState createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final ApiService _apiService = ApiService();
  List<Product> products = [];
  List<Product> filteredProducts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  ProductStatusFilter _currentFilter = ProductStatusFilter.active; // Default to Active filter

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Platform detection: call appropriate API
      Map<String, dynamic> response;

      if (widget.platform.toLowerCase().contains('shopee')) {
        // Shopee uses offset-based pagination
        // Query multiple statuses: NORMAL, UNLIST, SELLER_DELETE to show all products including deleted
        response = await _apiService.getShopeeProducts(
          widget.shopId,
          itemStatus: 'NORMAL,UNLIST,SELLER_DELETE',
        );
      } else {
        // TikTok (default)
        response = await _apiService.getProducts(widget.shopId);
      }

      final List<dynamic> productsData = response['products'] ?? [];

      setState(() {
        products =
            productsData.map((product) => Product.fromJson(product)).toList();
        _applyFilterAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilterAndSort() {
    // First apply filter
    List<Product> filtered;
    switch (_currentFilter) {
      case ProductStatusFilter.all:
        filtered = List.from(products);
        break;
      case ProductStatusFilter.active:
        filtered =
            products.where((product) => _isProductActive(product)).toList();
        break;
      case ProductStatusFilter.inactive:
        filtered =
            products.where((product) => _isProductInactive(product)).toList();
        break;
      case ProductStatusFilter.deleted:
        filtered =
            products.where((product) => _isProductDeleted(product)).toList();
        break;
      case ProductStatusFilter.draft:
        filtered =
            products.where((product) => _isProductDraft(product)).toList();
        break;
    }

    // Then sort by status priority: Active  Draft  Inactive  Deleted
    filtered.sort((a, b) {
      int getPriority(Product product) {
        if (_isProductActive(product)) return 1;
        if (_isProductDraft(product)) return 2;
        if (_isProductInactive(product)) return 3;
        if (_isProductDeleted(product)) return 4;
        return 5;
      }

      return getPriority(a).compareTo(getPriority(b));
    });

    setState(() {
      filteredProducts = filtered;
    });
  }

  bool _isProductActive(Product product) {
    final status = product.status.toUpperCase();
    return status == 'ACTIVATE' || status == 'ACTIVE' || status == 'NORMAL';
  }

  bool _isProductInactive(Product product) {
    final status = product.status.toUpperCase();
    return status == 'DEACTIVATE' ||
        status == 'INACTIVE' ||
        status == 'DEACTIVATED' ||
        status == 'SELLER_DEACTIVATED' ||
        status == 'UNLIST'; // Shopee: product unlisted by seller
  }

  bool _isProductDeleted(Product product) {
    final status = product.status.toUpperCase();
    return status == 'DELETED' ||
           status == 'REMOVED' ||
           status == 'DELETE' ||
           status == 'SELLER_DELETE' ||  // Shopee: deleted by seller
           status == 'SHOPEE_DELETE' ||  // Shopee: deleted by Shopee
           status == 'BANNED';            // Shopee: banned by Shopee
  }

  bool _isProductDraft(Product product) {
    final status = product.status.toUpperCase();
    return status == 'DRAFT' ||
           status == 'PENDING' ||
           status == 'REVIEWING';  // Shopee: product under review
  }

  // Product action methods
  Future<void> _activateProduct(Product product) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(width: 20),
              Text('Mengaktifkan produk...'),
            ],
          ),
        ),
      );

      // Platform-specific API call
      bool success;
      if (widget.platform.toLowerCase().contains('shopee')) {
        // Shopee: use unlistShopeeProduct with unlist=false to activate
        success = await _apiService.unlistShopeeProduct(
          widget.shopId,
          product.id,
          unlist: false, // false = activate/list
        );
      } else {
        // TikTok: use activateProduct
        success = await _apiService.activateProduct(widget.shopId, product.id);
      }

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil diaktifkan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProducts(); // Refresh products
      } else {
        _showErrorSnackBar('Gagal mengaktifkan produk');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _deactivateProduct(Product product) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(width: 20),
              Text('Menonaktifkan produk...'),
            ],
          ),
        ),
      );

      // Platform-specific API call
      bool success;
      if (widget.platform.toLowerCase().contains('shopee')) {
        // Shopee: use unlistShopeeProduct with unlist=true to deactivate
        success = await _apiService.unlistShopeeProduct(
          widget.shopId,
          product.id,
          unlist: true, // true = deactivate/unlist
        );
      } else {
        // TikTok: use deactivateProduct
        success = await _apiService.deactivateProduct(widget.shopId, product.id);
      }

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil dinonaktifkan'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProducts(); // Refresh products
      } else {
        _showErrorSnackBar('Gagal menonaktifkan produk');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      _showErrorSnackBar(e.toString());
    }
  }

  Future<void> _recoverProduct(Product product) async {
    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.blue),
            SizedBox(width: 12),
            Text('Pulihkan Produk'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin memulihkan produk ini?'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Produk akan dipulihkan dengan status "Nonaktif"',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
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
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text('Pulihkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(width: 20),
              Text('Memulihkan produk...'),
            ],
          ),
        ),
      );

      final success =
          await _apiService.recoverProduct(widget.shopId, product.id);

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk berhasil dipulihkan'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProducts(); // Refresh products
      } else {
        _showErrorSnackBar('Gagal memulihkan produk');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog if still open
      _showErrorSnackBar(e.toString());
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getFilterTitle(ProductStatusFilter filter) {
    switch (filter) {
      case ProductStatusFilter.active:
        return 'Aktif';
      case ProductStatusFilter.all:
        return 'Semua';
      case ProductStatusFilter.inactive:
        return 'Nonaktif';
      case ProductStatusFilter.deleted:
        return 'Dihapus';
      case ProductStatusFilter.draft:
        return 'Draft';
    }
  }

  Color _getFilterColor(ProductStatusFilter filter) {
    switch (filter) {
      case ProductStatusFilter.all:
        return Colors.grey[700]!;
      case ProductStatusFilter.active:
        return Colors.green[600]!;
      case ProductStatusFilter.inactive:
        return Colors.orange[600]!;
      case ProductStatusFilter.deleted:
        return Colors.red[600]!;
      case ProductStatusFilter.draft:
        return Colors.blue[600]!;
    }
  }

  int _getFilterCount(ProductStatusFilter filter) {
    switch (filter) {
      case ProductStatusFilter.all:
        return products.length;
      case ProductStatusFilter.active:
        return products.where((p) => _isProductActive(p)).length;
      case ProductStatusFilter.inactive:
        return products.where((p) => _isProductInactive(p)).length;
      case ProductStatusFilter.deleted:
        return products.where((p) => _isProductDeleted(p)).length;
      case ProductStatusFilter.draft:
        return products.where((p) => _isProductDraft(p)).length;
    }
  }

  void _showFilterBottomSheet() {
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
                      'Filter Status Produk',
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
              itemCount: ProductStatusFilter.values.length,
              itemBuilder: (context, index) {
                final filter = ProductStatusFilter.values[index];
                final count = _getFilterCount(filter);
                final isSelected = _currentFilter == filter;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _getFilterColor(filter).withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _getFilterColor(filter).withOpacity(0.3)
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
                            ? _getFilterColor(filter)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? _getFilterColor(filter)
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
                        Text(
                          _getFilterTitle(filter),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? _getFilterColor(filter)
                                : Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _getFilterColor(filter).withOpacity(0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? _getFilterColor(filter)
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _currentFilter = filter;
                        _applyFilterAndSort();
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
              _buildAppBar(),
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

  Widget _buildAppBar() {
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
                    'Kelola Produk',
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

            // Add Button - matching Dashboard style
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
              child: IconButton(
                icon: Icon(
                  Icons.add_rounded,
                  color: Color(0xFF1A237E),
                  size: 24,
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateProductScreen(
                        shopId: widget.shopId,
                        shopName: widget.shopName,
                        platform: widget.platform,
                      ),
                    ),
                  );

                  if (result == true) {
                    _loadProducts();
                  }
                },
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
              'Memuat produk...',
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
                onPressed: _loadProducts,
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

    if (filteredProducts.isEmpty && products.isNotEmpty) {
      return _buildNoResultsState();
    }

    if (products.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductList();
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
                Icons.inventory_outlined,
                size: 72,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 28),
            Text(
              'Belum Ada Produk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Tambahkan produk pertama Anda\nuntuk mulai berjualan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateProductScreen(
                      shopId: widget.shopId,
                      shopName: widget.shopName,
                      platform: widget.platform,
                    ),
                  ),
                );
                if (result == true) {
                  _loadProducts();
                }
              },
              icon: Icon(Icons.add_rounded, size: 22),
              label: Text(
                'Tambah Produk',
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

  Widget _buildNoResultsState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getFilterColor(_currentFilter).withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.filter_list_off_rounded,
                size: 72,
                color: _getFilterColor(_currentFilter),
              ),
            ),
            SizedBox(height: 28),
            Text(
              'Tidak Ada Produk ${_getFilterTitle(_currentFilter)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Coba pilih filter lain atau\ntambahkan produk baru',
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
                if (_currentFilter != ProductStatusFilter.all) ...[
                  SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentFilter = ProductStatusFilter.all;
                        _applyFilterAndSort();
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

  Widget _buildProductList() {
    return Column(
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
                  color: _getFilterColor(_currentFilter).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: _getFilterColor(_currentFilter),
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
                          '${filteredProducts.length}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getFilterColor(_currentFilter),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _getFilterTitle(_currentFilter),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    if (_currentFilter != ProductStatusFilter.all)
                      Text(
                        'dari ${products.length} total produk',
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
            onRefresh: _loadProducts,
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToProductDetail(product),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image - Improved
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[200]!, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: product.mainImage.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(
                                product.mainImage,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.grey[100]!,
                                          Colors.grey[200]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: Colors.grey[400],
                                      size: 28,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.grey[100]!,
                                    Colors.grey[200]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.grey[400],
                                size: 28,
                              ),
                            ),
                    ),

                    SizedBox(width: 14),

                    // Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Title
                          Text(
                            product.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A237E),
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: 8),

                          // Price with better styling
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF2196F3).withOpacity(0.1),
                                  Color(0xFF42A5F5).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Color(0xFF2196F3).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              product.formattedPrice,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          // Status and Stock Row
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Status Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      _getStatusColor(product).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getStatusColor(product)
                                        .withOpacity(0.3),
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
                                        color: _getStatusColor(product),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      _getStatusDisplayText(product),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getStatusColor(product),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Stock Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey[300]!, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 13,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${product.stock}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Action Section
                SizedBox(height: 16),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.grey[200]!,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14),

                Row(
                  children: [
                    // Action Button
                    Expanded(
                      child: _buildActionButton(product),
                    ),

                    SizedBox(width: 10),

                    // Detail Button - Improved
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[50]!,
                            Colors.grey[100]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _navigateToProductDetail(product),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: Colors.grey[700],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  // Helper method untuk mendapatkan warna status
  Color _getStatusColor(Product product) {
    if (_isProductActive(product)) {
      return Colors.green[600]!;
    } else if (_isProductInactive(product)) {
      return Colors.orange[600]!;
    } else if (_isProductDeleted(product)) {
      return Colors.red[600]!;
    } else {
      return Colors.blue[600]!;
    }
  }

  // Helper method untuk mendapatkan text status
  String _getStatusDisplayText(Product product) {
    if (_isProductActive(product)) {
      return 'Aktif';
    } else if (_isProductInactive(product)) {
      return 'Nonaktif';
    } else if (_isProductDeleted(product)) {
      return 'Dihapus';
    } else {
      return 'Draft';
    }
  }

  // Modern action buttons with improved styling
  Widget _buildActionButton(Product product) {
    if (_isProductDeleted(product)) {
      // Shopee doesn't support restore for deleted products
      // Only TikTok supports restore deleted products
      if (widget.platform.toLowerCase().contains('shopee')) {
        // For Shopee deleted products, show disabled button
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.grey[400]),
              SizedBox(width: 6),
              Text(
                'Dihapus',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      } else {
        // TikTok: show restore button
        return _buildModernButton(
          label: 'Pulihkan',
          icon: Icons.restore_rounded,
          gradient: [Colors.blue[600]!, Colors.blue[400]!],
          onTap: () => _recoverProduct(product),
        );
      }
    } else if (_isProductActive(product)) {
      return _buildModernButton(
        label: 'Nonaktifkan',
        icon: Icons.visibility_off_outlined,
        gradient: [Colors.orange[600]!, Colors.orange[400]!],
        onTap: () => _deactivateProduct(product),
      );
    } else if (_isProductInactive(product)) {
      return _buildModernButton(
        label: 'Aktifkan',
        icon: Icons.visibility_outlined,
        gradient: [Colors.green[600]!, Colors.green[400]!],
        onTap: () => _activateProduct(product),
      );
    } else {
      // Untuk draft - no action, subtle style
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey[500]),
            SizedBox(width: 8),
            Text(
              'Draft',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildModernButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        splashColor: gradient[0].withOpacity(0.1),
        highlightColor: gradient[0].withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: gradient[0].withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: gradient[0].withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: gradient[0]),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: gradient[0],
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          shopId: widget.shopId,
          shopName: widget.shopName,
          productId: product.id,
          productTitle: product.title,
          platform: widget.platform, // Pass platform to detail screen
        ),
      ),
    ).then((_) {
      // Refresh products ketika kembali dari detail
      _loadProducts();
    });
  }
}