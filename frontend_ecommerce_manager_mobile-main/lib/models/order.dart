// lib/models/order.dart
class Order {
  final String id;
  final String orderId;
  final String orderNumber;
  final String status;
  final String statusCode;
  final String orderStatus;
  final String orderStatusName;
  final String totalAmount;
  final String subTotal;
  final String shippingFee;
  final String currency;
  final String customerName;
  final String buyerName;
  final String customerPhone;
  final String buyerPhone;
  final String customerAddress;
  final int itemCount;
  final String itemsSummary;
  final String orderDate;
  final String paidDate;
  final String updateDate;
  final int createdTime;
  final int updatedTime;
  final String shippingProvider;
  final String shippingType;
  final String trackingNumber;
  final String buyerMessage;
  final String sellerNote;
  final String paymentMethod;
  final String fulfillmentType;
  final String deliveryType;
  final bool isUrgent;
  final bool isCod;
  final bool isOnHold;
  final bool isBuyerRequestCancel;
  final String warehouseName;
  final String statusColor;
  final bool canCancel;
  final bool canShip;
  final List<OrderItem> items;

  
  final String? packageId;
  final String? packageStatus;

  Order({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusCode,
    required this.orderStatus,
    required this.orderStatusName,
    required this.totalAmount,
    required this.subTotal,
    required this.shippingFee,
    required this.currency,
    required this.customerName,
    required this.buyerName,
    required this.customerPhone,
    required this.buyerPhone,
    required this.customerAddress,
    required this.itemCount,
    required this.itemsSummary,
    required this.orderDate,
    required this.paidDate,
    required this.updateDate,
    required this.createdTime,
    required this.updatedTime,
    required this.shippingProvider,
    required this.shippingType,
    required this.trackingNumber,
    required this.buyerMessage,
    required this.sellerNote,
    required this.paymentMethod,
    required this.fulfillmentType,
    required this.deliveryType,
    required this.isUrgent,
    required this.isCod,
    required this.isOnHold,
    required this.isBuyerRequestCancel,
    required this.warehouseName,
    required this.statusColor,
    required this.canCancel,
    required this.canShip,
    required this.items,

    
    this.packageId,
    this.packageStatus,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      // Basic identifiers
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? json['id']?.toString() ?? '',
      orderNumber:
          json['orderNumber']?.toString() ?? json['id']?.toString() ?? '',

      // Status fields
      status: json['status']?.toString() ?? '',
      statusCode: json['statusCode']?.toString() ?? '',
      orderStatus:
          json['statusCode']?.toString() ?? json['status']?.toString() ?? '',
      orderStatusName: json['orderStatusName']?.toString() ??
          json['status']?.toString() ??
          '',

      // Financial information
      totalAmount: json['totalAmount']?.toString() ?? '0',
      subTotal: json['subTotal']?.toString() ?? '0',
      shippingFee: json['shippingFee']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'IDR',

      // Customer information
      customerName: json['customerName']?.toString() ?? '',
      buyerName: json['buyerName']?.toString() ??
          json['customerName']?.toString() ??
          'N/A',
      customerPhone: json['customerPhone']?.toString() ?? '',
      buyerPhone: json['customerPhone']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',

      // Items information
      itemCount: json['itemCount'] ?? (json['items'] as List?)?.length ?? 0,
      itemsSummary: json['itemsSummary']?.toString() ?? '',
      items: _parseOrderItems(json['items']),

      // Dates - Handle both string and timestamp formats
      orderDate: json['orderDate']?.toString() ?? '',
      paidDate: json['paidDate']?.toString() ?? '',
      updateDate: json['updateDate']?.toString() ?? '',
      createdTime: _parseTimestamp(json['orderDate']) ?? 0,
      updatedTime: _parseTimestamp(json['updateDate']) ?? 0,

      // Shipping information
      shippingProvider: json['shippingProvider']?.toString() ?? '',
      shippingType: json['shippingProvider']?.toString() ?? '',
      trackingNumber: json['trackingNumber']?.toString() ?? '',

      // Additional information
      buyerMessage: json['buyerMessage']?.toString() ?? '',
      sellerNote: json['sellerNote']?.toString() ?? '',
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      fulfillmentType: json['fulfillmentType']?.toString() ?? '',
      deliveryType: json['deliveryType']?.toString() ?? '',

      // Flags
      isUrgent: json['isBuyerRequestCancel'] ?? false,
      isCod: json['isCod'] ?? false,
      isOnHold: json['isOnHold'] ?? false,
      isBuyerRequestCancel: json['isBuyerRequestCancel'] ?? false,

      // Status styling and actions
      warehouseName: json['warehouseName']?.toString() ?? '',
      statusColor: _getStatusColorHex(
          json['statusCode']?.toString() ?? json['status']?.toString() ?? ''),
      canCancel: _canCancelOrder(
          json['statusCode']?.toString() ?? json['status']?.toString() ?? ''),
      canShip: _canShipOrder(
          json['statusCode']?.toString() ?? json['status']?.toString() ?? ''),

      
      packageId:
          json['packageId']?.toString() ?? json['package_id']?.toString(),
      packageStatus: json['packageStatus']?.toString() ??
          json['package_status']?.toString(),
    );
  }

