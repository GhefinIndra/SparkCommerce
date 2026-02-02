/// Shop model representing a marketplace shop.
/// 
/// After PostgreSQL migration:
/// - `id` = marketplace shop ID (used for API calls to TikTok/Shopee)
/// - `internalId` = internal database ID (FK in shops table)
/// 
/// FE should use `id` (marketplace ID) for all API requests to BE,
/// as BE resolves it to internal ID automatically.
class Shop {
  /// Marketplace shop ID (e.g., TikTok shop_id, Shopee shop_id)
  /// This is the ID to use when making API calls
  final String id;
  
  /// Internal database ID (shops.id in PostgreSQL)
  /// Only used for internal reference, not for API calls
  final int? internalId;
  
  final String name;
  final String platform;
  final String lastSync;
  final String sellerName;
  final String region;
  final String? status;
  final String? role;

  Shop({
    required this.id,
    this.internalId,
    required this.name,
    required this.platform,
    required this.lastSync,
    required this.sellerName,
    required this.region,
    this.status,
    this.role,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    // Handle internal_id which can be int or String from BE
    int? parsedInternalId;
    if (json['internal_id'] != null) {
      if (json['internal_id'] is int) {
        parsedInternalId = json['internal_id'];
      } else if (json['internal_id'] is String) {
        parsedInternalId = int.tryParse(json['internal_id']);
      }
    }
    
    return Shop(
      // Prefer 'id' field, fallback to 'shop_id' for backward compatibility
      id: (json['id'] ?? json['shop_id'] ?? '').toString(),
      internalId: parsedInternalId,
      name: json['name'] ?? json['shop_name'] ?? '',
      platform: json['platform'] ?? 'TikTok Shop',
      lastSync: json['lastSync'] ?? json['last_sync'] ?? '',
      sellerName: json['seller_name'] ?? json['sellerName'] ?? '',
      region: json['region'] ?? json['shop_region'] ?? '',
      status: json['status'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'internal_id': internalId,
      'name': name,
      'platform': platform,
      'lastSync': lastSync,
      'seller_name': sellerName,
      'region': region,
      'status': status,
      'role': role,
    };
  }
  
  /// Check if this is a Shopee shop
  bool get isShopee => platform.toLowerCase().contains('shopee');
  
  /// Check if this is a TikTok shop
  bool get isTikTok => platform.toLowerCase().contains('tiktok');
  
  /// Get display name (shop name or seller name as fallback)
  String get displayName => name.isNotEmpty ? name : sellerName;
  
  @override
  String toString() {
    return 'Shop{id: $id, internalId: $internalId, name: $name, platform: $platform}';
  }
}
