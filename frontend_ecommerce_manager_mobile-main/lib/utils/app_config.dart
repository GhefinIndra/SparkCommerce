import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    const defined = String.fromEnvironment('BASE_URL');
    if (defined.isNotEmpty) {
      return defined;
    }
    return kReleaseMode ? 'https://spark.tuantoko.com' : 'http://10.0.2.2:5000';
  }

  static String get apiBaseUrl => '$baseUrl/api';

  static void validate() {
    if (kReleaseMode && baseUrl.startsWith('http://')) {
      throw StateError('Insecure BASE_URL in release. Use HTTPS.');
    }
  }
}
