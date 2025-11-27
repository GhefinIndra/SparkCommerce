// lib/screens/create_product/models/product_form_data.dart
import 'package:image_picker/image_picker.dart';
import 'category_attribute.dart';

class ProductFormData {
  // Basic Info
  String title = '';
  String description = '';
  String price = '';
  String stock = '';
  String sellerSku = '';

  // Categories & Brand (support up to 5 levels for Shopee)
  String? selectedLevel1Id;
  String? selectedLevel2Id;
  String? selectedLevel3Id;
  String? selectedLevel4Id;
  String? selectedLevel5Id;
  String? selectedBrandId;

  // Category names for display
  String level1Name = '';
  String level2Name = '';
  String level3Name = '';
  String level4Name = '';
  String level5Name = '';

  // Track which level is the final selected category (leaf)
  String? get selectedCategoryId {
    return selectedLevel5Id ?? selectedLevel4Id ?? selectedLevel3Id ?? selectedLevel2Id ?? selectedLevel1Id;
  }

  // Check if category has children (not a leaf)
  bool categoryHasChildren = false;

  // Product Details
  String condition = 'Baru';
  bool isPreOrder = false;

  // Shipping
  String weight = '';
  String weightUnit = 'Gram';
  String length = '';
  String width = '';
  String height = '';
  bool isCodAllowed = true;
  String shippingInsurance = 'OPTIONAL';

  // Images
  List<XFile> selectedImages = [];
  List<String> uploadedImageUris = [];

  // Dynamic Attributes
  List<CategoryAttribute> categoryAttributes = [];
  List<SelectedAttribute> selectedAttributes = [];

  // Category Rules info
  Map<String, dynamic>? categoryRules;
  bool categoryRulesLoaded = false;

  // Size Chart
  bool sizeChartRequired = false;
  bool sizeChartSupported = false;
  String? selectedSizeChartTemplateId;
  String? selectedSizeChartTemplateName;
  XFile? customSizeChartImage;
  String? uploadedSizeChartUri;
  List<Map<String, dynamic>> availableSizeChartTemplates = [];

  // Certifications
  bool certificationsRequired = false;
  List<CertificationRequirement> requiredCertifications = [];
  List<SelectedCertification> selectedCertifications = [];

  // Package Dimensions (from rules)
  bool packageDimensionsRequired = false;

  // Shopee-specific fields
  String? gtin; // GTIN code
  bool productWithoutGtin = false; // "00" checkbox
  int minPurchaseQuantity = 1; // Min purchase quantity
  String maxPurchaseType = 'unlimited'; // unlimited, per_order, per_period
  int? maxPurchaseQuantity; // Max quantity per order/period
  int? maxPurchasePeriodDays; // Days for per_period type
  String itemDangerous = '0'; // 0 = tidak berbahaya, 1 = berbahaya
  String itemStatus = 'NORMAL'; // NORMAL or UNLIST

  // Wholesale (Shopee grosir - skip for phase 1)
  List<Map<String, dynamic>> wholesaleTiers = [];

  // Brand (Shopee uses different structure)
  String? shopeeBrandName; // For text input if input_type = TEXT_FILED
  bool isBrandMandatory = false; // From API response
  String brandInputType = 'DROP_DOWN'; // DROP_DOWN or TEXT_FILED

  // Validation limits from API (Shopee)
  Map<String, dynamic>? itemLimits;

  // Validation states
  Map<String, String?> validationErrors = {};

  // Helper methods
  bool get isBasicInfoValid {
    // Platform-specific title validation will be done in UI
    // For now, allow both ranges (Shopee: 1-226, TikTok: 25-255)
    return title.trim().isNotEmpty &&
        description.trim().isNotEmpty &&
        price.trim().isNotEmpty;
        // SKU dan Stock sekarang OPSIONAL - tidak perlu validasi wajib
        // User bisa pilih SKU dari master, kosongkan SKU, atau tidak pilih SKU
  }

