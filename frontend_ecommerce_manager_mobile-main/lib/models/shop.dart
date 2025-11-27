class Shop {
  final String id;
  final String name;
  final String platform;
  final String lastSync;
  final String sellerName;
  final String region;

  Shop({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSync,
    required this.sellerName,
    required this.region,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      platform: json['platform'] ?? 'TikTok Shop',
      lastSync: json['lastSync'] ?? '',
      sellerName: json['seller_name'] ?? '',
      region: json['region'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'lastSync': lastSync,
      'seller_name': sellerName,
      'region': region,
    };
  }
}
