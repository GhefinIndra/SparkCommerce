// lib/screens/product_detail/models/product_detail_model.dart
import 'package:flutter/material.dart'; // Add this import for Color

class ProductDetailModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final List<ProductImage> images;
  final List<ProductSku> skus;

  // Category information (from category_chains array)
  final List<CategoryChain> categoryChains;

  // Brand information (from brand object)
  final ProductBrand? brand;

  // Package & Weight
  final PackageDimensions? packageDimensions;
  final PackageWeight? packageWeight;

  // Additional fields from API
  final bool isCodAllowed;
  final bool? isNotForSale;
  final bool? isPreOwned;
  final int? minimumOrderQuantity;
  final String? externalProductId;
  final List<String> productTypes;
  final String? shippingInsuranceRequirement;
  final int? createTime;
  final int? updateTime;
  final bool? hasDraft;
  final bool? isReplicated;
  final String? productStatus;

  // Product Attributes (Sertifikasi, dll)
  final List<ProductAttribute>? productAttributes;

  ProductDetailModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.images,
    required this.skus,
    this.categoryChains = const [],
    this.brand,
    this.packageDimensions,
    this.packageWeight,
    this.isCodAllowed = false,
    this.isNotForSale,
    this.isPreOwned,
    this.minimumOrderQuantity,
    this.externalProductId,
    this.productTypes = const [],
    this.shippingInsuranceRequirement,
    this.createTime,
    this.updateTime,
    this.hasDraft,
    this.isReplicated,
    this.productStatus,
    this.productAttributes,
  });

  factory ProductDetailModel.fromJson(Map<String, dynamic> json) {
    return ProductDetailModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? json['product_status']?.toString() ?? '',
      images: (json['main_images'] as List<dynamic>?)
              ?.map((img) => ProductImage.fromJson(img))
              .toList() ??
          (json['images'] as List<dynamic>?)
              ?.map((img) => ProductImage.fromJson(img))
              .toList() ??
          [],
      skus: (json['skus'] as List<dynamic>?)
              ?.map((sku) => ProductSku.fromJson(sku))
              .toList() ??
          [],
      categoryChains: (json['category_chains'] as List<dynamic>?)
              ?.map((cat) => CategoryChain.fromJson(cat))
              .toList() ??
          [],
      brand: json['brand'] != null ? ProductBrand.fromJson(json['brand']) : null,
      packageDimensions: json['package_dimensions'] != null
          ? PackageDimensions.fromJson(json['package_dimensions'])
          : null,
      packageWeight: json['package_weight'] != null
          ? PackageWeight.fromJson(json['package_weight'])
          : null,
      isCodAllowed: json['is_cod_allowed'] == true,
      isNotForSale: json['is_not_for_sale'],
      isPreOwned: json['is_pre_owned'],
      minimumOrderQuantity: json['minimum_order_quantity'],
      externalProductId: json['external_product_id']?.toString(),
      productTypes: (json['product_types'] as List<dynamic>?)
              ?.map((type) => type.toString())
              .toList() ??
          [],
      shippingInsuranceRequirement: json['shipping_insurance_requirement']?.toString(),
      createTime: json['create_time'],
      updateTime: json['update_time'],
      hasDraft: json['has_draft'],
      isReplicated: json['is_replicated'],
      productStatus: json['product_status']?.toString(),
      productAttributes: (json['product_attributes'] as List<dynamic>?)
              ?.map((attr) => ProductAttribute.fromJson(attr))
              .toList(),
    );
  }

  String get statusText {
    switch (status) {
      case 'ACTIVE':
        return 'Aktif';
      case 'SELLER_DEACTIVATED':
        return 'Dinonaktifkan Seller';
      case 'PLATFORM_DEACTIVATED':
        return 'Dinonaktifkan Platform';
      case 'DRAFT':
        return 'Draft';
      case 'PENDING_REVIEW':
        return 'Menunggu Review';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFF4CAF50);
      case 'SELLER_DEACTIVATED':
      case 'PLATFORM_DEACTIVATED':
        return const Color(0xFFFF9800);
      case 'DRAFT':
        return const Color(0xFF2196F3);
      case 'PENDING_REVIEW':
        return const Color(0xFF9C27B0);
      case 'REJECTED':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF757575);
    }
  }

  Color get statusBackgroundColor {
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFFE8F5E8);
      case 'SELLER_DEACTIVATED':
      case 'PLATFORM_DEACTIVATED':
        return const Color(0xFFFFF3E0);
      case 'DRAFT':
        return const Color(0xFFE3F2FD);
      case 'PENDING_REVIEW':
        return const Color(0xFFF3E5F5);
      case 'REJECTED':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  int get totalStock {
    return skus.fold(0, (total, sku) => total + sku.stock);
  }

  String get priceRange {
    if (skus.isEmpty) return 'Rp 0';

    final prices = skus.map((sku) => sku.price.amountInt).toList();
    prices.sort();

    if (prices.first == prices.last) {
      return 'Rp ${_formatRupiah(prices.first.toString())}';
    } else {
      return 'Rp ${_formatRupiah(prices.first.toString())} - ${_formatRupiah(prices.last.toString())}';
    }
  }

  // Get category name from category_chains (last/leaf category)
  String get categoryName {
    if (categoryChains.isEmpty) return '-';
    // Get the leaf category (last one in the chain, or the one with isLeaf = true)
    final leafCategory = categoryChains.firstWhere(
      (cat) => cat.isLeaf,
      orElse: () => categoryChains.last,
    );
    return leafCategory.localName;
  }

  // Get full category path
  String get categoryPath {
    if (categoryChains.isEmpty) return '-';
    return categoryChains.map((cat) => cat.localName).join(' > ');
  }

  // Get brand name
  String get brandName {
    return brand?.name ?? '-';
  }

  static String _formatRupiah(String price) {
    if (price.isEmpty) return '0';
    final number = double.tryParse(price) ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }
}

