import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../utils/string_obfuscator.dart';

class EncryptionService {
  static const String _encVersion = 'v1';
  static const String _encAlg = 'AES-256-GCM';

  static final AesGcm _cipher = AesGcm.with256bits();

  static Future<String> decryptIfNeeded(String body) async {
    if (body.isEmpty) {
      return body;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return body;
    }

    if (decoded is! Map<String, dynamic>) {
      return body;
    }

    final encVersion = decoded['enc'];
    final alg = decoded['alg'];
    if (encVersion != _encVersion || alg != _encAlg) {
      return body;
    }

    final data = decoded['data'];
    final iv = decoded['iv'];
    final tag = decoded['tag'];
    if (data is! String || iv is! String || tag is! String) {
      throw Exception('Invalid encrypted payload format');
    }

    final keyBytes = _getKeyBytes();
    if (keyBytes.isEmpty) {
      throw Exception('PAYLOAD_KEY is missing on client');
    }

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      base64Decode(data),
      nonce: base64Decode(iv),
      mac: Mac(base64Decode(tag)),
    );

    final clearBytes = await _cipher.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(clearBytes);
  }

  static Future<dynamic> decodeResponse(String body) async {
    final decrypted = await decryptIfNeeded(body);
    return jsonDecode(decrypted);
  }

  static Map<String, String> withEncryptionHeader(Map<String, String> headers) {
    return {
      ...headers,
      'X-Enc': '1',
    };
  }

  static List<int> _getKeyBytes() {
    const definedKey = String.fromEnvironment('PAYLOAD_KEY');
    final rawKey = definedKey.isNotEmpty
        ? definedKey
        : ObfuscatedSecrets.payloadKey;

    if (rawKey.isEmpty) {
      return [];
    }

    try {
      final keyBytes = base64Decode(rawKey);
      if (keyBytes.length != 32) {
        return [];
      }
      return keyBytes;
    } catch (_) {
      return [];
    }
  }
}
