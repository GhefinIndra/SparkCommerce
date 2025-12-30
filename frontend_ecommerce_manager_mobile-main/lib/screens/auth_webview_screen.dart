import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';

class AuthWebViewScreen extends StatefulWidget {
  final String platform; // 'tiktok' or 'shopee'
  final String? displayName; // Optional display name (e.g., 'Tokopedia' for tiktok platform)

  const AuthWebViewScreen({
    Key? key,
    required this.platform,
    this.displayName,
  }) : super(key: key);

  @override
  _AuthWebViewScreenState createState() => _AuthWebViewScreenState();
}

class _AuthWebViewScreenState extends State<AuthWebViewScreen> {
  late WebViewController _controller;
  bool _isLoading = true;
  String _errorMessage = '';
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    String authUrl = await _getAuthorizationUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
            print('Loading progress: $progress%');
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _errorMessage = '';
            });
          },
          onPageFinished: (String url) {
            print('✅ Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });

            if (url.contains('/success')) {
              print('🎉 Success URL detected, calling handler');
              _handleAuthSuccess(url);
            } else if (url.contains('/error')) {
              print('❌ Error URL detected, calling handler');
              _handleAuthError(url);
            } else {
              print('ℹ️ Normal page load (not success/error)');
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('   Error type: ${error.errorType}');
            print('   Error code: ${error.errorCode}');
            print('   Failing URL: ${error.url}');

            _controller.currentUrl().then((currentUrl) {
              print('   Current page URL: $currentUrl');

              if (error.errorCode == -2 && error.url != null) {
                final failingUrl = error.url!;

                final backendOrigin = Uri.parse(AppConfig.baseUrl).origin;
                bool isBackendError =
                    failingUrl.startsWith(backendOrigin);

                bool stillOnBackend = currentUrl != null &&
                    currentUrl.startsWith(backendOrigin);

                print('   Is backend error: $isBackendError');
                print('   Still on backend: $stillOnBackend');

                if (isBackendError && stillOnBackend) {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Tidak dapat terhubung ke server.\n\n'
                        'Pastikan:\n'
                        ' Koneksi internet aktif\n'
                        ' Server backend sedang berjalan\n'
                        ' URL API sudah benar';
                  });
                } else {
                }
              }
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔄 Navigation request: ${request.url}');
            print('   Is for main frame: ${request.isMainFrame}');
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));
  }

  Future<String> _getAuthorizationUrl() async {
    final baseUrl = ApiService.baseUrl;

    final authService = AuthService();
    final userToken = authService.currentUser?.authToken ?? '';

    if (widget.platform == 'shopee') {
      final url = '$baseUrl/oauth/shopee/authorize?user_token=$userToken';
      print('📍 Loading Shopee auth URL: $url');
      return url;
    } else {
      final url = '$baseUrl/oauth/tiktok/authorize?user_token=$userToken';
      print('📍 Loading TikTok auth URL: $url');
      return url;
    }
  }

  void _handleAuthSuccess(String url) {
    final uri = Uri.parse(url);
    final platform = uri.queryParameters['platform'];
    final shopId = uri.queryParameters['shopId'];
    final openId = uri.queryParameters['openId'];
    final seller = uri.queryParameters['seller'];

    print('   Platform: $platform');
    print('   Shop ID: $shopId');
    print('   OpenID: $openId');
    print('   Seller: $seller');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Toko berhasil ditambahkan: ${seller ?? shopId ?? 'Unknown'}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );

    Navigator.pop(context, {
      'success': true,
      'platform': platform ?? widget.platform,
      'shopId': shopId,
      'openId': openId,
      'seller': seller,
    });
  }

  void _handleAuthError(String url) {
    final uri = Uri.parse(url);
    final errorMessage = uri.queryParameters['message'] ?? 'Unknown error';


    setState(() {
      _errorMessage = 'Authentication failed: $errorMessage';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Gagal menambahkan toko: $errorMessage',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 5),
      ),
    );
  }

  String _getPlatformTitle() {
    // If displayName is provided, use it (e.g., "Tokopedia")
    if (widget.displayName != null) {
      return 'Tambah Toko ${widget.displayName}';
    }

    // Otherwise, use platform name
    switch (widget.platform) {
      case 'shopee':
        return 'Tambah Toko Shopee';
      case 'tiktok':
        return 'Tambah Toko TikTok';
      default:
        return 'Tambah Toko';
    }
  }

  Color _getPlatformColor() {
    // If displayName is "Tokopedia", use Tokopedia green
    if (widget.displayName?.toLowerCase() == 'tokopedia') {
      return Color(0xFF03AC0E);
    }

    // Otherwise, use platform color
    switch (widget.platform) {
      case 'shopee':
        return Color(0xFFEE4D2D);
      case 'tiktok':
        return Colors.black;
      default:
        return Color(0xFF1A237E);
    }
  }

  List<Color> _getGradientColors() {
    // If displayName is "Tokopedia", use Tokopedia green gradient
    if (widget.displayName?.toLowerCase() == 'tokopedia') {
      return [Color(0xFF03AC0E), Color(0xFF028A0C)];
    }

    // Otherwise, use platform gradient
    if (widget.platform == 'shopee') {
      return [Color(0xFFEE4D2D), Color(0xFFD84315)];
    } else {
      return [Colors.black, Colors.grey[900]!];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getGradientColors(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: _buildBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context, {'success': false}),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _getPlatformTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              SizedBox(width: 56),
            ],
          ),
          if (_isLoading) ...[
            SizedBox(height: 16),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress / 100,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Terjadi Kesalahan',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = '';
                          _isLoading = true;
                        });
                        _initializeWebView();
                      },
                      icon: Icon(Icons.refresh_rounded, size: 20),
                      label: Text(
                        'Coba Lagi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPlatformColor(),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, {'success': false}),
                      icon: Icon(Icons.close_rounded, size: 20),
                      label: Text(
                        'Tutup',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }
}
