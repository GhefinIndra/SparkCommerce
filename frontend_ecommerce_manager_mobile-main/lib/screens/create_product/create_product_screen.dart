import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/sku_sync_service.dart';
import 'models/product_form_data.dart';
import 'widgets/category_selector_widget.dart';
import 'widgets/product_info_widget.dart';
import 'widgets/image_selector_widget.dart';
import 'widgets/dynamic_attributes_widget.dart';
import 'widgets/category_rules_widget.dart';
import 'widgets/shopee_gtin_field_widget.dart';
import 'widgets/shopee_hazardous_field_widget.dart';

class CreateProductScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final String platform; // 'TikTok Shop' or 'Shopee'

  const CreateProductScreen({
    Key? key,
    required this.shopId,
    required this.shopName,
    required this.platform,
  }) : super(key: key);

  @override
  _CreateProductScreenState createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  // Platform detection helper
  bool get isShopee => widget.platform.toLowerCase().contains('shopee');
  bool get isTikTok => widget.platform.toLowerCase().contains('tiktok');

  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Section keys for auto-scroll
  final GlobalKey _basicSectionKey = GlobalKey();
  final GlobalKey _attributesSectionKey = GlobalKey();
  final GlobalKey _detailSectionKey = GlobalKey();
  final GlobalKey _rulesSectionKey = GlobalKey();
  final GlobalKey _infoSectionKey = GlobalKey();
  final GlobalKey _previewSectionKey = GlobalKey();

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Form data dan state
  late ProductFormData _formData;
  bool _isSubmitting = false;

  // Track states untuk dependent widgets
  bool _isDependentWidgetsLoaded = false;
  bool _isLoadingDependentWidgets = false;

  // Controllers untuk basic info
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _formData = ProductFormData();
    _titleController = TextEditingController(text: _formData.title);
    _titleController.addListener(() => _updateTitle(_titleController.text));

    // Initialize animations
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _updateTitle(String value) {
    _formData.title = value.trim();
    _formData.validateField('title', value);
    _notifyFormChange();
  }

  // Category change handler - note: level4 and level5 are managed internally by CategorySelectorWidget
  void _onCategoryChanged(
      String? level1Id, String? level2Id, String? level3Id) {

    // Don't override level 4 and 5 here - they're set directly by CategorySelectorWidget
    // Only update the levels passed in the callback
    _formData.selectedLevel1Id = level1Id;
    _formData.selectedLevel2Id = level2Id;
    _formData.selectedLevel3Id = level3Id;

    // Load dependent widgets based on platform requirements:
    // - TikTok: Requires level 3 (3-level category structure)
    // - Shopee: Dynamic (1-5 levels, use deepest selected level)
    final shouldLoad = isTikTok
        ? (level3Id != null && level3Id.isNotEmpty)
        : (_formData.selectedCategoryId != null && _formData.selectedCategoryId!.isNotEmpty);

    if (shouldLoad) {
      _loadDependentWidgets();
    } else {
      _clearDependentWidgets();
    }
  }

  void _loadDependentWidgets() async {
    // Use selectedCategoryId which returns the deepest selected level (supports 1-5 levels)
    if (_isLoadingDependentWidgets || _formData.selectedCategoryId == null) {
      return;
    }

    setState(() {
      _isLoadingDependentWidgets = true;
      _isDependentWidgetsLoaded = false;
    });

    print(
        ' Loading dependent widgets for category: ${_formData.selectedCategoryId}');
    print('   Platform: ${widget.platform}');
    print('   L1: ${_formData.selectedLevel1Id}');
    print('   L2: ${_formData.selectedLevel2Id}');
    print('   L3: ${_formData.selectedLevel3Id}');
    print('   L4: ${_formData.selectedLevel4Id}');
    print('   L5: ${_formData.selectedLevel5Id}');
    print('   Selected (deepest): ${_formData.selectedCategoryId}');

    // For Shopee: fetch item limits (GTIN validation rule, etc.)
    if (isShopee) {
      try {
        // Use the deepest selected category ID
        final categoryId = int.tryParse(_formData.selectedCategoryId!);
        if (categoryId != null) {
          print(' Calling getShopeeItemLimits with category_id: $categoryId');

          var limits = await _apiService.getShopeeItemLimits(
            widget.shopId,
            categoryId: categoryId,
          );

          // If category-specific fails (returns empty), try general limits
          if (limits.isEmpty) {
            print('️ Category-specific limits returned empty, trying general limits...');
            limits = await _apiService.getShopeeItemLimits(widget.shopId);
          }

          if (mounted) {
            setState(() {
              _formData.itemLimits = limits;
            });
          }

          if (limits.isNotEmpty) {
            print(' Item limits loaded: ${limits.keys}');
          } else {
            print('️ No item limits available, continuing with defaults');
          }
        }
      } catch (e) {
        print('️ Failed to load item limits (continuing anyway): $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isDependentWidgetsLoaded = true;
          _isLoadingDependentWidgets = false;
        });
      }
    });
  }

  void _clearDependentWidgets() {
    if (mounted) {
      setState(() {
        _isDependentWidgetsLoaded = false;
        _isLoadingDependentWidgets = false;
        _formData.clearCategoryData();
      });
      print('🧹 Dependent widgets cleared');
    }
  }

  void _onImagesChanged(List<XFile> newImages) {
    _formData.selectedImages = newImages;
    _notifyFormChange();
  }

  void _onAttributeValueChanged(
    String attributeId, {
    List<String>? valueIds,
    String? customValue,
  }) {
    _formData.updateAttribute(attributeId,
        valueIds: valueIds, customValue: customValue);
    _notifyFormChange();
  }

  void _notifyFormChange() {
    if (mounted && !_isLoadingDependentWidgets) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            // Just trigger rebuild
          });
        }
      });
    }
  }

  bool get _isBasicStepComplete {
    final title = _formData.title.trim();
    final titleValid = isShopee
        ? (title.isNotEmpty && title.length <= 226)
        : (title.length >= 25 && title.length <= 255);

    return titleValid &&
        _formData.selectedImages.isNotEmpty &&
        _formData.isCategorySelected;
  }

  bool get _isDetailStepComplete {
    return _formData.description.trim().isNotEmpty &&
        _formData.areRequiredAttributesSelected &&
        _formData.areCertificationsValid;
  }

  bool get _isShippingStepComplete {
    final priceOk = _formData.price.trim().isNotEmpty;
    final weightOk = _formData.weight.trim().isNotEmpty;
    final dimsOk = _formData.arePackageDimensionsValid;
    return priceOk && weightOk && dimsOk;
  }

  int get _currentStepIndex {
    if (!_isBasicStepComplete) return 0;
    if (!_isDetailStepComplete) return 1;
    return 2;
  }

  double get _progressValue {
    final completed = [
      _isBasicStepComplete,
      _isDetailStepComplete,
      _isShippingStepComplete
    ].where((step) => step).length;
    return (completed / 3).clamp(0.0, 1.0);
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  void _scrollToFirstError() {
    if (!_formData.isCategorySelected ||
        _formData.selectedImages.isEmpty ||
        _formData.title.trim().isEmpty) {
      _scrollToSection(_basicSectionKey);
      return;
    }

    if (!_formData.areRequiredAttributesSelected) {
      _scrollToSection(_attributesSectionKey);
      return;
    }

    if (_formData.description.trim().isEmpty) {
      _scrollToSection(_detailSectionKey);
      return;
    }

    if (!_formData.areCertificationsValid ||
        !_formData.arePackageDimensionsValid) {
      _scrollToSection(_rulesSectionKey);
      return;
    }

    if (_formData.price.trim().isEmpty ||
        _formData.weight.trim().isEmpty) {
      _scrollToSection(_infoSectionKey);
      return;
    }

    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Submit Product
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (!_formData.isFormValid) {
      String errorMessage = 'Form tidak valid';

      // Use selectedCategoryId to support dynamic category depth (1-5 levels)
      if (_formData.selectedCategoryId == null) {
        errorMessage = 'Pilih kategori produk';
      } else if (_formData.selectedImages.isEmpty) {
        errorMessage = 'Pilih minimal 1 gambar produk';
      } else if (!_formData.areRequiredAttributesSelected) {
        errorMessage = 'Lengkapi semua atribut yang wajib diisi';
      } else if (!_formData.areCertificationsValid) {
        errorMessage = 'Lengkapi semua sertifikat yang wajib diisi';
      } else if (!_formData.arePackageDimensionsValid) {
        errorMessage = 'Lengkapi dimensi kemasan yang wajib diisi';
      }
      // Size chart validation removed - handled by backend/TikTok API

      _showSnackBar(errorMessage, Colors.red);
      _scrollToFirstError();
      return;
    }

    try {
      if (!mounted) return;
      setState(() => _isSubmitting = true);

      // Platform-specific image upload and product creation
      if (isShopee) {
        // SHOPEE FLOW
        // Upload images to Shopee
        List<String> imageIds = [];
        for (int i = 0; i < _formData.selectedImages.length; i++) {
          if (!mounted) return;

          try {
            final uploadResult = await _apiService.uploadShopeeProductImage(
              widget.shopId,
              File(_formData.selectedImages[i].path),
              scene: 'normal',
              ratio: '1:1',
            );

            if (uploadResult['image_id'] != null) {
              imageIds.add(uploadResult['image_id']);
            } else {
              throw Exception('Failed to get image_id from upload');
            }
          } catch (uploadError) {
            throw Exception('Gagal upload gambar ${i + 1}: $uploadError');
          }
        }

        if (imageIds.length != _formData.selectedImages.length) {
          throw Exception('Gagal upload semua gambar');
        }

        _formData.uploadedImageUris = imageIds;

        if (!mounted) return;

        // Create Shopee product
        final response = await _apiService.createShopeeProduct(
          widget.shopId,
          _formData.toShopeeApiData(),
        );

        if (!mounted) return;

        if (response['success'] == true) {
          _showSnackBar('Produk Shopee berhasil ditambahkan!', Color(0xFF4CAF50));

          final data = response['data'];

          if (data is Map<String, dynamic>) {
            print(' Shopee product created - data: $data');
            final skuMapping = data['sku_mapping'];
            print(' SKU Mapping from backend: $skuMapping');

            if (skuMapping != null && skuMapping is Map<String, dynamic>) {
              try {
                final syncService = SKUSyncService();

                // Handle two formats:
                // Format 1: {skus: [{seller_sku: "...", sku_id: "..."}], product_id: "..."}
                // Format 2: {item_id: "...", seller_sku: "...", marketplace: "SHOPEE"} (flat object)

                final skus = skuMapping['skus'] as List?;
                print(' SKUs to link: $skus');

                int linkedCount = 0;

                if (skus != null && skus.isNotEmpty) {
                  // Format 1: Array of SKUs
                  for (var skuData in skus) {
                    final sellerSku = skuData['seller_sku'] ?? _formData.sellerSku;

                    print('   Processing SKU: $sellerSku');
                    print('   Product ID: ${skuMapping['product_id']}');
                    print('   Variation ID: ${skuData['sku_id']}');
                    print('   Warehouse ID: ${skuData['warehouse_id'] ?? skuMapping['warehouse_id']}');

                    if (sellerSku == null || sellerSku.toString().trim().isEmpty) {
                      print('   ️ Skipping - empty seller SKU');
                      continue;
                    }

                    await syncService.linkProductToSKU(
                      sku: sellerSku,
                      marketplace: 'SHOPEE',
                      productId: skuMapping['product_id'].toString(),
                      variationId: skuData['sku_id']?.toString(),
                      warehouseId: skuData['warehouse_id']?.toString() ?? skuMapping['warehouse_id']?.toString(),
                      shopId: widget.shopId,
                    );
                    linkedCount++;
                    print('    Linked $sellerSku to SHOPEE');
                  }
                } else if (skuMapping['seller_sku'] != null) {
                  // Format 2: Flat object with seller_sku directly
                  final sellerSku = skuMapping['seller_sku'].toString();
                  final itemId = skuMapping['item_id']?.toString();

                  print('    Processing flat SKU mapping');
                  print('   Seller SKU: $sellerSku');
                  print('   Item ID: $itemId');

                  if (sellerSku.trim().isNotEmpty && itemId != null) {
                    await syncService.linkProductToSKU(
                      sku: sellerSku,
                      marketplace: 'SHOPEE',
                      productId: itemId,
                      variationId: itemId, // For single SKU product, use item_id as variation_id
                      warehouseId: null,
                      shopId: widget.shopId,
                    );
                    linkedCount++;
                    print('    Linked $sellerSku to SHOPEE (item_id: $itemId)');
                  }
                } else {
                  print('️ No SKUs found in sku_mapping');
                }

                if (linkedCount > 0) {
                  _showSnackBar(' $linkedCount SKU berhasil di-link ke Shopee', Color(0xFF4CAF50));
                }
              } catch (e) {
                print(' Error linking SKU: $e');
                _showSnackBar('️ Produk dibuat, tapi auto-link SKU gagal', Colors.orange);
              }
            } else {
              print('️ No sku_mapping in response data');
            }
          }

          if (mounted) Navigator.pop(context, true);
        }
      } else {
        // TIKTOK FLOW (existing code)
        // Upload Size Chart Image if needed
        if (_formData.customSizeChartImage != null &&
            _formData.uploadedSizeChartUri == null) {
          try {
            final sizeChartResult = await _apiService.uploadSizeChartImage(
              widget.shopId,
              File(_formData.customSizeChartImage!.path),
            );

            if (sizeChartResult['uri'] != null) {
              _formData.uploadedSizeChartUri = sizeChartResult['uri'];
            }
          } catch (sizeChartError) {
            throw Exception('Gagal upload size chart: $sizeChartError');
          }
        }

        // Upload main images
        List<String> imageUris = [];
        for (int i = 0; i < _formData.selectedImages.length; i++) {
          if (!mounted) return;

          try {
            final uploadedUri =
                await _uploadProductImage(_formData.selectedImages[i]);
            if (uploadedUri != null && uploadedUri.isNotEmpty) {
              imageUris.add(uploadedUri);
            } else {
              throw Exception('Failed to upload image ${i + 1}');
            }
          } catch (uploadError) {
            throw Exception('Gagal upload gambar ${i + 1}: $uploadError');
          }
        }

        if (imageUris.length != _formData.selectedImages.length) {
          throw Exception('Gagal upload semua gambar');
        }

        _formData.uploadedImageUris = imageUris;

        if (!mounted) return;

        final response = await _apiService.createProductWithRules(
            widget.shopId, _formData.toApiData());

        if (!mounted) return;

        if (response['success'] == true) {
          _showSnackBar('Produk berhasil ditambahkan!', const Color(0xFF4CAF50));

          final data = response['data'];


          if (data is Map<String, dynamic>) {
            print(' TikTok product created - data: $data');
            final skuMapping = data['sku_mapping'];
            print(' SKU Mapping from backend: $skuMapping');

            if (skuMapping != null && skuMapping is Map<String, dynamic>) {
              try {
                final syncService = SKUSyncService();
                final skus = skuMapping['skus'] as List?;
                print(' SKUs to link: $skus');

                if (skus != null && skus.isNotEmpty) {
                  int linkedCount = 0;

                  for (var skuData in skus) {
                    final sellerSku = skuData['seller_sku'] ?? _formData.sellerSku;

                    print('   Processing SKU: $sellerSku');
                    print('   Product ID: ${skuMapping['product_id']}');
                    print('   Variation ID: ${skuData['sku_id']}');
                    print('   Warehouse ID: ${skuData['warehouse_id'] ?? skuMapping['warehouse_id']}');

                    // Skip mapping jika SKU kosong (user pilih "Kosongkan SKU")
                    if (sellerSku == null || sellerSku.toString().trim().isEmpty) {
                      print('   ️ Skipping - empty seller SKU');
                      continue;
                    }

                    await syncService.linkProductToSKU(
                      sku: sellerSku,
                      marketplace: skuMapping['marketplace'] ?? 'TIKTOK',
                      productId: skuMapping['product_id'].toString(),
                      variationId: skuData['sku_id']?.toString(),
                      warehouseId: skuData['warehouse_id']?.toString() ?? skuMapping['warehouse_id']?.toString(),
                      shopId: widget.shopId,
                    );
                    linkedCount++;
                    print('    Linked $sellerSku to TIKTOK');
                  }

                  _showSnackBar(' $linkedCount SKU berhasil di-link ke marketplace', const Color(0xFF4CAF50));
                } else {
                  print('️ No SKUs found in sku_mapping');
                }
              } catch (e) {
                print(' Error linking TikTok SKU: $e');
                _showSnackBar('️ Produk dibuat, tapi auto-link SKU gagal', Colors.orange);
              }
            } else {
              // Fallback to old manual mapping jika sku_mapping tidak ada
              if (data['product_id'] != null) {
                // Skip mapping jika SKU kosong (user pilih "Kosongkan SKU")
                if (_formData.sellerSku.trim().isNotEmpty) {
                  try {
                    await DatabaseService().insertMapping(
                      sku: _formData.sellerSku,
                      marketplace: 'TIKTOK',
                      productId: data['product_id'].toString(),
                      variationId: data['sku_id']?.toString(),
                      warehouseId: data['warehouse_id']?.toString(),
                      shopId: widget.shopId,
                    );
                  } catch (e) {
                  }
                } else {
                }
              }
            }
          }

          if (mounted) Navigator.pop(context, true);
        }
      } // Close else block for TikTok flow
    } catch (e) {
      if (mounted) _showSnackBar('Gagal menambahkan produk: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _uploadProductImage(XFile imageFile) async {
    try {
      if (!mounted) return null;

      final file = File(imageFile.path);
      final result = await _apiService.uploadProductImage(
        widget.shopId,
        file,
        useCase: 'MAIN_IMAGE',
      );

      if (!mounted) return null;

      return result['uri'];
    } catch (e) {
      return null;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showWarningsDialog(List warnings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
            SizedBox(width: 12),
            Text('Peringatan', style: TextStyle(color: Colors.orange[700])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: warnings
              .map<Widget>((warning) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(top: 8, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Text('${warning['message']}')),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E),
              Color(0xFF283593),
              Color(0xFF3949AB),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          // Glassmorphism Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  widget.shopName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Save Button
          GestureDetector(
            onTap: _isSubmitting ? null : _submitProduct,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _isSubmitting
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isSubmitting
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSubmitting)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A237E),
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Icon(
                      Icons.save_rounded,
                      color: Color(0xFF1A237E),
                      size: 18,
                    ),
                  SizedBox(width: 6),
                  Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan',
                    style: TextStyle(
                      color: _isSubmitting
                          ? Colors.white.withOpacity(0.7)
                          : Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildStepChip(index: 0, label: 'Informasi Dasar'),
                _buildStepConnector(),
                _buildStepChip(index: 1, label: 'Detail'),
                _buildStepConnector(),
                _buildStepChip(index: 2, label: 'Pengiriman'),
              ],
            ),
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: _progressValue,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector() {
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }

  Widget _buildStepChip({required int index, required String label}) {
    final isCompleted = _progressValue >= (index + 1) / 3;
    final isCurrent = _currentStepIndex == index;

    Color chipColor;
    Color textColor;

    if (isCompleted) {
      chipColor = Color(0xFF4CAF50);
      textColor = Colors.white;
    } else if (isCurrent) {
      chipColor = Colors.white;
      textColor = Color(0xFF1A237E);
    } else {
      chipColor = Colors.white.withOpacity(0.3);
      textColor = Colors.white.withOpacity(0.7);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCompleted)
            Icon(Icons.check, size: 14, color: textColor)
          else
            Text(
              '${index + 1}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Form(
            key: _formKey,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification ||
                      notification is ScrollUpdateNotification) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                  return false;
                },
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(20),
                  physics: ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
          // 1. INFORMASI DASAR
          _buildSection(
            sectionKey: _basicSectionKey,
            title: 'Informasi Dasar',
            children: [
              // Gambar Produk
              Text(
                'Gambar Produk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              SizedBox(height: 8),
              ImageSelectorWidget(
                key: ValueKey('image_selector'),
                selectedImages: _formData.selectedImages,
                onImagesChanged: _onImagesChanged,
              ),

              SizedBox(height: 20),

              // Nama Produk
              _buildProductNameField(),

              SizedBox(height: 20),

              // Kategori & Merek
              Text(
                'Kategori Produk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
              SizedBox(height: 8),
              CategorySelectorWidget(
                key: ValueKey('category_selector'),
                shopId: widget.shopId,
                platform: widget.platform,
                formData: _formData,
                onCategoryChanged: _onCategoryChanged,
              ),
            ],
          ),

          // Show loading for dependent widgets
          if (_isLoadingDependentWidgets)
            Column(
              children: [
                _buildSkeletonSection(
                  title: isShopee ? 'Spesifikasi' : 'Atribut Produk',
                ),
                _buildSkeletonSection(title: 'Detail Produk'),
                _buildSkeletonSection(title: 'Info Penjualan & Pengiriman'),
              ],
            ),

          // Show dependent widgets only when ready
          // Use selectedCategoryId to support dynamic category depth (1-5 levels)
          if (_isDependentWidgetsLoaded &&
              _formData.selectedCategoryId != null) ...[
            // Atribut Produk / Spesifikasi (untuk semua platform)
            _buildSection(
              sectionKey: _attributesSectionKey,
              title: isShopee ? 'Spesifikasi' : 'Atribut Produk',
              child: DynamicAttributesWidget(
                key: ValueKey(
                    'dynamic_attributes_${_formData.selectedCategoryId}'),
                shopId: widget.shopId,
                platform: widget.platform, // Pass platform untuk deteksi Shopee/TikTok
                formData: _formData,
                onChanged: _notifyFormChange,
              ),
            ),

            // 2. DETAIL PRODUK (with size chart)
            _buildDetailProductSection(sectionKey: _detailSectionKey),

            // TIKTOK-ONLY: Category Rules Section (Certifications, Package Dimensions, etc.)
            if (!isShopee) ...[
              _buildSection(
                sectionKey: _rulesSectionKey,
                title: 'Persyaratan Kategori',
                child: CategoryRulesWidget(
                  key: ValueKey('category_rules_${_formData.selectedLevel3Id}'),
                  shopId: widget.shopId,
                  formData: _formData,
                  onChanged: _notifyFormChange,
                ),
              ),
            ],

            // 3. INFO PENJUALAN & PENGIRIMAN
            _buildSection(
              sectionKey: _infoSectionKey,
              title: 'Info Penjualan & Pengiriman',
              child: ProductInfoWidget(
                key: ValueKey('product_info'),
                formData: _formData,
                onDataChanged: (data) => _notifyFormChange(),
                showOnlyBusinessFields: true, // Flag baru untuk hide basic info
              ),
            ),

            // 4. SHOPEE-SPECIFIC SECTIONS
            if (isShopee) ...[
              // GTIN Field (optional/flexible/mandatory based on category)
              _buildSection(
                title: 'Informasi Tambahan',
                children: [
                  // GTIN Field
                  ShopeeGTINFieldWidget(
                    formData: _formData,
                    onChanged: _notifyFormChange,
                    validationRule: _formData.itemLimits?['gtin_limit']?['gtin_validation_rule'] ?? 'Optional',
                  ),

                  SizedBox(height: 16),

                  // Hazardous Product (for ID and MY only)
                  // Show for all regions, user can select if applicable
                  ShopeeHazardousFieldWidget(
                    formData: _formData,
                    onChanged: _notifyFormChange,
                    isRequired: true,
                  ),
                ],
              ),
            ],
          ],

          // Show message when no category selected
          // Use selectedCategoryId to support dynamic category depth (1-5 levels)
          if (_formData.selectedCategoryId == null &&
              !_isLoadingDependentWidgets) ...[
            _buildPlaceholderSections(),
          ],

          _buildPreviewSection(),

                // Bottom spacing
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildSection(
      {required String title,
      Key? sectionKey,
      Widget? child,
      List<Widget>? children}) {
    return Container(
      key: sectionKey,
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF2196F3),
                        Color(0xFF1976D2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (child != null) child,
            if (children != null) ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildProductNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Nama Produk',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Wajib',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: TextFormField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama produk wajib diisi';
              }

              if (isShopee) {
                // Shopee: 0-226 chars
                if (value.trim().length > 226) {
                  return 'Nama produk maksimal 226 karakter';
                }
              } else {
                // TikTok: 25-255 chars
                if (value.trim().length < 25) {
                  return 'Nama produk minimal 25 karakter';
                }
                if (value.trim().length > 255) {
                  return 'Nama produk maksimal 255 karakter';
                }
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: isShopee
                  ? 'Masukkan nama produk (maks 226 karakter)'
                  : 'Masukkan nama produk (25-255 karakter)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
          ),
        ),
        // Character counter
        Padding(
          padding: EdgeInsets.only(top: 4, right: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              isShopee
                  ? '${_formData.title.length}/226'
                  : '${_formData.title.length}/255',
              style: TextStyle(
                fontSize: 11,
                color: isShopee
                    ? (_formData.title.length > 226 ? Colors.red[600] : Colors.grey[500])
                    : (_formData.title.length < 25 || _formData.title.length > 255
                        ? Colors.red[600]
                        : Colors.grey[500]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailProductSection({Key? sectionKey}) {
    return _buildSection(
      sectionKey: sectionKey,
      title: 'Detail Produk',
      children: [
        // Deskripsi
        _buildDescriptionField(),

        SizedBox(height: 20),

        // Kondisi
        _buildConditionField(),

        // Tabel Ukuran jika supported
        if (_formData.sizeChartSupported) ...[
          SizedBox(height: 20),
          _buildSizeChartField(),
        ],
      ],
    );
  }

  Widget _buildSkeletonSection({required String title}) {
    return _buildSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonLine(widthFactor: 0.6),
          SizedBox(height: 12),
          _buildSkeletonLine(widthFactor: 0.9),
          SizedBox(height: 12),
          _buildSkeletonBlock(height: 48),
          SizedBox(height: 12),
          _buildSkeletonBlock(height: 48),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine({double widthFactor = 1.0}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildSkeletonBlock({double height = 56}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final hasPreviewData = _formData.title.trim().isNotEmpty ||
        _formData.selectedImages.isNotEmpty ||
        _formData.price.trim().isNotEmpty;

    if (!hasPreviewData) return SizedBox.shrink();

    final categoryPath = [
      _formData.level1Name,
      _formData.level2Name,
      _formData.level3Name,
      _formData.level4Name,
      _formData.level5Name
    ].where((name) => name.isNotEmpty).join(' > ');

    return _buildSection(
      sectionKey: _previewSectionKey,
      title: 'Preview Ringkas',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: _formData.selectedImages.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_formData.selectedImages.first.path),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(Icons.image_outlined, color: Colors.grey[400]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formData.title.trim().isNotEmpty
                      ? _formData.title
                      : 'Nama produk belum diisi',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  categoryPath.isNotEmpty
                      ? categoryPath
                      : 'Kategori belum dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPreviewChip(
                      label: _formData.price.trim().isNotEmpty
                          ? 'Rp ${_formData.price}'
                          : 'Harga belum diisi',
                      color: Color(0xFF2196F3),
                    ),
                    _buildPreviewChip(
                      label: _formData.stock.trim().isNotEmpty
                          ? 'Stok ${_formData.stock}'
                          : 'Stok opsional',
                      color: Color(0xFF4CAF50),
                    ),
                    _buildPreviewChip(
                      label: _formData.weight.trim().isNotEmpty
                          ? '${_formData.weight} ${_formData.weightUnit}'
                          : 'Berat belum diisi',
                      color: Color(0xFFFF9800),
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

  Widget _buildPreviewChip({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Deskripsi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 4),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Wajib',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!, width: 1.5),
          ),
          child: TextFormField(
            initialValue: _formData.description,
            maxLines: 5,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onChanged: (value) {
              _formData.description = value.trim();
              _formData.validateField('description', value);
              _notifyFormChange();
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Deskripsi wajib diisi';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Masukkan deskripsi produk',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kondisi Produk',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3436),
          ),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            _showConditionDialog();
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  _formData.condition == 'Baru' ? Icons.new_releases : Icons.restore,
                  size: 20,
                  color: _formData.condition == 'Baru' ? Color(0xFF4CAF50) : Color(0xFFFF9800),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formData.condition,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Color(0xFF2196F3)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showConditionDialog() {
    String? tempSelected = _formData.condition;

    final conditions = [
      {'value': 'Baru', 'icon': Icons.new_releases, 'color': Color(0xFF4CAF50)},
      {'value': 'Bekas', 'icon': Icons.restore, 'color': Color(0xFFFF9800)},
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shopping_bag, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Kondisi Produk',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Options List
                    ...conditions.map((condition) {
                      final isSelected = tempSelected == condition['value'];
                      return InkWell(
                        onTap: () {
                          setDialogState(() => tempSelected = condition['value'] as String);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (condition['color'] as Color).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(condition['icon'] as IconData, color: condition['color'] as Color, size: 20),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  condition['value'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: isSelected ? Color(0xFF3949AB) : Color(0xFF2D3436),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: Color(0xFF3949AB), size: 24),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    // Footer Actions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _formData.condition = tempSelected ?? 'Baru';
                              });
                              _notifyFormChange();
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF3949AB),
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Simpan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSizeChartField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tabel Ukuran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3436),
              ),
            ),
            if (_formData.sizeChartRequired)
              Container(
                margin: EdgeInsets.only(left: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Wajib',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12),

        // Simple upload area
        GestureDetector(
          onTap: _pickSizeChartImage,
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _formData.sizeChartRequired && !_formData.isSizeChartValid
                    ? Colors.red[300]!
                    : Color(0xFF2196F3).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: _formData.customSizeChartImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_formData.customSizeChartImage!.path),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _formData.customSizeChartImage = null;
                              _formData.uploadedSizeChartUri = null;
                            });
                            _notifyFormChange();
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF45A049),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Gambar custom dipilih',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tap untuk upload gambar',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Format: JPG, PNG (Maks 5MB)',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        // Validation message
        if (_formData.sizeChartRequired && !_formData.isSizeChartValid)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Tabel ukuran wajib untuk kategori ini',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickSizeChartImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _formData.customSizeChartImage = image;
          // Clear template selection if custom image selected
          _formData.selectedSizeChartTemplateId = null;
          _formData.selectedSizeChartTemplateName = null;
        });
        _notifyFormChange();
      }
    } catch (e) {
      _showSnackBar('Gagal memilih gambar: $e', Colors.red);
    }
  }

  Widget _buildPlaceholderSections() {
    return Column(
      children: [
        // Detail Produk placeholder
        _buildSection(
          title: 'Detail Produk',
          child: _buildLockedSectionMessage(),
        ),

        // Info Penjualan placeholder
        _buildSection(
          title: 'Info Penjualan',
          child: _buildLockedSectionMessage(),
        ),

        // Pengiriman placeholder
        _buildSection(
          title: 'Pengiriman',
          child: _buildLockedSectionMessage(),
        ),
      ],
    );
  }

  Widget _buildLockedSectionMessage() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pilih kategori terlebih dahulu untuk membuka bagian ini.',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
