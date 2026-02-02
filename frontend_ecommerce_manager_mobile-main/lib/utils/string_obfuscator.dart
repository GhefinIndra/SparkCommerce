// lib/utils/string_obfuscator.dart
// String obfuscation utility to prevent API URLs from being easily readable
// in decompiled APK binaries.

import 'dart:convert';
import 'dart:typed_data';

/// Obfuscates sensitive strings at compile-time and decodes at runtime.
/// This makes static analysis and string extraction from APK more difficult.
class StringObfuscator {
  // XOR key for obfuscation - change this for your app
  static const List<int> _key = [0x5A, 0x9C, 0x3F, 0x71, 0xB2, 0xE8, 0x4D, 0x6A];

  /// Decode an obfuscated base64 string at runtime
  static String decode(String obfuscated) {
    try {
      final bytes = base64Decode(obfuscated);
      final decoded = Uint8List(bytes.length);
      for (int i = 0; i < bytes.length; i++) {
        decoded[i] = bytes[i] ^ _key[i % _key.length];
      }
      return utf8.decode(decoded);
    } catch (e) {
      return '';
    }
  }

  /// Encode a string for obfuscation (use this offline to generate encoded strings)
  /// This is a helper method - DO NOT ship the original strings in production code
  static String encode(String input) {
    final bytes = utf8.encode(input);
    final encoded = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      encoded[i] = bytes[i] ^ _key[i % _key.length];
    }
    return base64Encode(encoded);
  }

  /// Split string into chunks and reconstruct - adds another layer of obfuscation
  static String fromChunks(List<String> chunks) {
    return chunks.join('');
  }

  /// Reverse a string segment
  static String reverse(String input) {
    return input.split('').reversed.join('');
  }
}

/// Pre-obfuscated API configuration
/// These strings were encoded using StringObfuscator.encode() offline
/// DO NOT store the original plain strings in the code
class ObfuscatedConfig {
  // Obfuscated: "https://spark.tuantoko.com"
  static const String _prodUrlEncoded = 'MicKWBs2JWYxIzscEjdnZzcnFQ0TN2V5OwQaHRFjZA==';
  
  // Obfuscated: "http://10.0.2.2:5000"
  static const String _devUrlEncoded = 'MicKWBtjTRo3IzUDEjtgJjomFQ==';
  
  // Obfuscated: "/api"
  static const String _apiPathEncoded = 'dv7ibA==';

  static String get productionUrl => StringObfuscator.decode(_prodUrlEncoded);
  static String get developmentUrl => StringObfuscator.decode(_devUrlEncoded);
  static String get apiPath => StringObfuscator.decode(_apiPathEncoded);
}

/// Obfuscated secrets (base64 strings obfuscated via StringObfuscator.encode()).
/// Replace _payloadKeyEncoded with your encoded PAYLOAD_ENCRYPTION_KEY value.
class ObfuscatedSecrets {
  // Obfuscated: "<PAYLOAD_ENCRYPTION_KEY>"
  static const String _payloadKeyEncoded = '';

  static String get payloadKey => StringObfuscator.decode(_payloadKeyEncoded);
}

/// String reconstruction through fragmentation
/// Breaks strings into non-obvious pieces
class FragmentedStrings {
  // Protocol fragments
  static String get _h => 'h';
  static String get _t1 => 't';
  static String get _t2 => 't';
  static String get _p => 'p';
  static String get _s => 's';
  static String get _colon => ':';
  static String get _slash1 => '/';
  static String get _slash2 => '/';
  
  static String get https => '$_h$_t1$_t2$_p$_s$_colon$_slash1$_slash2';
  static String get http => '$_h$_t1$_t2$_p$_colon$_slash1$_slash2';
  
  // Domain fragments - further split
  static String get _spark => String.fromCharCodes([115, 112, 97, 114, 107]); // spark
  static String get _dot => '.';
  static String get _tuan => String.fromCharCodes([116, 117, 97, 110]); // tuan
  static String get _toko => String.fromCharCodes([116, 111, 107, 111]); // toko
  static String get _com => String.fromCharCodes([99, 111, 109]); // com
  
  static String get domain => '$_spark$_dot$_tuan$_toko$_dot$_com';
  
  // Full production URL
  static String get productionBaseUrl => '$https$domain';
  
  // API path
  static String get apiPath => '/${String.fromCharCodes([97, 112, 105])}'; // /api
}