class ProductImage {
  final String url;
  final String? thumb;

  ProductImage({
    required this.url,
    this.thumb,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      url: json['url']?.toString() ?? '',
      thumb: json['thumb']?.toString(),
    );
  }
}

class ProductSku {
  final String id;
  final String? sellerSku;
  final ProductPrice price;
  final int stock;
  final String? warehouseId;
  final List<SalesAttribute> attributes;

  ProductSku({
    required this.id,
    this.sellerSku,
    required this.price,
    required this.stock,
    this.warehouseId,
    this.attributes = const [],
  });

  factory ProductSku.fromJson(Map<String, dynamic> json) {
    return ProductSku(
      id: json['id']?.toString() ?? '',
      sellerSku: json['sellerSku']?.toString() ?? json['seller_sku']?.toString(),
      price: ProductPrice.fromJson(json['price'] ?? {}),
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      
      warehouseId: json['warehouseId']?.toString() ?? json['warehouse_id']?.toString(),
      attributes: (json['attributes'] as List<dynamic>?)
              ?.map((attr) => SalesAttribute.fromJson(attr))
              .toList() ??
          [],
    );
  }

  String get displayName {
    if (sellerSku != null && sellerSku!.isNotEmpty) {
      return sellerSku!;
    }

    if (attributes.isNotEmpty) {
      final attrValues = attributes
          .map((attr) => attr.valueName)
          .where((name) => name.isNotEmpty)
          .join(', ');
      if (attrValues.isNotEmpty) {
        return attrValues;
      }
    }

    return 'SKU $id';
  }

  ProductSku copyWith({
    String? id,
    String? sellerSku,
    ProductPrice? price,
    int? stock,
    String? warehouseId,
    List<SalesAttribute>? attributes,
  }) {
    return ProductSku(
      id: id ?? this.id,
      sellerSku: sellerSku ?? this.sellerSku,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      warehouseId: warehouseId ?? this.warehouseId,
      attributes: attributes ?? this.attributes,
    );
  }
}