  // Helper method to parse order items
  static List<OrderItem> _parseOrderItems(dynamic itemsJson) {
    if (itemsJson == null || itemsJson is! List) return [];

    return (itemsJson as List).map((item) {
      if (item is Map<String, dynamic>) {
        return OrderItem.fromJson(item);
      }
      return OrderItem.empty();
    }).toList();
  }

  // Helper method to parse timestamp from string
  static int? _parseTimestamp(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final date = DateTime.parse(dateString);
      return date.millisecondsSinceEpoch ~/ 1000;
    } catch (e) {
      return null;
    }
  }

  // Helper method to format date from string
  static String _formatDateFromString(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  // Helper method to format currency
  static String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final numAmount = double.parse(amount.toString());
      return 'Rp ${numAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $amount';
    }
  }

  // Status color mapping based on backend status codes
  static String _getStatusColorHex(String status) {
    switch (status.toUpperCase()) {
      case 'UNPAID':
        return '#FF9800'; // Orange
      case 'ON_HOLD':
        return '#FF5722'; // Red Orange
      case 'AWAITING_SHIPMENT':
        return '#2196F3'; // Blue
      case 'PARTIALLY_SHIPPING':
        return '#9C27B0'; // Purple
      case 'AWAITING_COLLECTION':
        return '#795548'; // Brown
      case 'IN_TRANSIT':
        return '#03A9F4'; // Light Blue
      case 'DELIVERED':
        return '#4CAF50'; // Green
      case 'COMPLETED':
        return '#8BC34A'; // Light Green
      case 'CANCELLED':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }

  // Status color as integer for Flutter Color
  static int _getStatusColorInt(String status) {
    switch (status.toUpperCase()) {
      case 'UNPAID':
        return 0xFFFF9800;
      case 'ON_HOLD':
        return 0xFFFF5722;
      case 'AWAITING_SHIPMENT':
        return 0xFF2196F3;
      case 'PARTIALLY_SHIPPING':
        return 0xFF9C27B0;
      case 'AWAITING_COLLECTION':
        return 0xFF795548;
      case 'IN_TRANSIT':
        return 0xFF03A9F4;
      case 'DELIVERED':
        return 0xFF4CAF50;
      case 'COMPLETED':
        return 0xFF8BC34A;
      case 'CANCELLED':
        return 0xFFF44336;
      default:
        return 0xFF9E9E9E;
    }
  }

  // Determine if order can be cancelled
  static bool _canCancelOrder(String status) {
    return ['UNPAID', 'ON_HOLD', 'AWAITING_SHIPMENT']
        .contains(status.toUpperCase());
  }

  
  static bool _canShipOrder(String status) {
    const shippableStatuses = [
      'AWAITING_SHIPMENT',
      'TO_FULFILL',
      'AWAITING_COLLECTION'
    ];

    return shippableStatuses.contains(status.toUpperCase());
  }

  
  String getShippingStatusMessage() {
    if (canShip) {
      return 'Siap untuk dikirim';
    }

    switch (statusCode.toUpperCase()) {
      case 'UNPAID':
        return 'Pesanan belum dibayar';
      case 'ON_HOLD':
        return 'Pesanan sedang ditahan';
      case 'IN_TRANSIT':
        return 'Pesanan sudah dalam pengiriman';
      case 'DELIVERED':
        return 'Pesanan sudah terkirim';
      case 'COMPLETED':
        return 'Pesanan sudah selesai';
      case 'CANCELLED':
        return 'Pesanan dibatalkan';
      default:
        return 'Status: $orderStatusName';
    }
  }

  
  bool get hasPackage => packageId != null && packageId!.isNotEmpty;

  
  String get packageDisplayStatus {
    if (!hasPackage) return 'Belum dikemas';
    return packageStatus ?? 'Dikemas';
  }

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'status': status,
      'statusCode': statusCode,
      'orderStatus': orderStatus,
      'orderStatusName': orderStatusName,
      'totalAmount': totalAmount,
      'subTotal': subTotal,
      'shippingFee': shippingFee,
      'currency': currency,
      'customerName': customerName,
      'buyerName': buyerName,
      'customerPhone': customerPhone,
      'buyerPhone': buyerPhone,
      'customerAddress': customerAddress,
      'itemCount': itemCount,
      'itemsSummary': itemsSummary,
      'orderDate': orderDate,
      'paidDate': paidDate,
      'updateDate': updateDate,
      'createdTime': createdTime,
      'updatedTime': updatedTime,
      'shippingProvider': shippingProvider,
      'shippingType': shippingType,
      'trackingNumber': trackingNumber,
      'buyerMessage': buyerMessage,
      'sellerNote': sellerNote,
      'paymentMethod': paymentMethod,
      'fulfillmentType': fulfillmentType,
      'deliveryType': deliveryType,
      'isUrgent': isUrgent,
      'isCod': isCod,
      'isOnHold': isOnHold,
      'isBuyerRequestCancel': isBuyerRequestCancel,
      'warehouseName': warehouseName,
      'statusColor': statusColor,
      'canCancel': canCancel,
      'canShip': canShip,
      'items': items.map((item) => item.toJson()).toList(),

      
      'packageId': packageId,
      'packageStatus': packageStatus,
    };
  }

  // Legacy getter for backward compatibility
  String get formattedAmount {
    return _formatCurrency(totalAmount);
  }

  // Legacy getter for status color
  int get statusColorInt {
    return _getStatusColorInt(statusCode.isNotEmpty ? statusCode : status);
  }

  // Getter for formatted create time
  String get formattedCreateTime {
    return _formatDateFromString(orderDate);
  }

  // Getter for formatted update time
  String get formattedUpdateTime {
    return _formatDateFromString(updateDate);
  }
}