  bool get isCategorySelected {
    // Category is selected if we have at least one level AND it's a leaf (no children)
    return selectedCategoryId != null &&
           selectedCategoryId!.isNotEmpty &&
           !categoryHasChildren;
  }

  bool get hasRequiredImages {
    return selectedImages.isNotEmpty;
  }

  bool get areRequiredAttributesSelected {
    final requiredAttributes =
        categoryAttributes.where((attr) => attr.isRequired);

    for (final required in requiredAttributes) {
      final selected = selectedAttributes.firstWhere(
        (sel) => sel.attributeId == required.id,
        orElse: () => SelectedAttribute(attributeId: ''),
      );

      if (selected.attributeId.isEmpty) return false;

      // Check if has values or custom value
      if (selected.valueIds.isEmpty &&
          (selected.customValue == null ||
              selected.customValue!.trim().isEmpty)) {
        return false;
      }
    }

    return true;
  }

  // Size Chart Validation
  bool get isSizeChartValid {
    if (!sizeChartRequired) return true;

    // Valid jika ada template yang dipilih ATAU ada custom image yang di-upload
    return (selectedSizeChartTemplateId != null &&
            selectedSizeChartTemplateId!.isNotEmpty) ||
        (uploadedSizeChartUri != null && uploadedSizeChartUri!.isNotEmpty);
  }

