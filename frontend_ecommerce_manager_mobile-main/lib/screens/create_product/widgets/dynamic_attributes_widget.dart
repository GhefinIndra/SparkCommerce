// Updated DynamicAttributesWidget - integrated with category rules
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../models/category_attribute.dart';
import '../models/product_form_data.dart';

class DynamicAttributesWidget extends StatefulWidget {
  final String shopId;
  final String? platform; // 'TikTok Shop' or 'Shopee' - optional for backward compatibility
  final ProductFormData formData;
  final VoidCallback? onChanged;

  const DynamicAttributesWidget({
    Key? key,
    required this.shopId,
    this.platform,
    required this.formData,
    this.onChanged,
  }) : super(key: key);

  @override
  _DynamicAttributesWidgetState createState() =>
      _DynamicAttributesWidgetState();
}

class _DynamicAttributesWidgetState extends State<DynamicAttributesWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Platform detection helper
  bool get isShopee => widget.platform?.toLowerCase().contains('shopee') ?? false;
  bool get isTikTok => widget.platform?.toLowerCase().contains('tiktok') ?? true; // Default to TikTok for backward compatibility

  final ApiService _apiService = ApiService();
  bool _isLoadingAttributes = false;
  bool _isLoadingCategoryRules = false;
  String? _lastCategoryId;

  // Cache untuk mencegah reload berulang
  static final Map<String, List<CategoryAttribute>> _attributeCache = {};

  @override
  void initState() {
    super.initState();
    // DON'T set _lastCategoryId here - let it remain null so didUpdateWidget will trigger on first build
    // This ensures attributes are loaded even when widget is created with category already selected

    print(' DynamicAttributes.initState: categoryId=${widget.formData.selectedCategoryId}');

    if (widget.formData.selectedCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print(' DynamicAttributes.initState postFrameCallback: Loading data...');
        _loadCategoryData().then((_) {
          // Set _lastCategoryId AFTER loading completes to prevent didUpdateWidget from skipping
          _lastCategoryId = widget.formData.selectedCategoryId;
        });
      });
    }
  }

  @override
  void didUpdateWidget(DynamicAttributesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Use selectedCategoryId getter to support dynamic category depth (1-5 levels)
    final currentCategoryId = widget.formData.selectedCategoryId;

    print(' DynamicAttributes.didUpdateWidget:');
    print('   Platform: ${isShopee ? "Shopee" : "TikTok"}');
    print('   Last category: $_lastCategoryId');
    print('   Current category: $currentCategoryId');
    print('   L1: ${widget.formData.selectedLevel1Id}');
    print('   L2: ${widget.formData.selectedLevel2Id}');
    print('   L3: ${widget.formData.selectedLevel3Id}');
    print('   L4: ${widget.formData.selectedLevel4Id}');
    print('   L5: ${widget.formData.selectedLevel5Id}');

    if (_lastCategoryId != currentCategoryId) {
      print(
          ' DynamicAttributes: Category changed from $_lastCategoryId to $currentCategoryId');
      _lastCategoryId = currentCategoryId;

      if (currentCategoryId != null && currentCategoryId.isNotEmpty) {
        setState(() {
          widget.formData.categoryAttributes.clear();
          widget.formData.selectedAttributes.clear();
          widget.formData.clearCategoryRulesData();
        });
        _loadCategoryData();
      } else {
        setState(() {
          widget.formData.categoryAttributes.clear();
          widget.formData.selectedAttributes.clear();
          widget.formData.clearCategoryRulesData();
        });
      }
    } else {
      print('   ️ Category unchanged, skipping reload');
    }
  }

  Future<void> _loadCategoryData() async {
    if (widget.formData.selectedCategoryId == null || !mounted) {
      print('️ DynamicAttributes._loadCategoryData: Skipped (categoryId=${widget.formData.selectedCategoryId}, mounted=$mounted)');
      return;
    }

    final categoryId = widget.formData.selectedCategoryId!;
    print(' DynamicAttributes._loadCategoryData: Starting for category $categoryId (${isShopee ? "Shopee" : "TikTok"})');

    // Load attributes and rules (TikTok only has rules)
    if (isShopee) {
      // Shopee: Only load attributes
      await _loadCategoryAttributes();
    } else {
      // TikTok: Load both attributes and category rules
      await Future.wait([
        _loadCategoryAttributes(),
        _loadCategoryRules(),
      ]);
    }

    widget.onChanged?.call();
  }

  Future<void> _loadCategoryAttributes() async {
    if (widget.formData.selectedCategoryId == null || !mounted) return;

    final categoryId = widget.formData.selectedCategoryId!;
    final cacheKey = '${isShopee ? "shopee" : "tiktok"}_$categoryId';

    print(' DynamicAttributes._loadCategoryAttributes: category=$categoryId, cacheKey=$cacheKey');

    // Check cache first
    if (_attributeCache.containsKey(cacheKey)) {
      print(' Attributes loaded from cache: ${_attributeCache[cacheKey]!.length} attributes');
      setState(() {
        widget.formData.categoryAttributes =
            List.from(_attributeCache[cacheKey]!);
        widget.formData.selectedAttributes.clear();
      });
      return;
    }

    try {
      setState(() => _isLoadingAttributes = true);

      print(' Calling API: ${isShopee ? "getShopeeCategoryAttributes" : "getCategoryAttributes"}($categoryId)');

      final response = isShopee
          ? await _apiService.getShopeeCategoryAttributes(
              widget.shopId,
              int.parse(categoryId),
            )
          : await _apiService.getCategoryAttributes(
              widget.shopId,
              categoryId,
            );

      if (!mounted) return;

      if (response is Map<String, dynamic> &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'];

        List<CategoryAttribute> attributes = [];

        if (isShopee) {
          // Shopee response structure: data.attributes (array)
          if (data is Map && data['attributes'] != null) {
            final attrList = data['attributes'] as List;
            attributes = attrList.map((attr) => CategoryAttribute.fromJson(attr)).toList();
          }
        } else {
          // TikTok response structure: data (array directly)
          if (data is List) {
            attributes = data.map((attr) => CategoryAttribute.fromJson(attr)).toList();
          }
        }

        print(' Loaded ${attributes.length} attributes for category $categoryId');

        // Only cache if we got attributes (don't cache empty results)
        if (attributes.isNotEmpty) {
          _attributeCache[cacheKey] = List.from(attributes);
          print(' Cached ${attributes.length} attributes with key: $cacheKey');
        } else {
          print('️ NOT caching empty attributes for category $categoryId');
        }

        setState(() {
          widget.formData.categoryAttributes = attributes;
          widget.formData.selectedAttributes.clear();
        });
      }
    } catch (e) {
      print('️ Error loading attributes: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAttributes = false);
    }
  }

  Future<void> _loadCategoryRules() async {
    if (widget.formData.selectedCategoryId == null || !mounted) return;

    try {
      setState(() => _isLoadingCategoryRules = true);

      final response = await _apiService.getCategoryRulesWithSizeChart(
        widget.shopId,
        widget.formData.selectedCategoryId!,
      );

      if (!mounted) return;

      if (response is Map<String, dynamic> &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;

        // Gabungkan rules dengan size_chart info dari backend
        Map<String, dynamic> combinedRules = {};

        if (data['rules'] != null && data['rules'] is Map<String, dynamic>) {
          combinedRules.addAll(data['rules'] as Map<String, dynamic>);
        }

        if (data['size_chart'] != null &&
            data['size_chart'] is Map<String, dynamic>) {
          combinedRules['size_chart'] = data['size_chart'];
        }

        if (data['category_id'] != null) {
          combinedRules['category_id'] = data['category_id'];
        }

        setState(() {
          widget.formData.updateCategoryRules(combinedRules);
        });

        print(
            ' Category rules loaded: size_chart_required=${widget.formData.sizeChartRequired}');
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoadingCategoryRules = false);
    }
  }

  void _updateAttribute(
    String attributeId, {
    List<String>? valueIds,
    String? customValue,
    bool clearValues = false,
  }) {
    setState(() {
      widget.formData.updateAttribute(
        attributeId,
        valueIds: clearValues ? [] : valueIds,
        customValue: customValue,
      );
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Use selectedCategoryId to support dynamic category depth (1-5 levels)
    if (widget.formData.selectedCategoryId == null) {
      return _buildPlaceholder(
          'Pilih kategori terlebih dahulu untuk melihat atribut produk');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loading indicators
        if (_isLoadingAttributes || _isLoadingCategoryRules)
          _buildLoadingIndicator(),

        // Brand selection (if available)
        if (widget.formData.categoryAttributes.isNotEmpty) _buildBrandSection(),

        // Attributes
        if (!_isLoadingAttributes) ...[
          if (widget.formData.categoryAttributes.isEmpty)
            _buildNoAttributesMessage()
          else
            ..._buildAttributeFields(),
        ],

        // Category Rules - Certifications only (Size Chart moved to Detail Produk section)
        if (!_isLoadingCategoryRules &&
            widget.formData.categoryRulesLoaded) ...[
          // Other category rules can be added here
          if (widget.formData.certificationsRequired) ...[
            SizedBox(height: 24),
            _buildCertificationsSection(),
          ],
        ],
      ],
    );
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFF2196F3),
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _isLoadingAttributes
                  ? 'Memuat atribut kategori...'
                  : 'Memuat persyaratan kategori...',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAttributesMessage() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tidak ada atribut khusus untuk kategori ini',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSection() {
    // Build brand items
    final brandItems = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: 'no_brand',
        child: Text('Tidak Bermerek'),
      ),
      
      DropdownMenuItem<String>(
        value: 'add_new_brand',
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Tambah Merek Baru',
                style: TextStyle(color: Color(0xFF2196F3))),
          ],
        ),
      ),
    ];

    // Validate that selectedBrandId exists in items (or is null)
    String? validatedBrandValue;
    if (widget.formData.selectedBrandId != null &&
        brandItems.any((item) => item.value == widget.formData.selectedBrandId)) {
      validatedBrandValue = widget.formData.selectedBrandId;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merek',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: validatedBrandValue,
              hint: Text('Pilih merek',
                  style: TextStyle(color: Colors.grey[500])),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.all(16),
                filled: true,
                fillColor: Colors.transparent,
              ),
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              items: brandItems,
              onChanged: (value) {
                if (value == 'add_new_brand') {
                  _showCreateBrandDialog();
                } else {
                  setState(() {
                    widget.formData.selectedBrandId = value;
                  });
                  widget.onChanged?.call();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAttributeFields() {
    // Use sorted attributes (trigger attributes for certifications first)
    final attributes = widget.formData.sortedCategoryAttributes;
    return List.generate(attributes.length, (index) {
      final attribute = attributes[index];
      // Use index as fallback if attribute.id is empty to prevent duplicate keys
      final uniqueKey = attribute.id.isNotEmpty
          ? 'attribute_${attribute.id}'
          : 'attribute_index_$index';

      return Container(
        key: ValueKey(uniqueKey),
        margin: EdgeInsets.only(bottom: 20),
        child: _buildAttributeField(attribute),
      );
    });
  }

  Widget _buildAttributeField(CategoryAttribute attribute) {
    // Special card for required attributes
    if (attribute.isRequired) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2196F3).withOpacity(0.1),
              Color(0xFF2196F3).withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF2196F3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF2196F3).withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attribute.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'WAJIB',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _buildAttributeInput(attribute),
            ),
          ],
        ),
      );
    }

    // Regular card for optional attributes
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttributeLabel(attribute),
        SizedBox(height: 10),
        _buildAttributeInput(attribute),
      ],
    );
  }

  Widget _buildAttributeLabel(CategoryAttribute attribute) {
    return Row(
      children: [
        Text(
          attribute.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3436),
          ),
        ),
        if (attribute.isRequired)
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
    );
  }

  Widget _buildAttributeInput(CategoryAttribute attribute) {
    // Check if this is a date input (Shopee sends input_type as string in transformed response)
    if (attribute.inputType == '3' && attribute.name.toLowerCase().contains('date')) {
      return _buildDatePicker(attribute);
    }

    // Combo box: dropdown + custom input option
    if (attribute.type == 'COMBO_BOX' || attribute.isCustomizable) {
      return _buildComboBox(attribute);
    }

    // Regular logic
    if (attribute.values.isEmpty) {
      return _buildTextInput(attribute);
    } else if (attribute.isMultipleSelection) {
      return _buildMultipleSelection(attribute);
    } else {
      return _buildDropdown(attribute);
    }
  }

  Widget _buildTextInput(CategoryAttribute attribute) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        initialValue: selected?.customValue ?? '',
        decoration: InputDecoration(
          hintText: 'Masukkan ${attribute.name.toLowerCase()}',
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.all(16),
          filled: true,
          fillColor: Colors.transparent,
        ),
        onChanged: (value) {
          _updateAttribute(attribute.id, customValue: value);
        },
        validator: attribute.isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '${attribute.name} wajib diisi';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdown(CategoryAttribute attribute) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);
    final selectedValue =
        selected?.valueIds.isNotEmpty == true ? selected!.valueIds.first : null;

    // Get selected value name for display
    String? selectedName;
    if (selectedValue != null && selectedValue.isNotEmpty && selectedValue != 'custom') {
      final selectedAttr = attribute.values.firstWhere(
        (v) => v.id == selectedValue,
        orElse: () => AttributeValue(id: '', name: ''),
      );
      selectedName = selectedAttr.name.isNotEmpty ? selectedAttr.name : null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Single-select dropdown button
        InkWell(
          onTap: () => _showSingleSelectDialog(attribute, selected),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: attribute.isRequired && selectedValue == null
                    ? Colors.red[300]!
                    : Colors.grey[300]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radio_button_checked_rounded,
                  color: selectedName != null ? Color(0xFF3949AB) : Colors.grey[400],
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedName ?? 'Pilih ${attribute.name.toLowerCase()}',
                    style: TextStyle(
                      color: selectedName != null ? Colors.grey[800] : Colors.grey[500],
                      fontSize: 14,
                      fontWeight: selectedName != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),

        // Custom value display
        if (selected?.customValue?.isNotEmpty == true)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFF3949AB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFF3949AB).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 12, color: Color(0xFF3949AB)),
                  SizedBox(width: 6),
                  Text(
                    'Custom: ${selected!.customValue}',
                    style: TextStyle(
                      color: Color(0xFF3949AB),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _updateAttribute(attribute.id, valueIds: [], customValue: '');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF3949AB),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Validation error
        if (attribute.isRequired && selectedValue == null)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Pilih ${attribute.name.toLowerCase()}',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // Show single-select dialog with premium UI/UX
  void _showSingleSelectDialog(
    CategoryAttribute attribute,
    SelectedAttribute? selected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String? tempSelected = selected?.valueIds.isNotEmpty == true
            ? selected!.valueIds.first
            : null;
        bool hasCustom = selected?.customValue?.isNotEmpty == true;
        String searchQuery = '';

        // Filter values based on search
        List<AttributeValue> getFilteredValues() {
          if (searchQuery.isEmpty) return attribute.values;
          return attribute.values.where((v) {
            return v.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredValues = getFilteredValues();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 600),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.radio_button_checked_rounded, color: Colors.white, size: 24),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilih ${attribute.name}',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Pilih salah satu opsi',
                                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),

                          // Search Bar
                          if (attribute.values.length > 5) ...[
                            SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                onChanged: (value) => setDialogState(() => searchQuery = value),
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cari...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                  prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.9)),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.9)),
                                          onPressed: () => setDialogState(() => searchQuery = ''),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Clear Selection Button
                    if (tempSelected != null || hasCustom)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  tempSelected = null;
                                  hasCustom = false;
                                });
                              },
                              icon: Icon(Icons.clear, size: 16),
                              label: Text('Hapus Pilihan'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Content List
                    Flexible(
                      child: filteredValues.isEmpty && searchQuery.isNotEmpty
                          ? _buildEmptyState(searchQuery)
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                // Custom option
                                if (attribute.isCustomizable)
                                  _buildRadioTile(
                                    'Lainnya (Custom)',
                                    hasCustom,
                                    () {
                                      Navigator.pop(context);
                                      _showCustomValueDialog(attribute);
                                    },
                                    isCustom: true,
                                  ),

                                // Regular options
                                ...filteredValues.map((value) {
                                  final isSelected = tempSelected == value.id;
                                  return _buildRadioTile(
                                    value.name,
                                    isSelected,
                                    () {
                                      setDialogState(() => tempSelected = value.id);
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                    ),

                    // Footer
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (tempSelected != null) {
                                  _updateAttribute(attribute.id, valueIds: [tempSelected!]);
                                }
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3949AB),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, size: 18),
                                  SizedBox(width: 8),
                                  Text('Simpan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
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

  // Build radio tile for single selection
  Widget _buildRadioTile(String title, bool isSelected, VoidCallback onTap, {bool isCustom = false}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF3949AB).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Color(0xFF3949AB).withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: RadioListTile<bool>(
        title: Row(
          children: [
            if (isCustom) ...[
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Color(0xFF3949AB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, size: 14, color: Color(0xFF3949AB)),
              ),
              SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isCustom
                      ? Color(0xFF3949AB)
                      : (isSelected ? Color(0xFF1A237E) : Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
        value: isSelected,
        groupValue: true,
        activeColor: Color(0xFF3949AB),
        onChanged: (_) => onTap(),
      ),
    );
  }

  Widget _buildMultipleSelection(CategoryAttribute attribute) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);
    final selectedValues = selected?.valueIds ?? [];

    // Get selected value names for display
    final selectedNames = attribute.values
        .where((v) => selectedValues.contains(v.id))
        .map((v) => v.name)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-select dropdown button
        InkWell(
          onTap: () => _showMultiSelectDialog(attribute, selected, selectedValues),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: attribute.isRequired && selectedValues.isEmpty
                    ? Colors.red[300]!
                    : Colors.grey[300]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  color: selectedValues.isEmpty ? Colors.grey[400] : Color(0xFF3949AB),
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedValues.isEmpty
                        ? 'Pilih ${attribute.name.toLowerCase()}'
                        : '${selectedValues.length} item dipilih',
                    style: TextStyle(
                      color: selectedValues.isEmpty ? Colors.grey[500] : Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),

        // Selected items chips
        if (selectedNames.isNotEmpty) ...[
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...selectedNames.map((name) => _buildSelectedChip(
                name,
                () {
                  // Remove this value
                  final valueId = attribute.values
                      .firstWhere((v) => v.name == name)
                      .id;
                  final newValues = List<String>.from(selectedValues)
                    ..remove(valueId);
                  _updateAttribute(
                    attribute.id,
                    valueIds: newValues,
                    customValue: selected?.customValue,
                  );
                },
              )),
              // Custom value chip
              if (selected?.customValue?.isNotEmpty == true)
                _buildSelectedChip(
                  'Custom: ${selected!.customValue}',
                  () {
                    _updateAttribute(
                      attribute.id,
                      valueIds: selectedValues,
                      customValue: '',
                    );
                  },
                  isCustom: true,
                ),
            ],
          ),
        ],

        // Validation error
        if (attribute.isRequired && selectedValues.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Pilih minimal 1 ${attribute.name.toLowerCase()}',
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  // Build combo box (dropdown + custom input)
  Widget _buildComboBox(CategoryAttribute attribute) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);
    final selectedValue =
        selected?.valueIds.isNotEmpty == true ? selected!.valueIds.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown with predefined values
        _buildDropdown(attribute),

        // "Or" separator
        if (attribute.values.isNotEmpty) ...[
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'atau',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          SizedBox(height: 12),
        ],

        // Custom input field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            initialValue: selected?.customValue ?? '',
            decoration: InputDecoration(
              hintText: 'Masukkan ${attribute.name.toLowerCase()} sendiri',
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(16),
              filled: true,
              fillColor: Colors.transparent,
            ),
            onChanged: (value) {
              // Clear dropdown selection when typing custom value
              if (value.trim().isNotEmpty) {
                _updateAttribute(attribute.id, customValue: value, clearValues: true);
              } else {
                _updateAttribute(attribute.id, customValue: value);
              }
            },
          ),
        ),
      ],
    );
  }

  // Build date picker
  Widget _buildDatePicker(CategoryAttribute attribute) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);
    final selectedDate = selected?.customValue;

    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate != null
              ? DateTime.tryParse(selectedDate) ?? DateTime.now()
              : DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );

        if (picked != null) {
          // Format: YYYY-MM-DD
          final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          _updateAttribute(attribute.id, customValue: formatted);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: attribute.isRequired && selectedDate == null
                ? Colors.red[300]!
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: selectedDate != null ? Color(0xFF3949AB) : Colors.grey[400],
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedDate ?? 'Pilih tanggal ${attribute.name.toLowerCase()}',
                style: TextStyle(
                  fontSize: 15,
                  color: selectedDate != null ? Colors.black87 : Colors.grey[500],
                ),
              ),
            ),
            if (selectedDate != null)
              IconButton(
                icon: Icon(Icons.clear, size: 20),
                onPressed: () {
                  _updateAttribute(attribute.id, customValue: '');
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  // Build selected chip
  Widget _buildSelectedChip(String label, VoidCallback onRemove, {bool isCustom = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCustom
            ? Color(0xFF3949AB).withOpacity(0.1)
            : Color(0xFF3949AB).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCustom
              ? Color(0xFF3949AB).withOpacity(0.3)
              : Color(0xFF3949AB).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom)
            Icon(Icons.edit, size: 12, color: Color(0xFF3949AB)),
          if (isCustom) SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Color(0xFF3949AB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF3949AB),
            ),
          ),
        ],
      ),
    );
  }

  // Show multi-select dialog with premium UI/UX
  void _showMultiSelectDialog(
    CategoryAttribute attribute,
    SelectedAttribute? selected,
    List<String> selectedValues,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(selectedValues);
        bool hasCustom = selected?.customValue?.isNotEmpty == true;
        String searchQuery = '';

        // Filter values based on search
        List<AttributeValue> getFilteredValues() {
          if (searchQuery.isEmpty) return attribute.values;
          return attribute.values.where((v) {
            return v.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredValues = getFilteredValues();
            final hasSelection = tempSelected.isNotEmpty || hasCustom;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header dengan Gradient
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1A237E),
                            Color(0xFF283593),
                            Color(0xFF3949AB),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.checklist_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pilih ${attribute.name}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      hasSelection
                                          ? '${tempSelected.length} item dipilih'
                                          : 'Pilih minimal 1 item',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),

                          // Search Bar
                          if (attribute.values.length > 5) ...[
                            SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  setDialogState(() => searchQuery = value);
                                },
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Cari...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: Colors.white.withOpacity(0.9),
                                          ),
                                          onPressed: () {
                                            setDialogState(() => searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Action Buttons
                    if (filteredValues.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  tempSelected = filteredValues.map((v) => v.id).toList();
                                });
                              },
                              icon: Icon(Icons.done_all, size: 16),
                              label: Text('Pilih Semua'),
                              style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF3949AB),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                            SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  tempSelected.clear();
                                  hasCustom = false;
                                });
                              },
                              icon: Icon(Icons.clear_all, size: 16),
                              label: Text('Hapus Semua'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Content List
                    Flexible(
                      child: filteredValues.isEmpty && searchQuery.isNotEmpty
                          ? _buildEmptyState(searchQuery)
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                // Custom option
                                if (attribute.isCustomizable)
                                  _buildCustomOptionTile(attribute, hasCustom, (value) {
                                    if (value == true) {
                                      Navigator.pop(context);
                                      _showCustomValueDialog(attribute, isMultiple: true);
                                    } else {
                                      setDialogState(() => hasCustom = false);
                                    }
                                  }),

                                // Regular options
                                ...filteredValues.map((value) {
                                  final isSelected = tempSelected.contains(value.id);
                                  return _buildCheckboxTile(value.name, isSelected, (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        tempSelected.add(value.id);
                                      } else {
                                        tempSelected.remove(value.id);
                                      }
                                    });
                                  });
                                }).toList(),
                              ],
                            ),
                    ),

                    // Footer
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                _updateAttribute(attribute.id, valueIds: tempSelected, customValue: selected?.customValue);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3949AB),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, size: 18),
                                  SizedBox(width: 8),
                                  Text('Simpan ${tempSelected.isNotEmpty ? "(${tempSelected.length})" : ""}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
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

  Widget _buildCustomOptionTile(CategoryAttribute attribute, bool hasCustom, Function(bool?) onChanged) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF3949AB).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasCustom ? Color(0xFF3949AB).withOpacity(0.3) : Colors.transparent),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(color: Color(0xFF3949AB).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.edit, size: 14, color: Color(0xFF3949AB)),
            ),
            SizedBox(width: 12),
            Text('Lainnya (Custom)', style: TextStyle(color: Color(0xFF3949AB), fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        value: hasCustom,
        activeColor: Color(0xFF3949AB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCheckboxTile(String title, bool isSelected, Function(bool?) onChanged) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Color(0xFF3949AB).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? Color(0xFF3949AB).withOpacity(0.2) : Colors.transparent),
      ),
      child: CheckboxListTile(
        title: Text(title, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Color(0xFF1A237E) : Colors.grey[800])),
        value: isSelected,
        activeColor: Color(0xFF3949AB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Container(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text('Tidak ditemukan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          SizedBox(height: 8),
          Text('Hasil pencarian "$query" tidak ditemukan', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ],
      ),
    );
  }


  Widget _buildCustomValueDisplay(
      CategoryAttribute attribute, SelectedAttribute selected) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF2196F3).withOpacity(0.1),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(
          top: BorderSide(color: Color(0xFF2196F3).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, size: 16, color: Color(0xFF2196F3)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Custom: ${selected.customValue}',
              style: TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                _showCustomValueDialog(attribute, isMultiple: true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size(0, 0),
            ),
            child: Text(
              'Edit',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomValueDialog(CategoryAttribute attribute,
      {bool isMultiple = false}) {
    final selected = widget.formData.getSelectedAttribute(attribute.id);
    final controller = TextEditingController(text: selected?.customValue ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF2196F3)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Custom ${attribute.name}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: attribute.name,
                hintText: 'Masukkan nilai custom',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                ),
              ),
              maxLength: 100,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final customValue = controller.text.trim();
              if (customValue.isNotEmpty) {
                _updateAttribute(
                  attribute.id,
                  valueIds: isMultiple ? (selected?.valueIds ?? []) : [],
                  customValue: customValue,
                );
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2196F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sertifikasi Produk',
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
        ...widget.formData.requiredCertifications
            .map((cert) => Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (cert.documentDetails != null)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            cert.documentDetails!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Upload sertifikat akan diimplementasi')),
                          );
                        },
                        icon: Icon(Icons.file_upload, size: 16),
                        label: Text('Upload Sertifikat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }

  // Show dialog untuk create custom brand
  void _showCreateBrandDialog() {
    final controller = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.add_business, color: Color(0xFF2196F3)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tambah Merek Baru',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Masukkan nama merek (2-30 karakter)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 12),
              TextField(
                controller: controller,
                enabled: !isCreating,
                decoration: InputDecoration(
                  labelText: 'Nama Merek',
                  hintText: 'Contoh: Nike, Adidas, dll',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
                  ),
                ),
                maxLength: 30,
                autofocus: true,
              ),
              if (isCreating)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Membuat merek...',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final brandName = controller.text.trim();

                      if (brandName.isEmpty || brandName.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Nama merek minimal 2 karakter'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);

                      try {
                        // Call API to create brand
                        final response = await _apiService.createBrand(
                          widget.shopId,
                          brandName,
                        );

                        if (response is Map<String, dynamic> &&
                            response['success'] == true &&
                            response['data'] != null) {
                          final brandId = response['data']['id'].toString();

                          // Set brand_id ke form
                          setState(() {
                            widget.formData.selectedBrandId = brandId;
                          });
                          widget.onChanged?.call();

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Merek "$brandName" berhasil dibuat'),
                              backgroundColor: Color(0xFF2196F3),
                            ),
                          );
                        } else {
                          throw Exception(
                              response['message'] ?? 'Gagal membuat merek');
                        }
                      } catch (e) {
                        setDialogState(() => isCreating = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal membuat merek: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2196F3),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child:
                  Text('Buat Merek', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
