// lib/models/product.dart
class Product {
  final String id;
  final String title;
  final String description;
  final String status;
  final String mainImage;
  final String price;
  final String currency;
  final int stock;
  final int skuCount;
  final String createdAt;
  final String updatedAt;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.mainImage,
    required this.price,
    required this.currency,
    required this.stock,
    required this.skuCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mainImage: json['mainImage']?.toString() ?? '',
      price: json['price']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'IDR',
      stock: json['stock']?.toInt() ?? 0,
      skuCount: json['skuCount']?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  String get formattedPrice {
    return currency == 'IDR'
        ? 'Rp ${_formatRupiah(price)}'
        : '$currency $price';
  }

  String _formatRupiah(String price) {
    if (price.isEmpty) return '0';
    final number = double.tryParse(price) ?? 0;
    return number.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String get statusText {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Tidak Aktif';
      case 'draft':
        return 'Draft';
      default:
        return status;
    }
  }

  bool get isActive => status.toLowerCase() == 'active';
}