class ProductPrice {
  final String amount;
  final String currency;
  final String? salePrice;

  ProductPrice({
    required this.amount,
    required this.currency,
    this.salePrice,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) {
    return ProductPrice(
      amount: json['amount']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'IDR',
      salePrice: json['salePrice']?.toString(),
    );
  }

  int get amountInt => int.tryParse(amount) ?? 0;
  int get salePriceInt => int.tryParse(salePrice ?? amount) ?? 0;

  String get displayPrice {
    if (currency == 'IDR') {
      return 'Rp ${_formatRupiah(amount)}';
    }
    return '$currency $amount';
  }

  String get displaySalePrice {
    final price = salePrice ?? amount;
    if (currency == 'IDR') {
      return 'Rp ${_formatRupiah(price)}';
    }
    return '$currency $price';
  }

  static String _formatRupiah(String price) {
    if (price.isEmpty) return '0';
    final number = double.tryParse(price) ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  ProductPrice copyWith({
    String? amount,
    String? currency,
    String? salePrice,
  }) {
    return ProductPrice(
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      salePrice: salePrice ?? this.salePrice,
    );
  }
}

class SalesAttribute {
  final String id;
  final String name;
  final String valueId;
  final String valueName;

  SalesAttribute({
    required this.id,
    required this.name,
    required this.valueId,
    required this.valueName,
  });

  factory SalesAttribute.fromJson(Map<String, dynamic> json) {
    return SalesAttribute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      valueId: json['value_id']?.toString() ?? '',
      valueName: json['value_name']?.toString() ?? '',
    );
  }
}

// Category Chain from API response
class CategoryChain {
  final String id;
  final String? parentId;
  final String localName;
  final bool isLeaf;

  CategoryChain({
    required this.id,
    this.parentId,
    required this.localName,
    required this.isLeaf,
  });

  factory CategoryChain.fromJson(Map<String, dynamic> json) {
    return CategoryChain(
      id: json['id']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      localName: json['local_name']?.toString() ?? '',
      isLeaf: json['is_leaf'] == true,
    );
  }
}

// Brand from API response
class ProductBrand {
  final String id;
  final String name;

  ProductBrand({
    required this.id,
    required this.name,
  });

  factory ProductBrand.fromJson(Map<String, dynamic> json) {
    return ProductBrand(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

// Package Dimensions from API response
class PackageDimensions {
  final String length;
  final String width;
  final String height;
  final String unit;

  PackageDimensions({
    required this.length,
    required this.width,
    required this.height,
    required this.unit,
  });

  factory PackageDimensions.fromJson(Map<String, dynamic> json) {
    return PackageDimensions(
      length: json['length']?.toString() ?? '0',
      width: json['width']?.toString() ?? '0',
      height: json['height']?.toString() ?? '0',
      unit: json['unit']?.toString() ?? 'CENTIMETER',
    );
  }

  String get display {
    return '$length x $width x $height $unit';
  }
}

// Package Weight from API response
class PackageWeight {
  final String value;
  final String unit;

  PackageWeight({
    required this.value,
    required this.unit,
  });

  factory PackageWeight.fromJson(Map<String, dynamic> json) {
    return PackageWeight(
      value: json['value']?.toString() ?? '0',
      unit: json['unit']?.toString() ?? 'KILOGRAM',
    );
  }

  String get display {
    return '$value $unit';
  }
}

// Product Attribute from API response (Sertifikasi, dll)
class ProductAttribute {
  final String id;
  final String name;
  final List<AttributeValue> values;

  ProductAttribute({
    required this.id,
    required this.name,
    required this.values,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      values: (json['values'] as List<dynamic>?)
              ?.map((val) => AttributeValue.fromJson(val))
              .toList() ??
          [],
    );
  }
}

// Attribute Value
class AttributeValue {
  final String id;
  final String name;

  AttributeValue({
    required this.id,
    required this.name,
  });

  factory AttributeValue.fromJson(Map<String, dynamic> json) {
    return AttributeValue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