  // Certifications Validation (with conditional logic)
  bool get areCertificationsValid {
    if (!certificationsRequired) return true;

    // Check each certification requirement
    for (final certReq in requiredCertifications) {
      // Check if this certification is actually required based on conditions
      final isActuallyRequired = certReq.isRequiredForCurrentSelection(selectedAttributes);

      if (!isActuallyRequired) {
        continue; // Skip if not required for current selection
      }

      // Find uploaded certification
      final selected = selectedCertifications.firstWhere(
        (cert) => cert.certificationId == certReq.id,
        orElse: () => SelectedCertification(certificationId: ''),
      );

      // If required but not uploaded, invalid
      if (selected.certificationId.isEmpty ||
          selected.uploadedFileUris.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // Package Dimensions Validation
  bool get arePackageDimensionsValid {
    if (!packageDimensionsRequired) return true;

    return length.trim().isNotEmpty &&
        width.trim().isNotEmpty &&
        height.trim().isNotEmpty &&
        double.tryParse(length.trim()) != null &&
        double.tryParse(width.trim()) != null &&
        double.tryParse(height.trim()) != null;
  }

  // Updated Form Validation
  bool get isFormValid {
    return isBasicInfoValid &&
        isCategorySelected &&
        hasRequiredImages &&
        areRequiredAttributesSelected &&
        // isSizeChartValid && // Removed - size chart is optional for Indonesia
        areCertificationsValid &&
        arePackageDimensionsValid;
  }

  // Convert weight to grams
  double get weightInGrams {
    final weightValue = double.tryParse(weight) ?? 0.0;
    return weightUnit == 'Kg' ? weightValue * 1000 : weightValue;
  }

  // Helper: Get attributes sorted by priority (required first, then trigger attributes)
  List<CategoryAttribute> get sortedCategoryAttributes {
    if (categoryAttributes.isEmpty) return [];

    // Get attribute IDs that trigger certifications
    Set<String> triggerAttributeIds = {};
    for (final cert in requiredCertifications) {
      if (cert.requirementConditions != null) {
        for (final condition in cert.requirementConditions!) {
          if (condition.attributeId != null) {
            triggerAttributeIds.add(condition.attributeId!);
          }
        }
      }
    }


    // Sort priority:
    // 1. Required attributes (isRequired = true)
    // 2. Trigger attributes for certifications
    // 3. Other attributes
    final sorted = List<CategoryAttribute>.from(categoryAttributes);
    sorted.sort((a, b) {
      final aIsRequired = a.isRequired;
      final bIsRequired = b.isRequired;
      final aIsTrigger = triggerAttributeIds.contains(a.id);
      final bIsTrigger = triggerAttributeIds.contains(b.id);

      // Priority 1: Required attributes first
      if (aIsRequired && !bIsRequired) return -1;
      if (!aIsRequired && bIsRequired) return 1;

      // Priority 2: Among same required status, triggers come first
      if (aIsTrigger && !bIsTrigger) return -1;
      if (!aIsTrigger && bIsTrigger) return 1;

      // Same priority, maintain original order
      return 0;
    });

    return sorted;
  }

  void updateCategoryRules(Map<String, dynamic> rules) {
    categoryRules = rules;
    categoryRulesLoaded = true;


    // Update size chart info - handle both nested and flat structure
    final sizeChart = rules['size_chart'] as Map<String, dynamic>?;
    if (sizeChart != null) {
      // Nested structure: { "size_chart": { "is_required": true, "is_supported": true } }
      sizeChartRequired = sizeChart['is_required'] == true;
      sizeChartSupported = sizeChart['is_supported'] == true;

      // Get templates dari backend response
      final templates = sizeChart['templates'] as List?;
      if (templates != null) {
        availableSizeChartTemplates =
            List<Map<String, dynamic>>.from(templates);
      } else {
        availableSizeChartTemplates.clear();
      }

      print(
          ' Size chart info updated (nested): required=$sizeChartRequired, supported=$sizeChartSupported, templates=${availableSizeChartTemplates.length}');
    } else if (rules.containsKey('size_chart_required')) {
      // Flat structure: { "size_chart_required": true }
      // For flat structure, we set supported=true if field exists
      sizeChartSupported = true;
      // IMPORTANT: Size chart is OPTIONAL for Indonesia region
      // Even if TikTok API returns required=true, we treat it as optional
      sizeChartRequired = false;
      availableSizeChartTemplates.clear();

      print(
          ' Size chart info updated (flat): required=$sizeChartRequired (forced optional), supported=$sizeChartSupported');
    } else {
      // No size chart info at all
      sizeChartRequired = false;
      sizeChartSupported = false;
      availableSizeChartTemplates.clear();
    }

    // Update certifications info
    final certifications = rules['product_certifications'] as List?;

    if (certifications != null && certifications.isNotEmpty) {
      // Parse all certifications
      requiredCertifications = certifications
          .map((cert) => CertificationRequirement.fromJson(cert))
          .toList();

      // DEBUG: Log each certification's requirement_conditions
      for (var i = 0; i < requiredCertifications.length; i++) {
        final cert = requiredCertifications[i];
        print('   [$i] ${cert.name}:');
        print('       - is_required: ${cert.isRequired}');
        print('       - has_conditions: ${cert.requirementConditions != null}');
        print('       - conditions_count: ${cert.requirementConditions?.length ?? 0}');
        if (cert.requirementConditions != null) {
          for (var j = 0; j < cert.requirementConditions!.length; j++) {
            final cond = cert.requirementConditions![j];
            print('       - condition[$j]: ${cond.conditionType} | attr=${cond.attributeId} | value=${cond.attributeValueId}');
          }
        }
      }

      
      // 1. There's at least one cert with is_required=true WITHOUT conditions, OR
      // 2. There's at least one cert with conditions (conditional requirement)
      certificationsRequired = requiredCertifications.any((cert) {
        // Has no conditions but is required = always required
        if (cert.requirementConditions == null || cert.requirementConditions!.isEmpty) {
          return cert.isRequired;
        }
        // Has conditions = potentially required (will check dynamically)
        return true;
      });

    } else {
      requiredCertifications.clear();
      certificationsRequired = false;
    }

    // Update package dimensions requirement
    final packageDimension =
        rules['package_dimension'] as Map<String, dynamic>?;
    packageDimensionsRequired = packageDimension?['is_required'] == true;

    print(
        '   - Size Chart: required=$sizeChartRequired, supported=$sizeChartSupported');
    print(
        '   - Certifications: required=$certificationsRequired (${requiredCertifications.length} certs)');
    print('   - Package Dimensions: required=$packageDimensionsRequired');
    print(
        '   - Available Size Chart Templates: ${availableSizeChartTemplates.length}');
  }

  void clearCategoryRulesData() {
    categoryRules = null;
    categoryRulesLoaded = false;

    // Clear size chart data
    sizeChartRequired = false;
    sizeChartSupported = false;
    selectedSizeChartTemplateId = null;
    selectedSizeChartTemplateName = null;
    customSizeChartImage = null;
    uploadedSizeChartUri = null;
    availableSizeChartTemplates.clear();

    // Clear certifications data
    certificationsRequired = false;
    requiredCertifications.clear();
    selectedCertifications.clear();

    // Clear package dimensions requirement
    packageDimensionsRequired = false;
  }

  // Prepare data for API submission (TikTok format)
  Map<String, dynamic> toApiData() {
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      // Use selectedCategoryId for consistency (TikTok always has level 3, so this returns level3)
      'category_id': selectedCategoryId,
      'price': price.trim(),
      'stock': stock.trim(),
      'seller_sku': sellerSku.trim(),
      'weight': weightInGrams.toString(),
      'main_images': uploadedImageUris,
      'is_cod_allowed': isCodAllowed,
      'package_dimensions': {
        'length': length.trim().isNotEmpty ? length.trim() : '10',
        'width': width.trim().isNotEmpty ? width.trim() : '10',
        'height': height.trim().isNotEmpty ? height.trim() : '10',
      },
      'condition': condition,
      'is_pre_order': isPreOrder,
      'shipping_insurance': shippingInsurance,
    };

    // Add brand_id only if valid
    if (selectedBrandId != null &&
        selectedBrandId!.isNotEmpty &&
        selectedBrandId != 'no_brand' &&
        selectedBrandId != 'add_new_brand') {
      data['brand_id'] = selectedBrandId;
    }

    // Add product attributes
    if (selectedAttributes.isNotEmpty) {
      final attributesData = selectedAttributes.map((attr) {
        // Find the corresponding CategoryAttribute to pass value names
        final categoryAttr = categoryAttributes.firstWhere(
          (ca) => ca.id == attr.attributeId,
          orElse: () => CategoryAttribute(
            id: attr.attributeId,
            name: '',
            type: '',
            values: [],
          ),
        );
        return attr.toJson(categoryAttr);
      }).toList();
      data['product_attributes'] = attributesData;

      print('   Total attributes: ${selectedAttributes.length}');
      for (var i = 0; i < selectedAttributes.length; i++) {
        final attr = selectedAttributes[i];
        final categoryAttr = categoryAttributes.firstWhere(
          (ca) => ca.id == attr.attributeId,
          orElse: () => CategoryAttribute(
            id: attr.attributeId,
            name: '',
            type: '',
            values: [],
          ),
        );
        final jsonData = attr.toJson(categoryAttr);
        print('   [$i] Attribute ID: ${attr.attributeId}');
        print('       - Value IDs: ${attr.valueIds}');
        print('       - Custom value: ${attr.customValue}');
        print('       - JSON format: $jsonData');
      }
    } else {
      print('   Category has ${categoryAttributes.length} attributes');
      print('   Required attributes: ${categoryAttributes.where((a) => a.isRequired).length}');
    }

    if (sizeChartSupported &&
        (selectedSizeChartTemplateId != null || uploadedSizeChartUri != null)) {
      data['size_chart'] = <String, dynamic>{};

      if (selectedSizeChartTemplateId != null &&
          selectedSizeChartTemplateId!.isNotEmpty) {
        data['size_chart']['template'] = {'id': selectedSizeChartTemplateId};
      }

      if (uploadedSizeChartUri != null && uploadedSizeChartUri!.isNotEmpty) {
        data['size_chart']['image'] = {'uri': uploadedSizeChartUri};
      }
    }

    if (certificationsRequired && selectedCertifications.isNotEmpty) {
      data['certifications'] =
          selectedCertifications.map((cert) => cert.toJson()).toList();
    }

    return data;
  }

  // Convert to Shopee API format
  Map<String, dynamic> toShopeeApiData() {
    final data = <String, dynamic>{
      'item_name': title.trim(),
      'description': description.trim(),
      // Use selectedCategoryId to support dynamic category depth (1-5 levels)
      'category_id': int.parse(selectedCategoryId!),
      'original_price': double.parse(price.trim()),
      'weight': double.parse(weight.trim()) / 1000, // gram to kg
      'image': {
        'image_id_list': uploadedImageUris, // image_id from Shopee upload
      },
      'item_status': itemStatus,
    };

    // Stock (seller_stock array)
    if (stock.trim().isNotEmpty) {
      data['seller_stock'] = [
        {
          'location_id': '', // Default location
          'stock': int.parse(stock.trim()),
        }
      ];
    }

    // Dimensions (optional)
    if (length.trim().isNotEmpty &&
        width.trim().isNotEmpty &&
        height.trim().isNotEmpty) {
      data['dimension'] = {
        'package_length': int.parse(length.trim()),
        'package_width': int.parse(width.trim()),
        'package_height': int.parse(height.trim()),
      };
    }

    // Min purchase quantity (always send, default is 1)
    // Note: Shopee doesn't have min_purchase_limit in their API
    // This is handled differently - they don't support this feature

    // Condition
    if (condition == 'Baru') {
      data['condition'] = 'NEW';
    } else {
      data['condition'] = 'USED';
    }

    // Pre-order
    if (isPreOrder) {
      data['pre_order'] = {
        'is_pre_order': true,
        'days_to_ship': 7, // Default
      };
    }

    // Item dangerous
    if (itemDangerous == '1') {
      data['item_dangerous'] = 1;
    } else {
      data['item_dangerous'] = 0;
    }

    // GTIN
    if (productWithoutGtin) {
      data['gtin_code'] = '00'; // Product without GTIN
    } else if (gtin != null && gtin!.trim().isNotEmpty) {
      data['gtin_code'] = gtin!.trim();
    }

    // SKU
    if (sellerSku.trim().isNotEmpty) {
      data['item_sku'] = sellerSku.trim();
    }

    // Brand - ALWAYS send for Shopee (mandatory for most categories)
    // Priority: selected brand > custom brand name > "No Brand" fallback
    if (brandInputType == 'DROP_DOWN' && selectedBrandId != null && selectedBrandId!.isNotEmpty) {
      // Check if it's a special ID like 'no_brand' or 'add_new_brand'
      if (selectedBrandId == 'no_brand' || selectedBrandId == 'add_new_brand') {
        // Special handling for custom brand IDs
        data['brand'] = {
          'brand_id': 0,
          'original_brand_name': selectedBrandId == 'no_brand' ? 'No Brand' : shopeeBrandName ?? 'No Brand',
        };
      } else {
        // Use brand_id from dropdown (numeric ID)
        data['brand'] = {
          'brand_id': int.parse(selectedBrandId!),
          'original_brand_name': shopeeBrandName ?? '', // Display name
        };
      }
    } else if (brandInputType == 'TEXT_FILED' && shopeeBrandName != null && shopeeBrandName!.trim().isNotEmpty) {
      // Use text input for brand name
      data['brand'] = {
        'brand_id': 0, // 0 for custom brand
        'original_brand_name': shopeeBrandName!.trim(),
      };
    } else {
      // FALLBACK: Always send brand for Shopee (most categories require it)
      // Use "No Brand" as default if not specified
      data['brand'] = {
        'brand_id': 0,
        'original_brand_name': 'No Brand',
      };
    }

    // Product attributes (Shopee format)
    if (selectedAttributes.isNotEmpty) {
      final attributesData = selectedAttributes.map((attr) {
        return {
          'attribute_id': int.parse(attr.attributeId),
          'attribute_value_list': attr.valueIds.map((vid) {
            return {
              'value_id': int.parse(vid),
            };
          }).toList(),
        };
      }).toList();
      data['attribute_list'] = attributesData;
    }

    // Logistic info will be auto-populated by backend if not provided

    return data;
  }

  // Update selected attribute
  void updateAttribute(
    String attributeId, {
    List<String>? valueIds,
    String? customValue,
  }) {
    final existingIndex = selectedAttributes.indexWhere(
      (attr) => attr.attributeId == attributeId,
    );

    final newAttribute = SelectedAttribute(
      attributeId: attributeId,
      valueIds: valueIds ?? [],
      customValue: customValue,
    );

    if (existingIndex >= 0) {
      selectedAttributes[existingIndex] = newAttribute;
    } else {
      selectedAttributes.add(newAttribute);
    }
  }

  // Get selected attribute
  SelectedAttribute? getSelectedAttribute(String attributeId) {
    try {
      return selectedAttributes.firstWhere(
        (attr) => attr.attributeId == attributeId,
      );
    } catch (e) {
      return null;
    }
  }

  // Clear category-related data when category changes
  void clearCategoryData() {
    categoryAttributes.clear();
    selectedAttributes.clear();
    selectedBrandId = null;
    validationErrors.clear();

    clearCategoryRulesData();
  }

  // Validate specific field
  void validateField(String field, String? value) {
    switch (field) {
      case 'title':
        if (value == null || value.trim().isEmpty) {
          validationErrors['title'] = 'Nama produk wajib diisi';
        } else if (value.trim().length < 25) {
          validationErrors['title'] = 'Nama produk minimal 25 karakter';
        } else if (value.trim().length > 255) {
          validationErrors['title'] = 'Nama produk maksimal 255 karakter';
        } else {
          validationErrors.remove('title');
        }
        break;

      case 'description':
        if (value == null || value.trim().isEmpty) {
          validationErrors['description'] = 'Deskripsi wajib diisi';
        } else {
          validationErrors.remove('description');
        }
        break;

      case 'price':
        if (value == null || value.trim().isEmpty) {
          validationErrors['price'] = 'Harga wajib diisi';
        } else if (double.tryParse(value.trim()) == null) {
          validationErrors['price'] = 'Harga harus berupa angka';
        } else {
          validationErrors.remove('price');
        }
        break;

      case 'stock':
        // Stock sekarang opsional - hanya validasi format jika ada value
        if (value != null && value.trim().isNotEmpty) {
          if (int.tryParse(value.trim()) == null) {
            validationErrors['stock'] = 'Stok harus berupa angka';
          } else {
            validationErrors.remove('stock');
          }
        } else {
          validationErrors.remove('stock');
        }
        break;

      case 'sellerSku':
        // SKU sekarang opsional - tidak perlu validasi wajib
        validationErrors.remove('sellerSku');
        break;

      case 'weight':
        if (value == null || value.trim().isEmpty) {
          validationErrors['weight'] = 'Berat wajib diisi';
        } else if (double.tryParse(value.trim()) == null) {
          validationErrors['weight'] = 'Berat harus berupa angka';
        } else {
          validationErrors.remove('weight');
        }
        break;
    }
  }
}

class CertificationRequirement {
  final String id;
  final String name;
  final bool isRequired;
  final String? documentDetails;
  final String? sampleImageUrl;
  final bool expirationDateRequired;
  final List<RequirementCondition>? requirementConditions;

  CertificationRequirement({
    required this.id,
    required this.name,
    required this.isRequired,
    this.documentDetails,
    this.sampleImageUrl,
    required this.expirationDateRequired,
    this.requirementConditions,
  });

  factory CertificationRequirement.fromJson(Map<String, dynamic> json) {
    final conditionsList = json['requirement_conditions'] as List?;
    List<RequirementCondition>? conditions;

    if (conditionsList != null && conditionsList.isNotEmpty) {
      conditions = conditionsList
          .map((c) => RequirementCondition.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return CertificationRequirement(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isRequired: json['is_required'] == true,
      documentDetails: json['document_details']?.toString(),
      sampleImageUrl: json['sample_image_url']?.toString(),
      expirationDateRequired: json['expiration_date']?['is_required'] == true,
      requirementConditions: conditions,
    );
  }

  // Check if certification is actually required based on conditions
  bool isRequiredForCurrentSelection(List<SelectedAttribute> selectedAttributes) {
    // If no conditions, use base isRequired flag
    if (requirementConditions == null || requirementConditions!.isEmpty) {
      return isRequired;
    }

    // Check if ALL conditions are met
    for (final condition in requirementConditions!) {
      if (condition.conditionType == 'VALUE_ID_MATCH') {
        final matchingAttr = selectedAttributes.firstWhere(
          (attr) => attr.attributeId == condition.attributeId,
          orElse: () => SelectedAttribute(attributeId: ''),
        );

        // If attribute not selected or value doesn't match, condition not met
        if (matchingAttr.attributeId.isEmpty ||
            !matchingAttr.valueIds.contains(condition.attributeValueId)) {
          return false; // Condition not met, so NOT required
        }
      }
    }

    // All conditions met
    return isRequired;
  }
}

class RequirementCondition {
  final String conditionType; // e.g. "VALUE_ID_MATCH"
  final String? attributeId;
  final String? attributeValueId;

  RequirementCondition({
    required this.conditionType,
    this.attributeId,
    this.attributeValueId,
  });

  factory RequirementCondition.fromJson(Map<String, dynamic> json) {
    return RequirementCondition(
      conditionType: json['condition_type']?.toString() ?? '',
      attributeId: json['attribute_id']?.toString(),
      attributeValueId: json['attribute_value_id']?.toString(),
    );
  }
}

class SelectedCertification {
  final String certificationId;
  List<XFile> selectedFiles;
  List<String> uploadedFileUris;
  DateTime? expirationDate;

  SelectedCertification({
    required this.certificationId,
    this.selectedFiles = const [],
    this.uploadedFileUris = const [],
    this.expirationDate,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': certificationId,
    };

    // Add uploaded files/images
    if (uploadedFileUris.isNotEmpty) {
      // Separate images and files based on file extension
      final images = uploadedFileUris
          .where((uri) =>
              uri.toLowerCase().endsWith('.jpg') ||
              uri.toLowerCase().endsWith('.jpeg') ||
              uri.toLowerCase().endsWith('.png'))
          .toList();

      final files = uploadedFileUris
          .where((uri) =>
              uri.toLowerCase().endsWith('.pdf') ||
              uri.toLowerCase().endsWith('.doc') ||
              uri.toLowerCase().endsWith('.docx'))
          .toList();

      if (images.isNotEmpty) {
        json['images'] = images.map((uri) => {'uri': uri}).toList();
      }

      if (files.isNotEmpty) {
        json['files'] = files
            .map((uri) => {
                  'id': uri, // TikTok Shop expects file ID
                  'name': uri.split('/').last,
                  'format': uri.split('.').last.toUpperCase()
                })
            .toList();
      }
    }

    // Add expiration date if provided
    if (expirationDate != null) {
      json['expiration_date'] =
          (expirationDate!.millisecondsSinceEpoch / 1000).round();
    }

    return json;
  }

  bool get isValid {
    return uploadedFileUris.isNotEmpty;
  }
}
