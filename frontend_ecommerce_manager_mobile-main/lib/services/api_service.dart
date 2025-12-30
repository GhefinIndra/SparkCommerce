// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/shop.dart';
import '../models/order.dart';
import '../services/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/app_error.dart';
import '../utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL from compile-time define (BASE_URL)
  static String get baseUrl => AppConfig.apiBaseUrl;

  
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // NEW: Get Aggregated Dashboard Stats (Fast Loading)
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/dashboard/stats'),
            headers: headers,
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      // Fallback if endpoint fails or returns empty
      return {'totalShops': 0, 'totalOrders': 0, 'totalSKUs': 0};
    } catch (e) {
      print('Error fetching dashboard stats: $e');
      // Return zeros instead of throwing to prevent app crash on dashboard
      return {'totalShops': 0, 'totalOrders': 0, 'totalSKUs': 0};
    }
  }

  Future<List<Shop>> getShops() async {
    try {
      final headers = await _getAuthHeaders();
      List<Shop> allShops = [];

      // Fetch TikTok shops
      try {
        final tiktokResponse = await http
            .get(
              Uri.parse('$baseUrl/oauth/tiktok/shops'),
              headers: headers,
            )
            .timeout(Duration(seconds: 10));

        if (tiktokResponse.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(tiktokResponse.body);
          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> shopsJson = data['data'];
            final tiktokShops =
                shopsJson.map((json) => Shop.fromJson(json)).toList();
            allShops.addAll(tiktokShops);
          }
        }
      } catch (e) {
        // swallow per-platform error to keep other platforms loading
      }

      // Fetch Shopee shops
      try {
        final shopeeResponse = await http
            .get(
              Uri.parse('$baseUrl/oauth/shopee/shops'),
              headers: headers,
            )
            .timeout(Duration(seconds: 10));

        if (shopeeResponse.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(shopeeResponse.body);
          if (data['success'] == true && data['data'] != null) {
            final List<dynamic> shopsJson = data['data'];
            final shopeeShops =
                shopsJson.map((json) => Shop.fromJson(json)).toList();
            allShops.addAll(shopeeShops);
          }
        }
      } catch (e) {
        // swallow per-platform error to keep other platforms loading
      }

      return allShops;
    } catch (e) {
      throw AppError.from(e, action: 'memuat data toko');
    }
  }

  Future<bool> deleteShop(String shopId, {required String platform}) async {
    final isShopee = platform.toLowerCase().contains('shopee');
    final url = isShopee
        ? '$baseUrl/oauth/shopee/shops/$shopId'
        : '$baseUrl/oauth/tiktok/shops/$shopId';

    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 10));

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return true;
      }

      if (response.statusCode == 401) {
        await AuthService().logout();
        throw AppError('Sesi berakhir, silakan login lagi.');
      }

      if (response.statusCode == 403) {
        throw AppError('Anda tidak memiliki akses untuk menghapus toko ini');
      }

      final message = data['message'] ?? 'Gagal menghapus toko';
      throw AppError(
        'Gagal menghapus toko (HTTP ${response.statusCode})',
        debugMessage: message,
      );
    } catch (e) {
      throw AppError.from(e, action: 'menghapus toko');
    }
  }

  
  
  Future<Shop> getShopInfo(String shopId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/oauth/shops/$shopId'), 
            headers: await _getAuthHeaders(), 
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Shop.fromJson(data['data']);
        } else {
          throw AppError(
            data['message'] ?? 'Toko tidak ditemukan',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 401) {
        
        await AuthService().logout();
        throw AppError('Sesi berakhir, silakan login lagi.');
      } else if (response.statusCode == 403) {
        throw AppError('Akses ditolak ke toko ini');
      } else if (response.statusCode == 404) {
        throw AppError('Toko tidak ditemukan');
      } else {
        throw AppError(
          'Gagal memuat info toko (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat info toko');
    }
  }

  
  String getAuthorizationUrl() {
    return '$baseUrl/oauth/authorize';
  }

  
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  

  
  Future<Map<String, dynamic>> getProducts(String shopId,
      {int page = 1, int limit = 20}) async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/shops/$shopId/products?page=$page&limit=$limit'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat produk',
            debugMessage: data.toString(),
          );
        }
      } else {
        throw AppError(
          'Gagal memuat produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat data produk');
    }
  }

  
  Future<Map<String, dynamic>> getShopeeProducts(String shopId,
      {int offset = 0, int pageSize = 20, String itemStatus = 'NORMAL'}) async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/shopee/shops/$shopId/products?offset=$offset&page_size=$pageSize&item_status=$itemStatus'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15)); // Longer timeout for Shopee batch API


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat produk Shopee',
            debugMessage: data.toString(),
          );
        }
      } else {
        throw AppError(
          'Gagal memuat produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat data produk Shopee');
    }
  }

  // Get product detail (TikTok)
  Future<Map<String, dynamic>> getProductDetail(
      String shopId, String productId) async {
    try {
      print(
          ' Fetching TikTok product detail from: $baseUrl/shops/$shopId/products/$productId');

      final response = await http.get(
        Uri.parse('$baseUrl/shops/$shopId/products/$productId'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat detail produk',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 404) {
        throw AppError('Produk tidak ditemukan', debugMessage: response.body);
      } else {
        throw AppError(
          'Gagal memuat detail produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat detail produk');
    }
  }

  // Get product detail (Shopee)
  Future<Map<String, dynamic>> getShopeeProductDetail(
      String shopId, String productId) async {
    try {
      print(
          '️ Fetching Shopee product detail from: $baseUrl/shopee/shops/$shopId/products/$productId');

      final response = await http.get(
        Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15)); // Longer timeout for Shopee (might call 2 APIs)


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat detail produk Shopee',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 404) {
        throw AppError('Produk tidak ditemukan', debugMessage: response.body);
      } else if (response.statusCode == 503) {
        throw AppError(
          'Shopee API sedang tidak tersedia, coba lagi nanti',
          debugMessage: response.body,
        );
      } else {
        throw AppError(
          'Gagal memuat detail produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat detail produk Shopee');
    }
  }

  // Update Shopee product price
  Future<bool> updateShopeeProductPrice(
      String shopId, String productId, List<Map<String, dynamic>> skus) async {
    try {
      print(
          ' Updating Shopee product price: $baseUrl/shopee/shops/$shopId/products/$productId/price');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId/price'),
            headers: await _getAuthHeaders(),
            body: json.encode({'skus': skus}),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Check for partial failures
        if (data['warning'] != null) {
        }

        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui harga produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui harga produk Shopee');
    }
  }

  // Update Shopee product stock
  Future<bool> updateShopeeProductStock(
      String shopId, String productId, List<Map<String, dynamic>> skus) async {
    try {
      print(
          ' Updating Shopee product stock: $baseUrl/shopee/shops/$shopId/products/$productId/stock');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId/stock'),
            headers: await _getAuthHeaders(),
            body: json.encode({'skus': skus}),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Check for partial failures
        if (data['warning'] != null) {
        }

        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui stok produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui stok produk Shopee');
    }
  }

  // Update Shopee product info
  Future<bool> updateShopeeProductInfo(String shopId, String productId,
      {String? title, String? description}) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;

      print(
          '️ Updating Shopee product info: $baseUrl/shopee/shops/$shopId/products/$productId/info');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId/info'),
            headers: await _getAuthHeaders(),
            body: json.encode(body),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui info produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui info produk Shopee');
    }
  }

  // Update Shopee product images
  Future<bool> updateShopeeProductImages(
      String shopId, String productId, List<String> imageIds) async {
    try {
      print(
          '️ Updating Shopee product images: $baseUrl/shopee/shops/$shopId/products/$productId/images');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId/images'),
            headers: await _getAuthHeaders(),
            body: json.encode({'image_ids': imageIds}),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui gambar produk Shopee (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui gambar produk Shopee');
    }
  }

  // Update product info (title, description)
  Future<bool> updateProductInfo(String shopId, String productId,
      {String? title, String? description}) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;

      print(
          ' Updating product info: $baseUrl/shops/$shopId/products/$productId/info');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shops/$shopId/products/$productId/info'),
            headers: await _getAuthHeaders(),
            body: json.encode(body),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui info produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui info produk');
    }
  }

  // Update product price
  Future<bool> updateProductPrice(
      String shopId, String productId, List<Map<String, dynamic>> skus) async {
    try {
      print(
          ' Updating product price: $baseUrl/shops/$shopId/products/$productId/price');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shops/$shopId/products/$productId/price'),
            headers: await _getAuthHeaders(),
            body: json.encode({'skus': skus}),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui harga produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui harga produk');
    }
  }

  // Update product stock
  Future<bool> updateProductStock(
      String shopId, String productId, List<Map<String, dynamic>> skus) async {
    try {
      print(
          ' Updating product stock: $baseUrl/shops/$shopId/products/$productId/stock');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shops/$shopId/products/$productId/stock'),
            headers: await _getAuthHeaders(),
            body: json.encode({'skus': skus}),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui stok produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui stok produk');
    }
  }

  // Delete product (TikTok)
  Future<bool> deleteProduct(String shopId, String productId) async {
    try {

      final response = await http.delete(
        Uri.parse('$baseUrl/shops/$shopId/products/$productId'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal menghapus produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'menghapus produk');
    }
  }

  // Delete Shopee product (permanent deletion)
  Future<bool> deleteShopeeProduct(String shopId, String productId) async {
    try {

      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId'),
        headers: headers,
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          throw AppError(
            data['message'] ?? 'Gagal menghapus produk Shopee',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 404) {
        throw AppError(
          'Produk tidak ditemukan atau sudah dihapus',
          debugMessage: response.body,
        );
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        throw AppError(
          data['message'] ?? 'Gagal menghapus produk Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'menghapus produk Shopee');
    }
  }

  // Unlist/List Shopee product (deactivate/activate)
  Future<bool> unlistShopeeProduct(
    String shopId,
    String productId, {
    bool unlist = true,
  }) async {
    try {

      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/shopee/shops/$shopId/products/$productId/unlist'),
        headers: headers,
        body: json.encode({'unlist': unlist}),
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          throw AppError(
            data['message'] ?? 'Gagal mengubah status produk',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Handle specific error like "Can't unlist item when item is under promotion"
        throw AppError(
          data['message'] ?? 'Gagal mengubah status produk',
          debugMessage: data.toString(),
        );
      } else {
        final Map<String, dynamic> data = json.decode(response.body);
        throw AppError(
          data['message'] ?? 'Gagal mengubah status produk',
          debugMessage: data.toString(),
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'mengubah status produk');
    }
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final authService = AuthService();
    if (authService.currentUser != null &&
        authService.currentUser!.authToken.isNotEmpty) {
      headers['auth_token'] = authService.currentUser!.authToken;
    }

    return headers;
  }

  // Get categories for specific shop
  // Update existing getCategories method to use new endpoint
  Future<Map<String, dynamic>> getCategories(String shopId,
      {String? parentId}) async {
    try {
      final Map<String, String> queryParams = {};

      if (parentId != null && parentId.isNotEmpty) {
        queryParams['parent_id'] = parentId;
      }

      final uri = Uri.parse('$baseUrl/categories/$shopId').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);


      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw AppError(
          data['message'] ?? 'Gagal memuat kategori',
          debugMessage: data.toString(),
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat kategori');
    }
  }

  Future<Map<String, dynamic>> getRootCategories(String shopId) async {
    return await getCategories(shopId);
  }


  Future<Map<String, dynamic>> getChildCategories(
      String shopId, String parentId) async {
    return await getCategories(shopId, parentId: parentId);
  }

  Future<Map<String, dynamic>> getCategoryAttributes(
      String shopId, String categoryId) async {
    try {
      
      final uri =
          Uri.parse('$baseUrl/categories/$shopId/$categoryId/attributes');


      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        print(
            ' Category attributes loaded: ${data['data']?.length ?? 0} attributes');
        return data;
      } else {
        throw AppError(
          data['message'] ?? 'Gagal memuat atribut kategori',
          debugMessage: data.toString(),
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat atribut kategori');
    }
  }

  Future<Map<String, dynamic>> getCategoryRules(
      String shopId, String categoryId) async {
    try {
      final uri = Uri.parse('$baseUrl/categories/$shopId/$categoryId/rules');


      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw AppError(
          data['message'] ?? 'Gagal memuat aturan kategori',
          debugMessage: data.toString(),
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat aturan kategori');
    }
  }

  Future<Map<String, dynamic>> getCategoryComplete(
      String shopId, String categoryId) async {
    try {
      final uri = Uri.parse('$baseUrl/categories/$shopId/$categoryId/complete');


      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        return data;
      } else {
        throw AppError(
          data['message'] ?? 'Gagal memuat info kategori',
          debugMessage: data.toString(),
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat info kategori');
    }
  }

// Update existing createProduct method to use correct endpoint
  Future<Map<String, dynamic>> createProduct(
      String shopId, Map<String, dynamic> productData) async {
    try{
      final uri = Uri.parse('$baseUrl/product/202309/products');

      productData['shop_id'] = shopId;


      final response = await http
          .post(
            uri,
            headers: await _getAuthHeaders(),
            body: json.encode(productData),
          )
          .timeout(Duration(seconds: 30)); // Timeout lebih lama untuk create


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw AppError(
            _pickApiErrorMessage(data, 'Gagal membuat produk'),
            debugMessage: response.body,
          );
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw AppError(
            _pickApiErrorMessage(
              errorData,
              'Gagal membuat produk (HTTP ${response.statusCode})',
            ),
            debugMessage: response.body,
          );
        } catch (jsonError) {
          throw AppError(
            'Gagal membuat produk (HTTP ${response.statusCode})',
            debugMessage: response.body,
          );
        }
      }
    } catch (e) {
      throw AppError.from(e, action: 'membuat produk');
    }
  }

  Future<List<Order>> getOrders(String shopId) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/orders/$shopId/list'),
            headers: await _getAuthHeaders(),
            body: json.encode({'page_size': 20, 'sort_order': 'DESC'}),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          
          final ordersData = data['data']['orders']
              as List?; // Bukan data['data']['data']['orders']
          if (ordersData != null) {
            return ordersData.map((json) => Order.fromJson(json)).toList();
          }
          return [];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat pesanan',
            debugMessage: data.toString(),
          );
        }
      } else {
        throw AppError(
          'Gagal memuat pesanan (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat pesanan');
    }
  }

  // Get order detail
  Future<Order> getOrderDetail(String shopId, String orderId) async {
    try {

      final response = await http.get(
        Uri.parse('$baseUrl/orders/$shopId/detail/$orderId'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          
          if (data['data']['orders'] != null &&
              data['data']['orders'] is List) {
            final orders = data['data']['orders'] as List;
            if (orders.isNotEmpty) {
              final orderData = orders[0] as Map<String, dynamic>;
              return Order.fromJson(orderData);
            } else {
              throw AppError('Pesanan tidak ditemukan dalam respons');
            }
          }
          // Fallback: coba data langsung jika bukan array
          else if (data['data'] is Map<String, dynamic>) {
            return Order.fromJson(data['data'] as Map<String, dynamic>);
          } else {
            throw AppError('Struktur respons tidak valid (order tidak ada)');
          }
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat detail pesanan',
            debugMessage: data.toString(),
          );
        }
      } else {
        throw AppError(
          'Gagal memuat detail pesanan (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat detail pesanan');
    }
  }

  // ========================================
  // SHOPEE ORDER METHODS
  // ========================================

  /// Get Shopee orders with time range filter
  Future<List<Order>> getShopeeOrders(
    String shopId, {
    int? timeFrom,
    int? timeTo,
    int pageSize = 20,
    String cursor = '',
    String? orderStatus,
  }) async {
    try {
      // Default to last 15 days if not specified
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final defaultTimeFrom = now - (15 * 24 * 60 * 60); // 15 days ago


      final response = await http
          .post(
            Uri.parse('$baseUrl/shopee/orders/$shopId/list'),
            headers: await _getAuthHeaders(),
            body: json.encode({
              'time_range_field': 'create_time',
              'time_from': timeFrom ?? defaultTimeFrom,
              'time_to': timeTo ?? now,
              'page_size': pageSize,
              'cursor': cursor,
              if (orderStatus != null) 'order_status': orderStatus,
              // Sesuai dokumentasi Shopee: get_order_list hanya support order_status
              'response_optional_fields': 'order_status',
            }),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final ordersData = data['data']['orders'] as List?;
          if (ordersData != null) {
            return ordersData.map((json) => Order.fromJson(json)).toList();
          }
          return [];
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat pesanan Shopee',
            debugMessage: data.toString(),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat pesanan Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat pesanan Shopee');
    }
  }

  /// Get Shopee order detail
  Future<Order> getShopeeOrderDetail(String shopId, String orderSn) async {
    try {

      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/shopee/orders/$shopId/detail/$orderSn?response_optional_fields=buyer_user_id,buyer_username,estimated_shipping_fee,recipient_address,actual_shipping_fee,item_list,pay_time,package_list,shipping_carrier,payment_method,total_amount'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 15));

      print(
          ' Shopee Order Detail API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          if (data['data']['orders'] != null &&
              data['data']['orders'] is List) {
            final orders = data['data']['orders'] as List;
            if (orders.isNotEmpty) {
              final orderData = orders[0] as Map<String, dynamic>;
              return Order.fromJson(orderData);
            } else {
              throw AppError('Pesanan Shopee tidak ditemukan dalam respons');
            }
          } else {
            throw AppError('Struktur respons tidak valid (order Shopee tidak ada)');
          }
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat detail pesanan Shopee',
            debugMessage: data.toString(),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat detail pesanan Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat detail pesanan Shopee');
    }
  }

  /// Ship Shopee order
  Future<Map<String, dynamic>> shipShopeeOrder(
    String shopId,
    String orderSn,
    Map<String, dynamic> shipmentData,
  ) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/shopee/orders/$shopId/ship/$orderSn'),
            headers: await _getAuthHeaders(),
            body: json.encode(shipmentData),
          )
          .timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw AppError(
            data['message'] ?? 'Gagal mengirim pesanan Shopee',
            debugMessage: data.toString(),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal mengirim pesanan Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'mengirim pesanan Shopee');
    }
  }

  /// Get Shopee tracking number
  Future<Map<String, dynamic>> getShopeeTrackingNumber(
    String shopId,
    String orderSn,
  ) async {
    try {

      final response = await http
          .get(
            Uri.parse('$baseUrl/shopee/orders/$shopId/tracking/$orderSn'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 15));

      print(
          ' Shopee Tracking Number Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw AppError(
            data['message'] ?? 'Gagal mendapatkan nomor resi Shopee',
            debugMessage: data.toString(),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal mendapatkan nomor resi Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat nomor resi Shopee');
    }
  }

  String _getImageType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'bmp':
        return 'bmp';
      case 'heic':
        return 'heic';
      default:
        return 'jpeg';
    }
  }

  // services/api_service.dart - Kembalikan ke single upload
  Future<Map<String, dynamic>> uploadProductImage(String shopId, File imageFile,
      {String useCase = 'MAIN_IMAGE'}) async {
    try {
      

      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/images/$shopId/upload'));

      final authHeaders = await _getAuthHeaders();
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);

      // Single file dengan field name 'data' (sesuai TikTok API)
      request.files.add(
        await http.MultipartFile.fromPath(
          'data',
          imageFile.path,
          contentType: MediaType('image', _getImageType(imageFile.path)),
        ),
      );

      request.fields['use_case'] = useCase;

      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: 60)); // Sesuai timeout backend
      final response = await http.Response.fromStream(streamedResponse);

      print(
          ' Single Upload Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          
          return responseData[
              'data']; // Contains: uri, url, width, height, use_case
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal upload gambar',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal upload gambar',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'upload gambar');
    }
  }

  // Upload Shopee product image
  Future<Map<String, dynamic>> uploadShopeeProductImage(String shopId, File imageFile,
      {String scene = 'normal', String ratio = '1:1'}) async {
    try {

      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/shopee/images/$shopId/upload'));

      final authHeaders = await _getAuthHeaders();
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);

      // Single file dengan field name 'image' (sesuai Shopee API)
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', _getImageType(imageFile.path)),
        ),
      );

      request.fields['scene'] = scene; // 'normal' or 'desc'
      request.fields['ratio'] = ratio; // '1:1' or '3:4'

      final streamedResponse = await request
          .send()
          .timeout(Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      print(
          ' Shopee Upload Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData['data']; // Contains: image_id, image_url, uri, url
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal upload gambar Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal upload gambar Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'upload gambar Shopee');
    }
  }

  // ==================== SHOPEE CREATE PRODUCT METHODS ====================

  /// Get Shopee Categories
  /// GET /api/shopee/categories?shop_id=xxx&language=en
  Future<Map<String, dynamic>> getShopeeCategories(
    String shopId, {
    String language = 'en',
  }) async {
    try {
      final queryParams = {
        'shop_id': shopId,
        'language': language,
      };

      final uri = Uri.parse('$baseUrl/shopee/categories')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal memuat kategori Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat kategori Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat kategori Shopee');
    }
  }

  /// Get Shopee Category Attributes
  /// GET /api/shopee/categories/:categoryId/attributes?shop_id=xxx&language=en
  Future<Map<String, dynamic>> getShopeeCategoryAttributes(
    String shopId,
    int categoryId, {
    String language = 'en',
  }) async {
    try {
      final queryParams = {
        'shop_id': shopId,
        'language': language,
      };

      final uri = Uri.parse('$baseUrl/shopee/categories/$categoryId/attributes')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal memuat atribut kategori Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat atribut kategori Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat atribut kategori Shopee');
    }
  }

  /// Get Shopee Brand List
  /// GET /api/shopee/categories/:categoryId/brands?shop_id=xxx&offset=0&page_size=100&status=1&language=en
  Future<Map<String, dynamic>> getShopeeBrandList(
    String shopId,
    int categoryId, {
    int offset = 0,
    int pageSize = 100,
    int status = 1,
    String language = 'en',
  }) async {
    try {
      final queryParams = {
        'shop_id': shopId,
        'offset': offset.toString(),
        'page_size': pageSize.toString(),
        'status': status.toString(),
        'language': language,
      };

      final uri = Uri.parse('$baseUrl/shopee/categories/$categoryId/brands')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal memuat daftar brand Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat daftar brand Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat daftar brand Shopee');
    }
  }

  /// Get Shopee Logistics Channels
  /// GET /api/shopee/logistics/channels?shop_id=xxx
  Future<Map<String, dynamic>> getShopeeLogisticsChannels(String shopId) async {
    try {
      final queryParams = {'shop_id': shopId};

      final uri = Uri.parse('$baseUrl/shopee/logistics/channels')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal memuat channel logistik Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat channel logistik Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat channel logistik Shopee');
    }
  }

  /// Create Shopee Product
  /// POST /api/shopee/shops/:shopId/products
  Future<Map<String, dynamic>> createShopeeProduct(
    String shopId,
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shopee/shops/$shopId/products'),
        headers: await _getAuthHeaders(),
        body: json.encode(productData),
      ).timeout(Duration(seconds: 30));

      print(' API Response [Create Shopee Product]: ${response.statusCode}');
      print(' Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData;
        } else {
          throw AppError(
            _pickApiErrorMessage(
              responseData,
              'Gagal membuat produk Shopee',
            ),
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          _pickApiErrorMessage(
            errorData,
            'Gagal membuat produk Shopee',
          ),
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'membuat produk Shopee');
    }
  }

  /// Get Shopee item limits and validation rules
  Future<Map<String, dynamic>> getShopeeItemLimits(
    String shopId, {
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'shop_id': shopId,
      };

      if (categoryId != null) {
        queryParams['category_id'] = categoryId.toString();
      }

      final uri = Uri.parse('$baseUrl/shopee/item-limits').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));

      print(' API Response [Get Shopee Item Limits]: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          return responseData['data'] ?? {};
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal memuat batasan item Shopee',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat batasan item Shopee',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      print('️ Failed to get item limits (non-critical): $e');
      // Return empty limits if API fails (non-critical)
      return {};
    }
  }

  // ==================== END SHOPEE CREATE PRODUCT METHODS ====================


  Future<Map<String, dynamic>> uploadMultipleImages(
      String shopId, List<File> imageFiles,
      {String useCase = 'MAIN_IMAGE'}) async {
    try {
      if (imageFiles.length > 9) {
        throw AppError('Maksimal 9 gambar per upload');
      }

      print(
          ' Uploading multiple images: $baseUrl/images/$shopId/upload-multiple');

      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/images/$shopId/upload-multiple'));

      final authHeaders = await _getAuthHeaders();
      authHeaders.remove('Content-Type');
      request.headers.addAll(authHeaders);

      // Multiple files dengan field name 'data'
      for (File imageFile in imageFiles) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'data',
            imageFile.path,
            contentType: MediaType('image', _getImageType(imageFile.path)),
          ),
        );
      }

      request.fields['use_case'] = useCase;

      final streamedResponse =
          await request.send().timeout(Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      print(
          ' Multiple Upload Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true ||
            responseData['data']['successful_count'] > 0) {
          return responseData[
              'data']; // Contains: successful_uploads, failed_uploads, counts
        } else {
          throw AppError(
            responseData['message'] ?? 'Gagal upload gambar',
            debugMessage: response.body,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal upload gambar',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'upload gambar');
    }
  }

// Update product images (tetap sama, sudah benar)
  Future<bool> updateProductImages(String shopId, String productId,
      List<Map<String, dynamic>> images) async {
    try {
      print(
          ' Updating product images: $baseUrl/products/shops/$shopId/products/$productId/images');

      final response = await http
          .put(
            Uri.parse('$baseUrl/shops/$shopId/products/$productId/images'),
            headers: await _getAuthHeaders(),
            body: json.encode({'images': images}),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal memperbarui gambar produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memperbarui gambar produk');
    }
  }

  Future<Map<String, dynamic>> getBrands(String shopId,
      {String? categoryId}) async {
    try {
      final url = '$baseUrl/shops/$shopId/brands';

      Map<String, String> queryParams = {};
      if (categoryId != null && categoryId.isNotEmpty) {
        queryParams['category_id'] = categoryId;
      }

      final uri = Uri.parse(url).replace(queryParameters: queryParams);


      final response = await http.get(
        uri,
        headers: await _getAuthHeaders(),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat brand',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat brand');
    }
  }

  // Create custom brand
  Future<Map<String, dynamic>> createBrand(
      String shopId, String brandName) async {
    try {
      final url = '$baseUrl/product/$shopId/brands';


      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: json.encode({'name': brandName}),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal membuat brand',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'membuat brand');
    }
  }

  Future<List<Map<String, dynamic>>> getWarehouses(String shopId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shops/$shopId/warehouses'),
        headers: await _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw AppError(
          'Gagal memuat gudang (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat gudang');
    }
  }

// Get Category Rules with Size Chart info
  Future<Map<String, dynamic>> getCategoryRulesWithSizeChart(
      String shopId, String categoryId) async {
    try {
      print(
          ' API: Getting category rules with size chart for category: $categoryId');

      
      final url =
          '$baseUrl/categories/$shopId/$categoryId/rules-with-sizechart';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat aturan kategori',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

// Get Size Chart Templates
  Future<Map<String, dynamic>> getSizeChartTemplates(
    String shopId, {
    String? keyword,
    int? limit,
  }) async {
    try {

      var url = '$baseUrl/categories/$shopId/size-charts';

      // Add query parameters
      List<String> queryParams = [];
      if (keyword != null && keyword.isNotEmpty) {
        queryParams.add('keyword=${Uri.encodeComponent(keyword)}');
      }
      if (limit != null) {
        queryParams.add('limit=$limit');
      }

      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
      );


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
            ' Size chart templates retrieved: ${data['data']?.length ?? 0} templates');
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat template size chart',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

// Upload Size Chart Image (using existing uploadProductImage method with different useCase)
  Future<Map<String, dynamic>> uploadSizeChartImage(
    String shopId,
    File imageFile,
  ) async {
    try {

      // Reuse existing uploadProductImage method with SIZE_CHART_IMAGE use case
      final result = await uploadProductImage(
        shopId,
        imageFile,
        useCase: 'SIZE_CHART_IMAGE',
      );

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProductWithRules(
      String shopId, Map<String, dynamic> productData) async {
    try {

      // Add shop_id to the request body
      final requestData = Map<String, dynamic>.from(productData);
      requestData['shop_id'] = shopId;

      // DEBUG: Print URL sebelum request
      final url = '$baseUrl/product/202309/products';

      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(),
        body: json.encode(requestData),
      );

      print(
          ' API Response [Create Product with Rules]: ${response.statusCode}');
      print(
          ' Response body (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Log warnings if any
        if (responseData['data']?['warnings'] != null) {
        }

        return responseData;
      } else {
        final errorData = json.decode(response.body);
        print(
            ' API Error [Create Product with Rules]: ${errorData['message']}');
        throw AppError(
          _pickApiErrorMessage(
            errorData,
            'Gagal membuat produk (dengan rules)',
          ),
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

// Activate Product
  Future<bool> activateProduct(String shopId, String productId) async {
    try {
      print(
          ' Activating product: $baseUrl/shops/$shopId/products/$productId/activate');

      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/products/$productId/activate'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal mengaktifkan produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'mengaktifkan produk');
    }
  }

// Deactivate Product
  Future<bool> deactivateProduct(String shopId, String productId) async {
    try {
      print(
          ' Deactivating product: $baseUrl/shops/$shopId/products/$productId/deactivate');

      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/products/$productId/deactivate'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal menonaktifkan produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'menonaktifkan produk');
    }
  }

// Recover Product
  Future<bool> recoverProduct(String shopId, String productId) async {
    try {
      print(
          ' Recovering product: $baseUrl/shops/$shopId/products/$productId/recover');

      final response = await http.post(
        Uri.parse('$baseUrl/shops/$shopId/products/$productId/recover'),
        headers: await _getAuthHeaders(),
      ).timeout(Duration(seconds: 15));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw AppError(
          'Gagal mengembalikan produk (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'mengembalikan produk');
    }
  }
  // Tambah methods ini ke class ApiService

// Ship Package
// Ship Package
  Future<Map<String, dynamic>> shipPackage(
    String shopId,
    String packageId, {
    String handoverMethod = 'PICKUP',
    Map<String, dynamic>? pickupSlot,
    Map<String, dynamic>? selfShipment,
  }) async {
    try {
      final url = '$baseUrl/orders/$shopId/packages/$packageId/ship';

      final requestBody = <String, dynamic>{
        'handover_method': handoverMethod,
      };

      if (pickupSlot != null) {
        requestBody['pickup_slot'] = pickupSlot;
      }

      if (selfShipment != null) {
        requestBody['self_shipment'] = selfShipment;
      }


      final response = await http.post(
        Uri.parse(url),
        headers: await _getAuthHeaders(), 
        body: json.encode(requestBody),
      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal mengirim paket',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

// Get Shipping Document
  Future<Map<String, dynamic>> getShippingDocument(
    String shopId,
    String packageId, {
    String documentType = 'SHIPPING_LABEL',
    String documentSize = 'A6',
    String documentFormat = 'PDF',
  }) async {
    try {
      final queryParams = {
        'document_type': documentType,
        'document_size': documentSize,
        'document_format': documentFormat,
      };

      final uri = Uri.parse(
              '$baseUrl/orders/$shopId/packages/$packageId/shipping-document')
          .replace(queryParameters: queryParams);


      final response = await http.get(uri,
          headers: await _getAuthHeaders()); 


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal mengambil dokumen pengiriman',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

// Get Package Detail
  Future<Map<String, dynamic>> getPackageDetail(
    String shopId,
    String packageId,
  ) async {
    try {
      final url = '$baseUrl/orders/$shopId/packages/$packageId/detail';


      final response = await http.get(
        Uri.parse(url),
        headers: await _getAuthHeaders(), 
      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw AppError(
          errorData['message'] ?? 'Gagal memuat detail paket',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  String _pickApiErrorMessage(Map<String, dynamic> data, String fallback) {
    String? errorMessage;

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      errorMessage = error.trim();
    } else if (error is Map<String, dynamic>) {
      final inner = error['message'] ?? error['error'] ?? error['msg'];
      if (inner is String && inner.trim().isNotEmpty) {
        errorMessage = inner.trim();
      }
    }

    final message = data['message'];
    if ((errorMessage == null || errorMessage.isEmpty) &&
        message is String &&
        message.trim().isNotEmpty) {
      errorMessage = message.trim();
    }

    final suggestion = data['suggestion'];
    final suggestionText = (suggestion is String && suggestion.trim().isNotEmpty)
        ? suggestion.trim()
        : null;

    if (errorMessage == null || errorMessage.isEmpty) {
      errorMessage = fallback;
    }

    if (suggestionText != null) {
      return '$errorMessage Saran: $suggestionText';
    }

    return errorMessage;
  }

// lib/services/api_service.dart - Extension untuk authenticated requests

  // Private method untuk mendapatkan headers dengan auth token
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Get current user's auth token
    final authService = AuthService();
    String? token;

    if (authService.currentUser != null &&
        authService.currentUser!.authToken.isNotEmpty) {
      token = authService.currentUser!.authToken;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('current_user_email');
      if (currentEmail != null) {
        token = await authService.getStoredAuthToken(currentEmail);
      }
    }

    if (token != null && token.isNotEmpty) {
      headers['auth_token'] = token;
    }

    return headers;
  }

  // Updated getShops method dengan authentication
  Future<List<Shop>> getShopsAuthenticated() async {
    try {

      final response = await http
          .get(
            Uri.parse('$baseUrl/oauth/shops'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> shopsJson = data['data'];
          return shopsJson.map((json) => Shop.fromJson(json)).toList();
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat toko',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid - redirect to login
        await AuthService().logout();
        throw AppError('Sesi berakhir, silakan login lagi.');
      } else {
        throw AppError(
          'Gagal memuat toko (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat data toko');
    }
  }

  // Updated getShopInfo method dengan authentication
  Future<Shop> getShopInfoAuthenticated(String shopId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/oauth/shops/$shopId/info'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Shop.fromJson(data['data']);
        } else {
          throw AppError(
            data['message'] ?? 'Toko tidak ditemukan',
            debugMessage: data.toString(),
          );
        }
      } else if (response.statusCode == 401) {
        await AuthService().logout();
        throw AppError('Sesi berakhir, silakan login lagi.');
      } else if (response.statusCode == 404) {
        throw AppError('Toko tidak ditemukan');
      } else {
        throw AppError(
          'Gagal memuat info toko (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat info toko');
    }
  }

  // Method untuk mendapatkan authorization URL dengan user token
  String getAuthorizationUrlWithUserToken() {
    final authService = AuthService();
    if (authService.currentUser != null) {
      return '$baseUrl/oauth/authorize?user_token=${authService.currentUser!.authToken}';
    } else {
      return '$baseUrl/oauth/authorize';
    }
  }

  



// Get available shops (unclaimed)
  Future<List<Shop>> getAvailableShops() async {
    try {

      final response = await http
          .get(
            Uri.parse('$baseUrl/oauth/shops-available'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> shopData = data['data'] ?? [];
          return shopData.map((json) => Shop.fromJson(json)).toList();
        } else {
          throw AppError(
            data['message'] ?? 'Gagal memuat toko yang tersedia',
            debugMessage: data.toString(),
          );
        }
      } else {
        throw AppError(
          'Gagal memuat toko yang tersedia (HTTP ${response.statusCode})',
          debugMessage: response.body,
        );
      }
    } catch (e) {
      throw AppError.from(e, action: 'memuat toko yang tersedia');
    }
  }

// Claim shop
  Future<Map<String, dynamic>> claimShop(String shopId) async {
    try {

      final response = await http
          .post(
            Uri.parse('$baseUrl/oauth/shops/claim/$shopId'),
            headers: await _getAuthHeaders(),
          )
          .timeout(Duration(seconds: 10));


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'] ?? 'Shop claimed successfully',
            'data': data['data']
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to claim shop'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'HTTP ${response.statusCode}: Server error'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal mengklaim toko: ${e.toString()}'
      };
    }
  }
}
