// lib/screens/create_product/widgets/category_selector_widget.dart
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../models/product_form_data.dart';

class CategorySelectorWidget extends StatefulWidget {
  final String shopId;
  final String platform; // 'TikTok Shop' or 'Shopee'
  final ProductFormData formData;
  final Function(String?, String?, String?) onCategoryChanged;

  const CategorySelectorWidget({
    Key? key,
    required this.shopId,
    required this.platform,
    required this.formData,
    required this.onCategoryChanged,
  }) : super(key: key);

  @override
  _CategorySelectorWidgetState createState() => _CategorySelectorWidgetState();
}

class _CategorySelectorWidgetState extends State<CategorySelectorWidget>
    with AutomaticKeepAliveClientMixin {
  // PENTING: Keep alive untuk mencegah rebuild
  @override
  bool get wantKeepAlive => true;

  // Platform detection helper
  bool get isShopee => widget.platform.toLowerCase().contains('shopee');
  bool get isTikTok => widget.platform.toLowerCase().contains('tiktok');

  final ApiService _apiService = ApiService();

  // Category data (support up to 5 levels)
  List<Map<String, dynamic>> _level1Categories = [];
  List<Map<String, dynamic>> _level2Categories = [];
  List<Map<String, dynamic>> _level3Categories = [];
  List<Map<String, dynamic>> _level4Categories = [];
  List<Map<String, dynamic>> _level5Categories = [];
  List<Map<String, dynamic>> _brands = [];

  // Loading states - TERPISAH untuk mencegah rebuild cascade
  bool _isLoadingLevel1 = false;
  bool _isLoadingLevel2 = false;
  bool _isLoadingLevel3 = false;
  bool _isLoadingLevel4 = false;
  bool _isLoadingLevel5 = false;
  bool _isLoadingBrands = false;

  // Cache untuk mencegah reload berulang
  static final Map<String, List<Map<String, dynamic>>> _categoryCache = {};
  static final Map<String, List<Map<String, dynamic>>> _brandCache = {};

  // Track last loaded values untuk prevent duplicate calls
  String? _lastLevel1Id;
  String? _lastLevel2Id;
  String? _lastLevel3Id;
  String? _lastLevel4Id;
  String? _lastLevel5Id;

  @override
  void initState() {
    super.initState();
    _loadLevel1Categories();

    // Initialize tracking values
    _lastLevel1Id = widget.formData.selectedLevel1Id;
    _lastLevel2Id = widget.formData.selectedLevel2Id;
    _lastLevel3Id = widget.formData.selectedLevel3Id;
  }

  @override
  void didUpdateWidget(CategorySelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // PENTING: Hanya rebuild jika data benar-benar berubah
    if (oldWidget.formData.selectedLevel1Id !=
            widget.formData.selectedLevel1Id ||
        oldWidget.formData.selectedLevel2Id !=
            widget.formData.selectedLevel2Id ||
        oldWidget.formData.selectedLevel3Id !=
            widget.formData.selectedLevel3Id) {
      // Only update if really changed to prevent loops
      if (_lastLevel1Id != widget.formData.selectedLevel1Id &&
          widget.formData.selectedLevel1Id != null) {
        _lastLevel1Id = widget.formData.selectedLevel1Id;
        final category = _level1Categories.firstWhere(
          (cat) => cat['id']?.toString() == widget.formData.selectedLevel1Id,
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          _loadLevel2CategoriesIfNeeded(
              widget.formData.selectedLevel1Id!,
              category['local_name']?.toString() ??
                  category['name']?.toString() ??
                  '');
        }
      }

      if (_lastLevel2Id != widget.formData.selectedLevel2Id &&
          widget.formData.selectedLevel2Id != null) {
        _lastLevel2Id = widget.formData.selectedLevel2Id;
        final category = _level2Categories.firstWhere(
          (cat) => cat['id']?.toString() == widget.formData.selectedLevel2Id,
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          _loadLevel3CategoriesIfNeeded(
              widget.formData.selectedLevel2Id!,
              category['local_name']?.toString() ??
                  category['name']?.toString() ??
                  '');
        }
      }

      if (_lastLevel3Id != widget.formData.selectedLevel3Id &&
          widget.formData.selectedLevel3Id != null) {
        _lastLevel3Id = widget.formData.selectedLevel3Id;
        final category = _level3Categories.firstWhere(
          (cat) => cat['id']?.toString() == widget.formData.selectedLevel3Id,
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          _loadBrandsIfNeeded(
              widget.formData.selectedLevel3Id!,
              category['local_name']?.toString() ??
                  category['name']?.toString() ??
                  '');
        }
      }
    }
  }

  Future<void> _loadLevel1Categories() async {
    if (!mounted || _isLoadingLevel1) return;

    // Check cache first - different cache key per platform
    final cacheKey = isShopee ? 'shopee_level1_categories' : 'tiktok_level1_categories';
    if (_categoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _level1Categories = List.from(_categoryCache[cacheKey]!);
        });
      }
      return;
    }

    try {
      if (mounted) setState(() => _isLoadingLevel1 = true);

      // Platform-specific API call
      final response = isShopee
          ? await _apiService.getShopeeCategories(widget.shopId, language: 'id')
          : await _apiService.getCategories(widget.shopId);

      if (!mounted) return;

      if (response is Map<String, dynamic> &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'];

        List<Map<String, dynamic>> categories = [];

        if (isShopee) {
          // Shopee returns tree structure, extract level 1 only
          if (data is Map && data['tree'] != null) {
            final tree = data['tree'] as Map<String, dynamic>;
            final level1 = tree['level1'] as List?;
            if (level1 != null) {
              categories = List<Map<String, dynamic>>.from(
                  level1.map((item) => Map<String, dynamic>.from(item)));
            }
          }
        } else {
          // TikTok returns flat list
          if (data is List) {
            categories = List<Map<String, dynamic>>.from(
                data.map((item) => Map<String, dynamic>.from(item)));
          }
        }

        _categoryCache[cacheKey] = categories;

        setState(() {
          _level1Categories = categories;
        });
      } else {
        _showError(
            'Gagal memuat kategori: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (mounted) _showError('Gagal memuat kategori: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevel1 = false);
    }
  }

  Future<void> _loadLevel2CategoriesIfNeeded(
      String parentId, String parentName) async {
    if (!mounted || _isLoadingLevel2) return;

    // Check cache first
    final platform = isShopee ? 'shopee' : 'tiktok';
    final cacheKey = '${platform}_level2_$parentId';
    if (_categoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _level2Categories = List.from(_categoryCache[cacheKey]!);
          _level3Categories.clear();
          _brands.clear();
          widget.formData.level1Name = parentName;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingLevel2 = true;
          _level2Categories.clear();
          _level3Categories.clear();
          _brands.clear();
          widget.formData.level1Name = parentName;
        });
      }

      List<Map<String, dynamic>> categories = [];

      if (isShopee) {
        // For Shopee: Extract children from level 1 category tree
        // Shopee uses 'id' field, not 'category_id'
        final parent = _level1Categories.firstWhere(
          (cat) => (cat['id'] ?? cat['category_id'])?.toString() == parentId,
          orElse: () => {},
        );

        if (parent.isNotEmpty && parent['children'] != null) {
          // Deep copy to preserve nested children array
          categories = (parent['children'] as List).map((item) {
            final copy = Map<String, dynamic>.from(item);
            // Preserve children array if exists (for level 3)
            if (item['children'] != null) {
              copy['children'] = List<Map<String, dynamic>>.from(
                (item['children'] as List).map((child) => Map<String, dynamic>.from(child))
              );
            }
            return copy;
          }).toList();
        }
      } else {
        // For TikTok: Call API to get child categories
        final response =
            await _apiService.getChildCategories(widget.shopId, parentId);

        if (!mounted) return;

        if (response is Map<String, dynamic> &&
            response['success'] == true &&
            response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            categories = List<Map<String, dynamic>>.from(
                data.map((item) => Map<String, dynamic>.from(item)));
          }
        } else {
          _showError(
              'Gagal memuat subkategori: ${response['message'] ?? 'Unknown error'}');
        }
      }

      _categoryCache[cacheKey] = categories;

      if (mounted) {
        setState(() {
          _level2Categories = categories;
        });
      }
    } catch (e) {
      if (mounted) _showError('Gagal memuat subkategori: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevel2 = false);
    }
  }

  Future<void> _loadLevel3CategoriesIfNeeded(
      String parentId, String parentName) async {
    if (!mounted || _isLoadingLevel3) return;

    // Check cache first
    final platform = isShopee ? 'shopee' : 'tiktok';
    final cacheKey = '${platform}_level3_$parentId';
    if (_categoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _level3Categories = List.from(_categoryCache[cacheKey]!);
          _brands.clear();
          widget.formData.level2Name = parentName;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingLevel3 = true;
          _level3Categories.clear();
          _brands.clear();
          widget.formData.level2Name = parentName;
        });
      }

      List<Map<String, dynamic>> categories = [];

      if (isShopee) {
        // For Shopee: Extract children from level 2 category
        // Shopee uses 'id' field, not 'category_id'
        final parent = _level2Categories.firstWhere(
          (cat) => (cat['id'] ?? cat['category_id'])?.toString() == parentId,
          orElse: () => {},
        );

        print(' DEBUG Level3 - Looking for parent: $parentId');
        print('   Parent found: ${parent.isNotEmpty}');
        print('   Parent has children: ${parent['children'] != null}');
        print('   Children count: ${parent['children']?.length ?? 0}');
        if (parent['children'] != null && parent['children'].length > 0) {
          print('   First child: ${parent['children'][0]}');
        }

        if (parent.isNotEmpty && parent['children'] != null) {
          categories = List<Map<String, dynamic>>.from(
            (parent['children'] as List).map((item) => Map<String, dynamic>.from(item))
          );
        } else {
          print('️ No children found in level 2 parent!');
        }
      } else {
        // For TikTok: Call API to get child categories
        final response =
            await _apiService.getChildCategories(widget.shopId, parentId);

        if (!mounted) return;

        if (response is Map<String, dynamic> &&
            response['success'] == true &&
            response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            categories = List<Map<String, dynamic>>.from(
                data.map((item) => Map<String, dynamic>.from(item)));
          }
        } else {
          _showError(
              'Gagal memuat kategori level 3: ${response['message'] ?? 'Unknown error'}');
        }
      }

      _categoryCache[cacheKey] = categories;

      if (mounted) {
        setState(() {
          _level3Categories = categories;
        });
      }
    } catch (e) {
      if (mounted) _showError('Gagal memuat kategori level 3: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevel3 = false);
    }
  }

  Future<void> _loadLevel4CategoriesIfNeeded(
      String parentId, String parentName) async {
    if (!mounted || _isLoadingLevel4) return;

    final platform = isShopee ? 'shopee' : 'tiktok';
    final cacheKey = '${platform}_level4_$parentId';
    if (_categoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _level4Categories = List.from(_categoryCache[cacheKey]!);
          _level5Categories.clear();
          _brands.clear();
          widget.formData.level3Name = parentName;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingLevel4 = true;
          _level4Categories.clear();
          _level5Categories.clear();
          _brands.clear();
          widget.formData.level3Name = parentName;
        });
      }

      List<Map<String, dynamic>> categories = [];

      if (isShopee) {
        final parent = _level3Categories.firstWhere(
          (cat) => (cat['id'] ?? cat['category_id'])?.toString() == parentId,
          orElse: () => {},
        );

        if (parent.isNotEmpty && parent['children'] != null) {
          categories = (parent['children'] as List).map((item) {
            final copy = Map<String, dynamic>.from(item);
            if (item['children'] != null) {
              copy['children'] = List<Map<String, dynamic>>.from(
                (item['children'] as List).map((child) => Map<String, dynamic>.from(child))
              );
            }
            return copy;
          }).toList();
        }
      } else {
        final response = await _apiService.getChildCategories(widget.shopId, parentId);
        if (!mounted) return;

        if (response is Map<String, dynamic> &&
            response['success'] == true &&
            response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            categories = List<Map<String, dynamic>>.from(
                data.map((item) => Map<String, dynamic>.from(item)));
          }
        }
      }

      _categoryCache[cacheKey] = categories;

      if (mounted) {
        setState(() {
          _level4Categories = categories;
        });
      }
    } catch (e) {
      if (mounted) _showError('Gagal memuat kategori level 4: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevel4 = false);
    }
  }

  Future<void> _loadLevel5CategoriesIfNeeded(
      String parentId, String parentName) async {
    if (!mounted || _isLoadingLevel5) return;

    final platform = isShopee ? 'shopee' : 'tiktok';
    final cacheKey = '${platform}_level5_$parentId';
    if (_categoryCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _level5Categories = List.from(_categoryCache[cacheKey]!);
          _brands.clear();
          widget.formData.level4Name = parentName;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoadingLevel5 = true;
          _level5Categories.clear();
          _brands.clear();
          widget.formData.level4Name = parentName;
        });
      }

      List<Map<String, dynamic>> categories = [];

      if (isShopee) {
        final parent = _level4Categories.firstWhere(
          (cat) => (cat['id'] ?? cat['category_id'])?.toString() == parentId,
          orElse: () => {},
        );

        if (parent.isNotEmpty && parent['children'] != null) {
          categories = List<Map<String, dynamic>>.from(
            (parent['children'] as List).map((item) => Map<String, dynamic>.from(item))
          );
        }
      } else {
        final response = await _apiService.getChildCategories(widget.shopId, parentId);
        if (!mounted) return;

        if (response is Map<String, dynamic> &&
            response['success'] == true &&
            response['data'] != null) {
          final data = response['data'];
          if (data is List) {
            categories = List<Map<String, dynamic>>.from(
                data.map((item) => Map<String, dynamic>.from(item)));
          }
        }
      }

      _categoryCache[cacheKey] = categories;

      if (mounted) {
        setState(() {
          _level5Categories = categories;
        });
      }
    } catch (e) {
      if (mounted) _showError('Gagal memuat kategori level 5: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLevel5 = false);
    }
  }


  Future<void> _loadBrandsIfNeeded(
      String categoryId, String categoryName) async {
    if (!mounted || _isLoadingBrands) return;

    // Determine which level this category belongs to
    String? determineCategoryLevel(String categoryId) {
      if (widget.formData.selectedLevel5Id == categoryId) return 'level5';
      if (widget.formData.selectedLevel4Id == categoryId) return 'level4';
      if (widget.formData.selectedLevel3Id == categoryId) return 'level3';
      if (widget.formData.selectedLevel2Id == categoryId) return 'level2';
      if (widget.formData.selectedLevel1Id == categoryId) return 'level1';
      return null;
    }

    // Save category name to appropriate level
    void saveCategoryName(String categoryName) {
      final level = determineCategoryLevel(categoryId);
      switch (level) {
        case 'level5':
          widget.formData.level5Name = categoryName;
          break;
        case 'level4':
          widget.formData.level4Name = categoryName;
          break;
        case 'level3':
          widget.formData.level3Name = categoryName;
          break;
        case 'level2':
          widget.formData.level2Name = categoryName;
          break;
        case 'level1':
          widget.formData.level1Name = categoryName;
          break;
      }
    }

    // SHOPEE: Skip brands loading (Shopee doesn't use brands API)
    if (isShopee) {
      if (mounted) {
        setState(() {
          saveCategoryName(categoryName);
          _brands = []; // Empty brands for Shopee
        });
        _notifyParentCategoryComplete();
      }
      return;
    }

    // Check cache first
    final cacheKey = 'brands_$categoryId';
    if (_brandCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _brands = List.from(_brandCache[cacheKey]!);
          saveCategoryName(categoryName);

          // Set default brand if not already set
          if (widget.formData.selectedBrandId == null && _brands.isNotEmpty) {
            final noBrandOption = _brands.firstWhere(
              (brand) => brand['id'] == 'no_brand',
              orElse: () => _brands.first,
            );
            widget.formData.selectedBrandId = noBrandOption['id']?.toString();
          }
        });

        _notifyParentCategoryComplete();
      }
      return;
    }

    try {
      if (mounted) {
        setState(() => _isLoadingBrands = true);
      }

      final response =
          await _apiService.getBrands(widget.shopId, categoryId: categoryId);

      if (!mounted) return;

      List<Map<String, dynamic>> brandsList = [];

      if (response is Map<String, dynamic> &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'];
        if (data is List) {
          brandsList = List<Map<String, dynamic>>.from(
              data.map((item) => Map<String, dynamic>.from(item)));
        }
      }

      
      // Remove any existing fallback brands first to prevent duplicates
      brandsList.removeWhere((brand) =>
          brand['id'] == 'no_brand' || brand['id'] == 'add_new_brand');

      // Add fallback brands at the beginning
      brandsList.insertAll(0, [
        {'id': 'no_brand', 'name': 'Tidak Ada Merek', 'is_custom': true},
        {
          'id': 'add_new_brand',
          'name': 'Tambahkan merek baru',
          'is_custom': true
        },
      ]);

      _brandCache[cacheKey] = brandsList;

      if (mounted) {
        setState(() {
          _brands = brandsList;
          saveCategoryName(categoryName);

          // Set default brand if not set
          if (widget.formData.selectedBrandId == null) {
            final noBrandOption = _brands.firstWhere(
              (brand) => brand['id'] == 'no_brand',
              orElse: () => _brands.first,
            );
            widget.formData.selectedBrandId = noBrandOption['id']?.toString();
          }
        });

        _notifyParentCategoryComplete();
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal memuat merek: $e');
        setState(() {
          _brands = [
            {'id': 'no_brand', 'name': 'Tidak Ada Merek', 'is_custom': true},
            {
              'id': 'add_new_brand',
              'name': 'Tambahkan merek baru',
              'is_custom': true
            },
          ];
          widget.formData.selectedBrandId = 'no_brand';
          saveCategoryName(categoryName);
        });

        _notifyParentCategoryComplete();
      }
    } finally {
      if (mounted) setState(() => _isLoadingBrands = false);
    }
  }


  void _notifyParentCategoryComplete() {
    // Use post-frame callback to ensure state is fully updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('   L1: ${widget.formData.selectedLevel1Id}');
        print('   L2: ${widget.formData.selectedLevel2Id}');
        print('   L3: ${widget.formData.selectedLevel3Id}');
        print('   L4: ${widget.formData.selectedLevel4Id}');
        print('   L5: ${widget.formData.selectedLevel5Id}');
        print('   Brand: ${widget.formData.selectedBrandId}');

        widget.onCategoryChanged(
          widget.formData.selectedLevel1Id,
          widget.formData.selectedLevel2Id,
          widget.formData.selectedLevel3Id,
        );
      }
    });
  }

  // IMPROVED: Manual load methods with proper state management
  Future<void> _loadLevel2Categories(String parentId, String parentName) async {
    // Clear dependent data FIRST
    setState(() {
      widget.formData.selectedLevel2Id = null;
      widget.formData.selectedLevel3Id = null;
      widget.formData.selectedBrandId = null;
      widget.formData.clearCategoryData();
    });

    // Then load data
    await _loadLevel2CategoriesIfNeeded(parentId, parentName);
  }

  Future<void> _loadLevel3Categories(String parentId, String parentName) async {
    // Clear dependent data FIRST
    setState(() {
      widget.formData.selectedLevel3Id = null;
      widget.formData.selectedBrandId = null;
      widget.formData.clearCategoryData();
    });

    // Then load data
    await _loadLevel3CategoriesIfNeeded(parentId, parentName);
  }

  Future<void> _loadLevel4Categories(String parentId, String parentName) async {
    // Clear dependent data FIRST
    setState(() {
      widget.formData.selectedLevel4Id = null;
      widget.formData.selectedLevel5Id = null;
      widget.formData.selectedBrandId = null;
      widget.formData.clearCategoryData();
    });

    // Then load data
    await _loadLevel4CategoriesIfNeeded(parentId, parentName);
  }

  Future<void> _loadLevel5Categories(String parentId, String parentName) async {
    // Clear dependent data FIRST
    setState(() {
      widget.formData.selectedLevel5Id = null;
      widget.formData.selectedBrandId = null;
      widget.formData.clearCategoryData();
    });

    // Then load data
    await _loadLevel5CategoriesIfNeeded(parentId, parentName);
  }

  Future<void> _loadBrands(String categoryId, String categoryName) async {
    // Clear dependent data FIRST
    // Only clear levels DEEPER than the current selection to avoid clearing the selected category
    setState(() {
      // Determine which level is being selected
      final isLevel5 = widget.formData.selectedLevel5Id == categoryId;
      final isLevel4 = !isLevel5 && widget.formData.selectedLevel4Id == categoryId;
      final isLevel3 = !isLevel5 && !isLevel4 && widget.formData.selectedLevel3Id == categoryId;
      final isLevel2 = !isLevel5 && !isLevel4 && !isLevel3 && widget.formData.selectedLevel2Id == categoryId;

      // Clear only deeper levels than current selection
      if (isLevel2) {
        // Level 2 selected  clear level 3, 4, 5
        widget.formData.selectedLevel3Id = null;
        widget.formData.selectedLevel4Id = null;
        widget.formData.selectedLevel5Id = null;
      } else if (isLevel3) {
        // Level 3 selected  clear level 4, 5
        widget.formData.selectedLevel4Id = null;
        widget.formData.selectedLevel5Id = null;
      } else if (isLevel4) {
        // Level 4 selected  clear level 5 only
        widget.formData.selectedLevel5Id = null;
      }
      // If level 5, don't clear anything

      widget.formData.selectedBrandId = null;
      widget.formData.clearCategoryData();
    });

    // Then load data
    await _loadBrandsIfNeeded(categoryId, categoryName);
  }

  void _showAddNewBrandDialog() {
    final TextEditingController brandController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_business, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Tambahkan Merek Baru'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brandController,
              decoration: InputDecoration(
                labelText: 'Nama Merek',
                hintText: 'Masukkan nama merek baru',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Merek ini akan ditambahkan ke daftar lokal dan hanya tersedia untuk produk ini.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset to previous valid value
              if (mounted) {
                setState(() {
                  widget.formData.selectedBrandId = 'no_brand';
                });
              }
            },
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final brandName = brandController.text.trim();
              if (brandName.isNotEmpty) {
                final newBrand = {
                  'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  'name': brandName,
                  'is_custom': true,
                  'is_user_added': true,
                };

                if (mounted) {
                  setState(() {
                    _brands.insert(2, newBrand);
                    widget.formData.selectedBrandId =
                        newBrand['id']?.toString();
                  });
                }

                Navigator.pop(context);
                _showSnackBar(
                    'Merek "$brandName" berhasil ditambahkan', Color(0xFF2196F3));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
            child: Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    _showSnackBar(message, Colors.red);
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Kategori',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
        SizedBox(height: 8),

        // Level 1 Categories
        _buildDropdown(
          key: ValueKey('level1_${_level1Categories.length}'),
          value: widget.formData.selectedLevel1Id,
          hint: 'Pilih kategori utama',
          title: 'Kategori Utama',
          icon: Icons.category_outlined,
          items: _level1Categories,
          isLoading: _isLoadingLevel1,
          onChanged: (value) {
            if (value != null && value != widget.formData.selectedLevel1Id) {
              setState(() {
                widget.formData.selectedLevel1Id = value;
                widget.formData.selectedLevel2Id = null;
                widget.formData.selectedLevel3Id = null;
                widget.formData.selectedLevel4Id = null;
                widget.formData.selectedLevel5Id = null;
              });
              final selectedCategory = _level1Categories.firstWhere(
                  (cat) => cat['id']?.toString() == value,
                  orElse: () => <String, dynamic>{});
              final categoryName = selectedCategory['local_name']?.toString() ??
                  selectedCategory['name']?.toString() ??
                  'Unknown';

              // For TikTok: always load level 2 (flat structure, no has_children field)
              // For Shopee: check has_children or children array (nested structure)
              if (isTikTok) {
                // TikTok: Always try to load level 2, API will return empty if no children
                _loadLevel2Categories(value, categoryName);
              } else {
                // Shopee: Check if category has children before loading
                final hasChildren = selectedCategory['has_children'] == true ||
                    (selectedCategory['children'] != null &&
                        selectedCategory['children'].isNotEmpty);

                if (hasChildren) {
                  _loadLevel2Categories(value, categoryName);
                } else {
                  // Level 1 leaf category (rare but possible) - clear all child levels
                  setState(() {
                    _level2Categories.clear();
                    _level3Categories.clear();
                    _level4Categories.clear();
                    _level5Categories.clear();
                    widget.formData.categoryHasChildren = false;
                  });
                  _loadBrands(value, categoryName);
                }
              }
            }
          },
        ),

        // Level 2 Categories
        if (widget.formData.selectedLevel1Id != null) ...[
          SizedBox(height: 12),
          _buildDropdown(
            key: ValueKey(
                'level2_${widget.formData.selectedLevel1Id}_${_level2Categories.length}'),
            value: widget.formData.selectedLevel2Id,
            hint: 'Pilih subkategori',
            title: 'Subkategori',
            icon: Icons.category,
            items: _level2Categories,
            isLoading: _isLoadingLevel2,
            onChanged: (value) {
              if (value != null && value != widget.formData.selectedLevel2Id) {
                setState(() {
                  widget.formData.selectedLevel2Id = value;
                  widget.formData.selectedLevel3Id = null;
                  widget.formData.selectedLevel4Id = null;
                  widget.formData.selectedLevel5Id = null;
                });
                final selectedCategory = _level2Categories.firstWhere(
                    (cat) => cat['id']?.toString() == value,
                    orElse: () => <String, dynamic>{});
                final categoryName =
                    selectedCategory['local_name']?.toString() ??
                        selectedCategory['name']?.toString() ??
                        'Unknown';

                // For TikTok: always load level 3 (flat structure)
                // For Shopee: check has_children (nested structure)
                if (isTikTok) {
                  _loadLevel3Categories(value, categoryName);
                } else {
                  final hasChildren = selectedCategory['has_children'] == true ||
                      (selectedCategory['children'] != null &&
                          selectedCategory['children'].isNotEmpty);

                  if (hasChildren) {
                    _loadLevel3Categories(value, categoryName);
                  } else {
                    // Level 2 leaf category - clear all child levels
                    setState(() {
                      _level3Categories.clear();
                      _level4Categories.clear();
                      _level5Categories.clear();
                      widget.formData.categoryHasChildren = false;
                    });
                    _loadBrands(value, categoryName);
                  }
                }
              }
            },
          ),
        ],

        // Level 3 Categories
        if (widget.formData.selectedLevel2Id != null && _level3Categories.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDropdown(
            key: ValueKey(
                'level3_${widget.formData.selectedLevel2Id}_${_level3Categories.length}'),
            value: widget.formData.selectedLevel3Id,
            hint: 'Pilih kategori level 3',
            title: 'Kategori Level 3',
            icon: Icons.category_rounded,
            items: _level3Categories,
            isLoading: _isLoadingLevel3,
            onChanged: (value) {
              if (value != null && value != widget.formData.selectedLevel3Id) {
                setState(() {
                  widget.formData.selectedLevel3Id = value;
                  widget.formData.selectedLevel4Id = null;
                  widget.formData.selectedLevel5Id = null;
                });
                final selectedCategory = _level3Categories.firstWhere(
                    (cat) => cat['id']?.toString() == value,
                    orElse: () => <String, dynamic>{});
                final categoryName =
                    selectedCategory['local_name']?.toString() ??
                        selectedCategory['name']?.toString() ??
                        'Unknown';
                final hasChildren = selectedCategory['has_children'] == true ||
                    (selectedCategory['children'] != null &&
                        selectedCategory['children'].isNotEmpty);

                if (hasChildren) {
                  _loadLevel4Categories(value, categoryName);
                } else {
                  widget.formData.categoryHasChildren = false;
                  _loadBrands(value, categoryName);
                }
              }
            },
          ),
        ],

        // Level 4 Categories
        if (widget.formData.selectedLevel3Id != null && _level4Categories.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDropdown(
            key: ValueKey(
                'level4_${widget.formData.selectedLevel3Id}_${_level4Categories.length}'),
            value: widget.formData.selectedLevel4Id,
            hint: 'Pilih kategori level 4',
            title: 'Kategori Level 4',
            icon: Icons.category_rounded,
            items: _level4Categories,
            isLoading: _isLoadingLevel4,
            onChanged: (value) {
              if (value != null && value != widget.formData.selectedLevel4Id) {
                setState(() {
                  widget.formData.selectedLevel4Id = value;
                  widget.formData.selectedLevel5Id = null;
                });
                final selectedCategory = _level4Categories.firstWhere(
                    (cat) => cat['id']?.toString() == value,
                    orElse: () => <String, dynamic>{});
                final categoryName =
                    selectedCategory['local_name']?.toString() ??
                        selectedCategory['name']?.toString() ??
                        'Unknown';
                final hasChildren = selectedCategory['has_children'] == true ||
                    (selectedCategory['children'] != null &&
                        selectedCategory['children'].isNotEmpty);

                if (hasChildren) {
                  _loadLevel5Categories(value, categoryName);
                } else {
                  widget.formData.categoryHasChildren = false;
                  _loadBrands(value, categoryName);
                }
              }
            },
          ),
        ],

        // Level 5 Categories (deepest level)
        if (widget.formData.selectedLevel4Id != null && _level5Categories.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildDropdown(
            key: ValueKey(
                'level5_${widget.formData.selectedLevel4Id}_${_level5Categories.length}'),
            value: widget.formData.selectedLevel5Id,
            hint: 'Pilih kategori akhir',
            title: 'Kategori Akhir',
            icon: Icons.category_rounded,
            items: _level5Categories,
            isLoading: _isLoadingLevel5,
            onChanged: (value) {
              if (value != null && value != widget.formData.selectedLevel5Id) {
                setState(() {
                  widget.formData.selectedLevel5Id = value;
                });
                final selectedCategory = _level5Categories.firstWhere(
                    (cat) => cat['id']?.toString() == value,
                    orElse: () => <String, dynamic>{});
                final categoryName =
                    selectedCategory['local_name']?.toString() ??
                        selectedCategory['name']?.toString() ??
                        'Unknown';
                widget.formData.categoryHasChildren = false;
                _loadBrands(value, categoryName);
              }
            },
          ),
        ],

        // Brand Selection - ONLY FOR TIKTOK (Shopee uses brand in attributes)
        if (isTikTok && widget.formData.selectedLevel3Id != null) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Merek',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
            ],
          ),
          SizedBox(height: 8),
          _buildBrandDropdown(),
        ],

        // Category Path Display
        if (widget.formData.selectedLevel1Id != null) ...[
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kategori: ${widget.formData.level1Name}'
                    '${widget.formData.level2Name.isNotEmpty ? ' > ${widget.formData.level2Name}' : ''}'
                    '${widget.formData.level3Name.isNotEmpty ? ' > ${widget.formData.level3Name}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown({
    Key? key,
    required String? value,
    required String hint,
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required bool isLoading,
    required Function(String?) onChanged,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      child: isLoading
          ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Memuat...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                _showCategoryDialog(
                  title: title,
                  icon: icon,
                  items: items,
                  currentValue: value,
                  onChanged: onChanged,
                );
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: value != null ? Color(0xFF3949AB) : Colors.grey[400], size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getCategoryDisplayName(value, items, hint),
                        style: TextStyle(
                          color: value != null ? Color(0xFF2D3436) : Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
    );
  }

  String _getCategoryDisplayName(String? value, List<Map<String, dynamic>> items, String hint) {
    if (value == null) return hint;
    final item = items.firstWhere(
      (item) => item['id']?.toString() == value,
      orElse: () => {},
    );
    if (item.isEmpty) return hint;
    return item['local_name']?.toString() ?? item['name']?.toString() ?? hint;
  }

  void _showCategoryDialog({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String? currentValue,
    required Function(String?) onChanged,
  }) {
    String? tempSelected = currentValue;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                          Icon(icon, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${items.length} opsi tersedia',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Options List
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        children: items.map((item) {
                          final id = item['id']?.toString() ?? '';
                          final name = item['local_name']?.toString() ?? item['name']?.toString() ?? 'Unknown';
                          final isSelected = tempSelected == id;
                          return InkWell(
                            onTap: () {
                              setDialogState(() => tempSelected = id);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3949AB).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.category, color: Color(0xFF3949AB), size: 20),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
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
                      ),
                    ),
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
                              if (tempSelected != null) {
                                onChanged(tempSelected);
                              }
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

  Widget _buildBrandDropdown() {
    return Container(
      key: ValueKey(
          'brand_dropdown_${widget.formData.selectedLevel3Id}_${_brands.length}_${widget.formData.selectedBrandId}'),
      width: double.infinity,
      child: _isLoadingBrands
          ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Memuat merek...',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
          : InkWell(
              onTap: () {
                FocusScope.of(context).unfocus();
                _showBrandDialog();
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getBrandIcon(),
                      color: widget.formData.selectedBrandId != null ? Color(0xFF3949AB) : Colors.grey[400],
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getBrandDisplayName(),
                        style: TextStyle(
                          color: widget.formData.selectedBrandId != null ? Color(0xFF2D3436) : Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getBrandIcon() {
    if (widget.formData.selectedBrandId == null) return Icons.branding_watermark;
    if (widget.formData.selectedBrandId == 'no_brand') return Icons.block;
    if (widget.formData.selectedBrandId == 'add_new_brand') return Icons.add;
    return Icons.branding_watermark;
  }

  String _getBrandDisplayName() {
    if (widget.formData.selectedBrandId == null) return 'Pilih merek';
    final brand = _brands.firstWhere(
      (b) => b['id']?.toString() == widget.formData.selectedBrandId,
      orElse: () => {},
    );
    if (brand.isEmpty) return 'Pilih merek';
    return brand['name']?.toString() ?? 'Unknown Brand';
  }

  void _showBrandDialog() {
    String? tempSelected = widget.formData.selectedBrandId;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                          Icon(Icons.branding_watermark, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pilih Merek Produk',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${_brands.length} opsi tersedia',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Options List
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        children: _brands.map((brand) {
                          final id = brand['id']?.toString() ?? '';
                          final name = brand['name']?.toString() ?? 'Unknown Brand';
                          final isCustom = brand['is_custom'] == true;
                          final isSelected = tempSelected == id;

                          IconData icon;
                          Color iconColor;
                          if (id == 'no_brand') {
                            icon = Icons.block;
                            iconColor = Colors.orange;
                          } else if (id == 'add_new_brand') {
                            icon = Icons.add_circle;
                            iconColor = Color(0xFF4CAF50);
                          } else {
                            icon = Icons.branding_watermark;
                            iconColor = Color(0xFF3949AB);
                          }

                          return InkWell(
                            onTap: () {
                              if (id == 'add_new_brand') {
                                Navigator.pop(dialogContext);
                                _showAddNewBrandDialog();
                              } else {
                                setDialogState(() => tempSelected = id);
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              color: isSelected ? Color(0xFF3949AB).withOpacity(0.1) : Colors.transparent,
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(icon, color: iconColor, size: 20),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : (isCustom ? FontWeight.w600 : FontWeight.w500),
                                        color: isSelected ? Color(0xFF3949AB) : (isCustom ? iconColor : Color(0xFF2D3436)),
                                      ),
                                    ),
                                  ),
                                  if (isSelected && id != 'add_new_brand')
                                    Icon(Icons.check_circle, color: Color(0xFF3949AB), size: 24),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
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
                              if (tempSelected != null) {
                                setState(() {
                                  widget.formData.selectedBrandId = tempSelected;
                                });
                              }
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
}
