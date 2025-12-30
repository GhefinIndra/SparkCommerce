import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../utils/app_config.dart';

class AuthService {
  static String get baseUrl => '${AppConfig.apiBaseUrl}/user';
  static const String _currentUserEmailKey = 'current_user_email';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  Map<String, String> _getHeaders({String? authToken}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken != null) {
      headers['auth_token'] = authToken;
    }

    return headers;
  }

  String _getUserTokenKey(String email) {
    return 'user_auth_token_${email.toLowerCase().replaceAll('@', '_at_').replaceAll('.', '_dot_')}';
  }

  String _getUserDataKey(String email) {
    return 'user_data_${email.toLowerCase().replaceAll('@', '_at_').replaceAll('.', '_dot_')}';
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? groupId,
  }) async {
    try {
      final requestBody = {
        'name': name.trim(),
        'email': email.toLowerCase().trim(),
        'password': password,
      };

      if (groupId != null && groupId.trim().isNotEmpty) {
        requestBody['group_id'] = groupId.trim();
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: _getHeaders(),
            body: json.encode(requestBody),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'success': true,
            'message': 'Registrasi berhasil! Silakan login.',
            'data': data['data']
          };
        } else {
          throw Exception(data['message'] ?? 'Registration failed');
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Invalid data provided');
      } else {
        throw Exception('HTTP ${response.statusCode}: Registration failed');
      }
    } on SocketException {
      throw Exception(
          'Tidak dapat terhubung ke server. Pastikan server berjalan.');
    } on FormatException {
      throw Exception('Format response tidak valid dari server');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal mendaftar: ${e.toString()}');
    }
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: _getHeaders(),
            body: json.encode({
              'email': email.toLowerCase().trim(),
              'password': password,
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];

          if (userData['auth_token'] == null) {
            throw Exception('No auth token received from server');
          }

          final user = User.fromJson(userData);

          await _saveUserSession(user);
          _currentUser = user;

          await _setCurrentUserEmail(user.email);

          return user;
        } else {
          throw Exception(data['message'] ?? 'Login failed');
        }
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Email atau password salah');
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Data tidak valid');
      } else {
        throw Exception('HTTP ${response.statusCode}: Login failed');
      }
    } on SocketException {
      throw Exception(
          'Tidak dapat terhubung ke server. Pastikan server berjalan.');
    } on FormatException {
      throw Exception('Format response tidak valid dari server');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal login: ${e.toString()}');
    }
  }

  Future<User> getProfile() async {
    try {
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('No current user found');
      }

      final authToken = await getStoredAuthToken(currentEmail);
      if (authToken == null) {
        throw Exception('No auth token found');
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/profile'),
            headers: _getHeaders(authToken: authToken),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final userData = data['data'];
          userData['auth_token'] = authToken;
          final user = User.fromJson(userData);
          _currentUser = user;
          return user;
        } else {
          throw Exception(data['message'] ?? 'Failed to load profile');
        }
      } else if (response.statusCode == 401) {
        await _clearUserSession(currentEmail);
        throw Exception('Session expired');
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load profile');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server');
    } on FormatException {
      throw Exception('Format response tidak valid dari server');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Gagal memuat profil: ${e.toString()}');
    }
  }

  Future<User> updateProfile({
    required String name,
    String? phone,
    String? groupId,
  }) async {
    try {
      // Validasi input
      if (name.trim().isEmpty) {
        throw Exception('Nama tidak boleh kosong');
      }

      // Get current user email
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('No current user found');
      }

      final token = await getStoredAuthToken(currentEmail);

      if (token == null || token.isEmpty) {
        await logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      }

      // Siapkan data untuk request
      final Map<String, dynamic> requestData = {
        'name': name.trim(),
      };

      if (phone != null && phone.trim().isNotEmpty) {
        requestData['phone'] = phone.trim();
      }

      if (groupId != null && groupId.trim().isNotEmpty) {
        requestData['group_id'] = groupId.trim();
      }


      // Kirim request ke server
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: _getHeaders(authToken: token),
        body: json.encode(requestData),
      );


      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          
          final userData = responseData['data'];
          userData['auth_token'] = token;
          final updatedUser = User.fromJson(userData);

          await _saveUserSession(updatedUser);
          _currentUser = updatedUser;

          return updatedUser;
        } else {
          throw Exception(
              responseData['message'] ?? 'Gagal memperbarui profil');
        }
      } else if (response.statusCode == 401) {
        
        await logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 422) {
        final responseData = json.decode(response.body);
        String errorMessage = 'Data tidak valid';

        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first.toString();
          }
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }

        throw Exception(errorMessage);
      } else {
        final responseData = json.decode(response.body);
        throw Exception(
            responseData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Network error: ${e.toString()}');
      }
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (currentPassword.isEmpty) {
        throw Exception('Password saat ini tidak boleh kosong');
      }

      if (newPassword.isEmpty) {
        throw Exception('Password baru tidak boleh kosong');
      }

      if (newPassword.length < 6) {
        throw Exception('Password baru minimal 6 karakter');
      }

      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail == null) {
        throw Exception('No current user found');
      }

      final token = await getStoredAuthToken(currentEmail);

      if (token == null || token.isEmpty) {
        await logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      }

      // Siapkan data untuk request
      final Map<String, dynamic> requestData = {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/change-password'),
        headers: _getHeaders(authToken: token),
        body: json.encode(requestData),
      );


      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          

          if (responseData['data'] != null &&
              responseData['data']['auth_token'] != null) {
            final newToken = responseData['data']['auth_token'];
            final userData = responseData['data'];
            final updatedUser = User.fromJson(userData);
            await _saveUserSession(updatedUser);
            _currentUser = updatedUser;
          }

          return responseData['data'] ?? {};
        } else {
          throw Exception(responseData['message'] ?? 'Gagal mengubah password');
        }
      } else if (response.statusCode == 400) {
        final responseData = json.decode(response.body);
        throw Exception(
            responseData['message'] ?? 'Password saat ini tidak benar');
      } else if (response.statusCode == 401) {
        
        await logout();
        throw Exception('Sesi telah berakhir, silakan login kembali');
      } else if (response.statusCode == 422) {
        final responseData = json.decode(response.body);
        String errorMessage = 'Data tidak valid';

        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMessage = firstError.first.toString();
          }
        } else if (responseData['message'] != null) {
          errorMessage = responseData['message'];
        }

        throw Exception(errorMessage);
      } else {
        final responseData = json.decode(response.body);
        throw Exception(
            responseData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Network error: ${e.toString()}');
      }
    }
  }

  Future<void> logout() async {
    try {
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail != null) {
        final authToken = await getStoredAuthToken(currentEmail);
        if (authToken != null) {

          final response = await http
              .post(
                Uri.parse('$baseUrl/logout'),
                headers: _getHeaders(authToken: authToken),
              )
              .timeout(Duration(seconds: 10));


          if (response.statusCode == 200) {
            
          } else {
            
          }
        }

        await _clearUserSession(currentEmail);
      }
    } catch (e) {
      
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail != null) {
        await _clearUserSession(currentEmail);
      }
    } finally {
      await _clearCurrentUserEmail();
      _currentUser = null;
      
    }
  }

  // Check if user is logged in


  
  Future<bool> isLoggedIn() async {
    try {
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail == null) {
        
        return false;
      }

      final authToken = await getStoredAuthToken(currentEmail);
      if (authToken == null) {
        
        return false;
      }

      try {
        await getProfile();
        return true;
      } catch (e) {
        
        return false;
      }
    } catch (e) {
      
      return false;
    }
  }

  Future<void> clearExpiredSession() async {
    try {
      final currentEmail = await _getCurrentUserEmail();
      if (currentEmail != null) {
        final authToken = await getStoredAuthToken(currentEmail);
        if (authToken != null) {
          try {
            await getProfile();
            
          } catch (e) {
            await _clearUserSession(currentEmail);
            await _clearCurrentUserEmail();
          }
        }
      }
    } catch (e) {
      
    }
  }

  // Initialize auth state (call on app startup)
  Future<void> initializeAuth() async {
    try {
      final isAuthenticated = await isLoggedIn();
      if (isAuthenticated) {
        
      } else {
        
      }
    } catch (e) {
      
      await _clearCurrentUserEmail();
    }
  }

  Future<void> _saveUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenKey = _getUserTokenKey(user.email);
    final dataKey = _getUserDataKey(user.email);

    await _secureStorage.write(key: tokenKey, value: user.authToken);
    final userData = Map<String, dynamic>.from(user.toJson());
    userData.remove('auth_token');
    await prefs.setString(dataKey, json.encode(userData));
  }

  Future<String?> getStoredAuthToken(String email) async {
    final tokenKey = _getUserTokenKey(email);
    final secureToken = await _secureStorage.read(key: tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: tokenKey, value: legacyToken);
      await prefs.remove(tokenKey);
      return legacyToken;
    }

    return null;
  }

  Future<void> _clearUserSession(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenKey = _getUserTokenKey(email);
    final dataKey = _getUserDataKey(email);

    await _secureStorage.delete(key: tokenKey);
    await prefs.remove(dataKey);
  }

  Future<void> _setCurrentUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserEmailKey, email);
  }

  Future<String?> _getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserEmailKey);
  }

  Future<void> _clearCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserEmailKey);
  }
}