// Order Item model for individual products in an order
class OrderItem {
  final String id;
  final String skuId; // SKU ID from TikTok (for mapping to SKU Master)
  final String productId;
  final String productName;
  final String sellerSku;
  final String skuName;
  final String skuImage;
  final int quantity;
  final String price;
  final String originalPrice;
  final String currency;
  final String itemStatus;
  final String itemStatusCode;

  OrderItem({
    required this.id,
    required this.skuId,
    required this.productId,
    required this.productName,
    required this.sellerSku,
    required this.skuName,
    required this.skuImage,
    required this.quantity,
    required this.price,
    required this.originalPrice,
    required this.currency,
    required this.itemStatus,
    required this.itemStatusCode,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      skuId: json['skuId']?.toString() ?? json['sku_id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? 'Produk Tidak Dikenal',
      sellerSku: json['sellerSku']?.toString() ?? '',
      skuName: json['skuName']?.toString() ?? '',
      skuImage: json['skuImage']?.toString() ?? '',
      quantity: json['quantity'] ?? 1,
      price: json['price']?.toString() ?? '0',
      originalPrice: json['originalPrice']?.toString() ?? '0',
      currency: json['currency']?.toString() ?? 'IDR',
      itemStatus: json['itemStatus']?.toString() ?? '',
      itemStatusCode: json['itemStatusCode']?.toString() ?? '',
    );
  }

  factory OrderItem.empty() {
    return OrderItem(
      id: '',
      skuId: '',
      productId: '',
      productName: 'Produk Tidak Dikenal',
      sellerSku: '',
      skuName: '',
      skuImage: '',
      quantity: 0,
      price: '0',
      originalPrice: '0',
      currency: 'IDR',
      itemStatus: '',
      itemStatusCode: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'skuId': skuId,
      'productId': productId,
      'productName': productName,
      'sellerSku': sellerSku,
      'skuName': skuName,
      'skuImage': skuImage,
      'quantity': quantity,
      'price': price,
      'originalPrice': originalPrice,
      'currency': currency,
      'itemStatus': itemStatus,
      'itemStatusCode': itemStatusCode,
    };
  }

  // Format price for display
  String get formattedPrice {
    try {
      final amount = double.parse(price);
      return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $price';
    }
  }

  // Format original price for display
  String get formattedOriginalPrice {
    try {
      final amount = double.parse(originalPrice);
      return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $originalPrice';
    }
  }
}

// Order response model for API pagination
class OrderResponse {
  final List<Order> orders;
  final OrderPagination pagination;

  OrderResponse({
    required this.orders,
    required this.pagination,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      orders: (json['orders'] as List? ?? [])
          .map((orderJson) => Order.fromJson(orderJson as Map<String, dynamic>))
          .toList(),
      pagination: OrderPagination.fromJson(json['pagination'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orders': orders.map((order) => order.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

// Pagination model
class OrderPagination {
  final int totalCount;
  final bool hasNextPage;
  final String? nextPageToken;
  final int currentCount;

  OrderPagination({
    required this.totalCount,
    required this.hasNextPage,
    this.nextPageToken,
    required this.currentCount,
  });

  factory OrderPagination.fromJson(Map<String, dynamic> json) {
    return OrderPagination(
      totalCount: json['total_count'] ?? 0,
      hasNextPage: json['has_next_page'] ?? false,
      nextPageToken: json['next_page_token'],
      currentCount: json['current_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_count': totalCount,
      'has_next_page': hasNextPage,
      'next_page_token': nextPageToken,
      'current_count': currentCount,
    };
  }
}
