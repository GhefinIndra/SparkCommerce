import 'dart:io';
import 'dart:async';
import 'dart:convert';

class AppError implements Exception {
  final String message;
  final String? debugMessage;

  AppError(this.message, {this.debugMessage});

  String get userMessage => _buildUserMessage();

  @override
  String toString() => userMessage;

  String _buildUserMessage() {
    final extracted = _extractPreferredMessage();
    return _humanize(extracted);
  }

  String _extractPreferredMessage() {
    final debugData = _parseDebugJson();
    final debugError = _extractErrorFromDebug(debugData);
    final suggestion = _extractSuggestionFromDebug(debugData);

    var primary = message.trim();

    if (_isGenericMessage(primary) && debugError != null) {
      primary = debugError;
    }

    final parts = <String>[];
    if (primary.isNotEmpty) {
      parts.add(primary);
    }
    if (suggestion != null) {
      parts.add('Saran: $suggestion');
    }

    return parts.isNotEmpty ? parts.join(' ') : message;
  }

  Map<String, dynamic>? _parseDebugJson() {
    final raw = debugMessage;
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  String? _extractErrorFromDebug(Map<String, dynamic>? data) {
    if (data == null) return null;
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    if (error is Map<String, dynamic>) {
      final inner = error['message'] ?? error['error'] ?? error['msg'];
      if (inner is String && inner.trim().isNotEmpty) {
        return inner.trim();
      }
    }
    return null;
  }

  String? _extractSuggestionFromDebug(Map<String, dynamic>? data) {
    if (data == null) return null;
    final suggestion = data['suggestion'];
    if (suggestion is String && suggestion.trim().isNotEmpty) {
      return suggestion.trim();
    }
    return null;
  }

  bool _isGenericMessage(String text) {
    final lower = text.toLowerCase();
    return lower.startsWith('failed to ') ||
        lower.startsWith('gagal ') ||
        lower == 'error' ||
        lower == 'unknown error' ||
        lower == 'failed to create product' ||
        lower == 'gagal membuat produk' ||
        lower == 'gagal membuat produk shopee';
  }

  String _humanize(String text) {
    var message = text.trim();
    if (message.isEmpty) {
      return 'Terjadi kesalahan. Silakan coba lagi.';
    }

    message = message.replaceFirst(
      RegExp(r'^(Shopee API Error:|TikTok API Error:)\s*', caseSensitive: false),
      '',
    );

    final patterns = <_ErrorPattern>[
      _ErrorPattern(
        RegExp(r'product\.error_desc_len_no_pass', caseSensitive: false),
        'Deskripsi produk harus 20-3000 karakter.',
      ),
      _ErrorPattern(
        RegExp(r'description length must be between', caseSensitive: false),
        'Deskripsi produk harus 20-3000 karakter.',
      ),
      _ErrorPattern(
        RegExp(r'description is required', caseSensitive: false),
        'Deskripsi produk wajib diisi.',
      ),
      _ErrorPattern(
        RegExp(r'item name is required', caseSensitive: false),
        'Nama produk wajib diisi.',
      ),
      _ErrorPattern(
        RegExp(r'category id is required', caseSensitive: false),
        'Kategori produk wajib dipilih.',
      ),
      _ErrorPattern(
        RegExp(r'original price is required', caseSensitive: false),
        'Harga produk wajib diisi.',
      ),
      _ErrorPattern(
        RegExp(r'weight is required', caseSensitive: false),
        'Berat produk wajib diisi.',
      ),
      _ErrorPattern(
        RegExp(r'at least one product image is required', caseSensitive: false),
        'Minimal 1 gambar produk wajib diisi.',
      ),
      _ErrorPattern(
        RegExp(r'partner and shop has no linked', caseSensitive: false),
        'Toko Shopee belum terhubung ke Partner. Silakan hubungkan/authorize ulang toko Shopee.',
      ),
      _ErrorPattern(
        RegExp(r'token expired', caseSensitive: false),
        'Token toko sudah kedaluwarsa. Silakan authorize ulang toko.',
      ),
      _ErrorPattern(
        RegExp(r'authorization is expired|authoirzaition is expired',
            caseSensitive: false),
        'Token toko sudah kedaluwarsa. Silakan authorize ulang toko.',
      ),
      _ErrorPattern(
        RegExp(r'access scope', caseSensitive: false),
        'Izin (scope) belum lengkap untuk endpoint ini. Aktifkan scope yang dibutuhkan lalu authorize ulang.',
      ),
      _ErrorPattern(
        RegExp(r'failed to get warehouse', caseSensitive: false),
        'Gagal mengambil data gudang dari marketplace. Cek izin logistik/warehouse dan otorisasi toko.',
      ),
      _ErrorPattern(
        RegExp(r'missing required product attributes', caseSensitive: false),
        'Atribut wajib belum lengkap. Lengkapi semua atribut kategori.',
      ),
      _ErrorPattern(
        RegExp(r'size chart.*required|size chart diperlukan',
            caseSensitive: false),
        'Size chart wajib untuk kategori ini.',
      ),
      _ErrorPattern(
        RegExp(r'shop not found', caseSensitive: false),
        'Toko tidak ditemukan atau token kadaluarsa. Silakan authorize ulang.',
      ),
      _ErrorPattern(
        RegExp(r'http\\s*401|unauthorized', caseSensitive: false),
        'Akses ditolak (401). Silakan login ulang atau authorize ulang toko.',
      ),
      _ErrorPattern(
        RegExp(r'failed to create product', caseSensitive: false),
        'Gagal membuat produk. Periksa kelengkapan data dan otorisasi toko.',
      ),
      _ErrorPattern(
        RegExp(r'failed to load products|gagal memuat produk',
            caseSensitive: false),
        'Gagal memuat produk. Pastikan toko sudah terhubung dan token masih aktif, lalu coba lagi.',
      ),
      _ErrorPattern(
        RegExp(r'token expired.*shopee', caseSensitive: false),
        'Token Shopee sudah kedaluwarsa. Silakan authorize ulang toko Shopee.',
      ),
      _ErrorPattern(
        RegExp(r'invalid platform: this endpoint is for shopee shops only',
            caseSensitive: false),
        'Endpoint ini khusus Shopee. Pastikan Anda memilih toko Shopee.',
      ),
    ];

    for (final pattern in patterns) {
      if (pattern.regex.hasMatch(message)) {
        return pattern.message;
      }
    }

    return message;
  }

  static AppError from(Object error, {String action = 'proses'}) {
    if (error is AppError) return error;
    if (error is SocketException) {
      return AppError(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        debugMessage: error.message,
      );
    }
    if (error is TimeoutException) {
      return AppError(
        'Permintaan $action melebihi batas waktu. Coba lagi.',
        debugMessage: error.toString(),
      );
    }
    if (error is FormatException) {
      return AppError(
        'Data yang diterima tidak valid. Coba lagi nanti.',
        debugMessage: error.message,
      );
    }
    return AppError(
      'Terjadi kesalahan saat $action. Silakan coba lagi.',
      debugMessage: error.toString(),
    );
  }
}

class _ErrorPattern {
  final RegExp regex;
  final String message;

  const _ErrorPattern(this.regex, this.message);
}
