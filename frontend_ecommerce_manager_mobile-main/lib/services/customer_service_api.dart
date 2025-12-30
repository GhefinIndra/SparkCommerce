import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class CustomerServiceApiService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/customer-service';

  static Future<Map<String, String>> _getAuthHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

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

  static Future<Map<String, dynamic>> getConversations(
    String shopId, {
    int pageSize = 20,
    String pageToken = '',
    String locale = 'id-ID',
  }) async {
    try {
      final queryParams = {
        'page_size': pageSize.toString(),
        'locale': locale,
        if (pageToken.isNotEmpty) 'page_token': pageToken,
      };

      final uri = Uri.parse('$baseUrl/$shopId/conversations')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeaders());
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final conversations = (data['data']['conversations'] as List)
            .map((json) => Conversation.fromJson(json))
            .toList();

        return {
          'success': true,
          'conversations': conversations,
          'nextPageToken': data['data']['nextPageToken'],
          'shop': data['data']['shop'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to get conversations');
      }
    } catch (e) {
      print('Error getting conversations: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMessages(
    String shopId,
    String conversationId, {
    int pageSize = 10,
    String pageToken = '',
    String locale = 'id-ID',
  }) async {
    try {
      final queryParams = {
        'page_size': pageSize.toString(),
        'locale': locale,
        if (pageToken.isNotEmpty) 'page_token': pageToken,
      };

      final uri =
          Uri.parse('$baseUrl/$shopId/conversations/$conversationId/messages')
              .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeaders());
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        final messages = (data['data']['messages'] as List)
            .map((json) => Message.fromJson(json))
            .toList();

        return {
          'success': true,
          'messages': messages,
          'nextPageToken': data['data']['nextPageToken'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to get messages');
      }
    } catch (e) {
      print('Error getting messages: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createConversation(
    String shopId,
    String buyerUserId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$shopId/conversations'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'buyer_user_id': buyerUserId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'conversationId': data['data']['conversationId'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to create conversation');
      }
    } catch (e) {
      print('Error creating conversation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
    String shopId,
    String conversationId,
    String type,
    String content,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$shopId/conversations/$conversationId/messages'),
        headers: await _getAuthHeaders(),
        body: jsonEncode({
          'type': type,
          'content': content,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'messageId': data['data']['messageId'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      print('Error sending message: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> readMessages(
    String shopId,
    String conversationId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$shopId/conversations/$conversationId/read'),
        headers: await _getAuthHeaders(),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {'success': true};
      } else {
        throw Exception(data['message'] ?? 'Failed to mark messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadImage(
    String shopId,
    File imageFile,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/$shopId/images/upload'),
      );

      final headers = await _getAuthHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      request.files.add(
        await http.MultipartFile.fromPath('data', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return {
          'success': true,
          'url': data['data']['url'],
          'width': data['data']['width'],
          'height': data['data']['height'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to upload image');
      }
    } catch (e) {
      print('Error uploading image: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendTextMessage(
    String shopId,
    String conversationId,
    String text,
  ) async {
    final content = jsonEncode({'content': text});
    return sendMessage(shopId, conversationId, 'TEXT', content);
  }

  static Future<Map<String, dynamic>> sendProductCard(
    String shopId,
    String conversationId,
    String productId,
  ) async {
    final content = jsonEncode({'product_id': productId});
    return sendMessage(shopId, conversationId, 'PRODUCT_CARD', content);
  }

  static Future<Map<String, dynamic>> sendOrderCard(
    String shopId,
    String conversationId,
    String orderId,
  ) async {
    final content = jsonEncode({'order_id': orderId});
    return sendMessage(shopId, conversationId, 'ORDER_CARD', content);
  }
}
