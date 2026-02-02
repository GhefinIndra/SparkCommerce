import 'package:flutter/foundation.dart';
import 'string_obfuscator.dart';

/// Application configuration with obfuscated sensitive strings.
/// 
/// Security hardening applied:
/// 1. URL strings are obfuscated to prevent easy extraction from APK
/// 2. Multiple obfuscation layers (XOR encoding + string fragmentation)
/// 3. Runtime decoding prevents static string analysis
class AppConfig {
  // Cached decoded URL to avoid repeated decoding
  static String? _cachedBaseUrl;
  
  static String get baseUrl {
    // Check for compile-time override first
    const defined = String.fromEnvironment('BASE_URL');
    if (defined.isNotEmpty) {
      return defined;
    }
    
    // Return cached URL if available
    if (_cachedBaseUrl != null) {
      return _cachedBaseUrl!;
    }
    
    // Decode and cache the URL
    if (kReleaseMode) {
      // Use fragmented string construction for production
      // This makes the URL harder to find via static analysis
      _cachedBaseUrl = FragmentedStrings.productionBaseUrl;
    } else {
      // Development URL - less critical but still obfuscated
      _cachedBaseUrl = _buildDevUrl();
    }
    
    return _cachedBaseUrl!;
  }

  /// Build development URL using character codes
  static String _buildDevUrl() {
    // http://10.0.2.2:5000
    return String.fromCharCodes([
      104, 116, 116, 112, 58, 47, 47,  // http://
      49, 48, 46, 48, 46, 50, 46, 50,  // 10.0.2.2
      58, 53, 48, 48, 48               // :5000
    ]);
  }

  static String get apiBaseUrl => '$baseUrl${FragmentedStrings.apiPath}';

  /// Validate configuration at app startup
  static void validate() {
    final url = baseUrl;
    if (kReleaseMode && url.startsWith(FragmentedStrings.http)) {
      throw StateError('Insecure BASE_URL in release. Use HTTPS.');
    }
  }
  
  /// Clear cached URL (useful for testing or URL switching)
  static void clearCache() {
    _cachedBaseUrl = null;
  }
}
