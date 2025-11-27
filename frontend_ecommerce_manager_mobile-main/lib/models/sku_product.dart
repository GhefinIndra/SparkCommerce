// lib/models/sku_product.dart

class SKUProduct {
  final String sku;
  final String name;
  final String description;
  final int stock;
  final double price;
  
  // TikTok Shop mapping
  final String? tiktokProductId;
  final String? tiktokSkuId;
  final String? tiktokWarehouseId;
  final int tiktokLastStock;
  
  // Shopee mapping (future)
  final String? shopeeProductId;
  final String? shopeeVariationId;
  final int shopeeLastStock;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncAt;

  SKUProduct({
    required this.sku,
    required this.name,
    required this.description,
    required this.stock,
    required this.price,
    this.tiktokProductId,
    this.tiktokSkuId,
    this.tiktokWarehouseId,
    required this.tiktokLastStock,
    this.shopeeProductId,
    this.shopeeVariationId,
    required this.shopeeLastStock,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncAt,
  });

  // Create from SQLite Map
  factory SKUProduct.fromMap(Map<String, dynamic> map) {
    return SKUProduct(
      sku: map['sku'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      stock: map['stock'] as int? ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      tiktokProductId: map['tiktok_product_id'] as String?,
      tiktokSkuId: map['tiktok_sku_id'] as String?,
      tiktokWarehouseId: map['tiktok_warehouse_id'] as String?,
      tiktokLastStock: map['tiktok_last_stock'] as int? ?? 0,
      shopeeProductId: map['shopee_product_id'] as String?,
      shopeeVariationId: map['shopee_variation_id'] as String?,
      shopeeLastStock: map['shopee_last_stock'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastSyncAt: map['last_sync_at'] != null 
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
    );
  }

  // Convert to SQLite Map
  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'name': name,
      'description': description,
      'stock': stock,
      'price': price,
      'tiktok_product_id': tiktokProductId,
      'tiktok_sku_id': tiktokSkuId,
      'tiktok_warehouse_id': tiktokWarehouseId,
      'tiktok_last_stock': tiktokLastStock,
      'shopee_product_id': shopeeProductId,
      'shopee_variation_id': shopeeVariationId,
      'shopee_last_stock': shopeeLastStock,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_sync_at': lastSyncAt?.toIso8601String(),
    };
  }

  // Helper getters untuk UI
  String get formattedPrice {
    return 'Rp ${_formatRupiah(price)}';
  }

  String _formatRupiah(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  bool get isOnTikTok => tiktokProductId != null;
  bool get isOnShopee => shopeeProductId != null;
  
  String get marketplaceInfo {
    List<String> marketplaces = [];
    if (isOnTikTok) marketplaces.add('TikTok');
    if (isOnShopee) marketplaces.add('Shopee');
    
    if (marketplaces.isEmpty) return 'Tidak ada marketplace';
    return marketplaces.join('  ');
  }

  // Check if stock changed from last known
  bool get hasTikTokStockChanged => isOnTikTok && (stock != tiktokLastStock);
  bool get hasShopeeStockChanged => isOnShopee && (stock != shopeeLastStock);
  bool get needsSync => hasTikTokStockChanged || hasShopeeStockChanged;

  // Calculate delta
  int get tiktokDelta => stock - tiktokLastStock;
  int get shopeeDelta => stock - shopeeLastStock;

  // Copy with untuk immutable updates
  SKUProduct copyWith({
    String? sku,
    String? name,
    String? description,
    int? stock,
    double? price,
    String? tiktokProductId,
    String? tiktokSkuId,
    String? tiktokWarehouseId,
    int? tiktokLastStock,
    String? shopeeProductId,
    String? shopeeVariationId,
    int? shopeeLastStock,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncAt,
  }) {
    return SKUProduct(
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      price: price ?? this.price,
      tiktokProductId: tiktokProductId ?? this.tiktokProductId,
      tiktokSkuId: tiktokSkuId ?? this.tiktokSkuId,
      tiktokWarehouseId: tiktokWarehouseId ?? this.tiktokWarehouseId,
      tiktokLastStock: tiktokLastStock ?? this.tiktokLastStock,
      shopeeProductId: shopeeProductId ?? this.shopeeProductId,
      shopeeVariationId: shopeeVariationId ?? this.shopeeVariationId,
      shopeeLastStock: shopeeLastStock ?? this.shopeeLastStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  String toString() {
    return 'SKUProduct(sku: $sku, name: $name, stock: $stock, TikTok: $isOnTikTok, Shopee: $isOnShopee)';
  }
}

// Helper class untuk hasil sync
class SyncResult {
  final bool success;
  final String message;
  final int? newStock;
  final List<String> updatedMarketplaces;
  final String? error;

  SyncResult({
    required this.success,
    required this.message,
    this.newStock,
    this.updatedMarketplaces = const [],
    this.error,
  });

  factory SyncResult.success({
    required String message,
    int? newStock,
    List<String> updatedMarketplaces = const [],
  }) {
    return SyncResult(
      success: true,
      message: message,
      newStock: newStock,
      updatedMarketplaces: updatedMarketplaces,
    );
  }

  factory SyncResult.failed({
    required String error,
  }) {
    return SyncResult(
      success: false,
      message: 'Sync gagal',
      error: error,
    );
  }

  @override
  String toString() {
    if (success) {
      return 'SyncResult: $message (Stock: $newStock, Updated: ${updatedMarketplaces.join(", ")})';
    } else {
      return 'SyncResult: FAILED - $error';
    }
  }
}