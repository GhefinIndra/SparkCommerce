import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class AnalyticsService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/analytics';

  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    String? token;
    if (_authService.currentUser != null &&
        _authService.currentUser!.authToken.isNotEmpty) {
      token = _authService.currentUser!.authToken;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = prefs.getString('current_user_email');
      if (currentEmail != null) {
        token = await _authService.getStoredAuthToken(currentEmail);
      }
    }

    if (token != null && token.isNotEmpty) {
      headers['auth_token'] = token;
    }

    return headers;
  }

  Future<Map<String, dynamic>> getSalesSummary({
    String platform = 'all',
    String? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();

      // Build URL
      final endpoint = shopId != null
          ? '$baseUrl/shops/$shopId/sales-summary'
          : '$baseUrl/sales-summary';

      // Build query parameters
      final queryParams = <String, String>{
        'platform': platform,
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to load sales summary');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRevenueTrend({
    String platform = 'all',
    String? shopId,
    DateTime? startDate,
    DateTime? endDate,
    String groupBy = 'day',
  }) async {
    try {
      final headers = await _getHeaders();

      final endpoint = shopId != null
          ? '$baseUrl/shops/$shopId/revenue-trend'
          : '$baseUrl/revenue-trend';

      final queryParams = <String, String>{
        'platform': platform,
        'groupBy': groupBy,
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load revenue trend');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOrderStatusBreakdown({
    String platform = 'all',
    String? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();

      final endpoint = shopId != null
          ? '$baseUrl/shops/$shopId/order-status-breakdown'
          : '$baseUrl/order-status-breakdown';

      final queryParams = <String, String>{
        'platform': platform,
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to load order breakdown');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTopProducts({
    String platform = 'all',
    String? shopId,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'quantity',
    int limit = 10,
  }) async {
    try {
      final headers = await _getHeaders();

      final endpoint = shopId != null
          ? '$baseUrl/shops/$shopId/top-products'
          : '$baseUrl/top-products';

      final queryParams = <String, String>{
        'platform': platform,
        'sortBy': sortBy,
        'limit': limit.toString(),
      };

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load top products');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSKUAnalytics() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/sku-analytics');


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to load SKU analytics');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getShopComparison({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();

      final queryParams = <String, String>{};

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      final uri = Uri.parse('$baseUrl/shop-comparison')
          .replace(queryParameters: queryParams);


      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load shop comparison');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
