// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'screens/auth_wrapper.dart';
import 'services/oauth_event_service.dart';
import 'utils/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('sparkcommerce.app/channel');
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _lastErrorShown;
  
  @override
  void initState() {
    super.initState();
    _initDeepLinkListener();
    _setupGlobalErrorHandling();
  }

  void _setupGlobalErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _showGlobalError('Terjadi kesalahan tak terduga. Silakan coba lagi.');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _showGlobalError('Terjadi kesalahan tak terduga. Silakan coba lagi.');
      return true;
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      final isRelease = kReleaseMode;
      return Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Color(0xFF1A237E),
                ),
                const SizedBox(height: 12),
                Text(
                  'Terjadi kesalahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Silakan kembali dan coba lagi.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                if (!isRelease) ...[
                  const SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    };
  }

  void _showGlobalError(String message) {
    final now = DateTime.now();
    if (_lastErrorShown != null &&
        now.difference(_lastErrorShown!).inSeconds < 3) {
      return;
    }
    _lastErrorShown = now;

    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
  
  void _initDeepLinkListener() {
    // Listen for deep link events
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final String? link = call.arguments;
        if (link != null) {
          _handleDeepLink(link);
        }
      }
    });
    
    // Check for initial deep link (app opened via deep link)
    _checkInitialDeepLink();
  }
  
  Future<void> _checkInitialDeepLink() async {
    try {
      final String? initialLink = await platform.invokeMethod('getInitialLink');
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }
  }
  
  void _handleDeepLink(String link) {
    print('📱 Deep link received: $link');
    
    final uri = Uri.parse(link);
    if (uri.scheme == 'sparkcommerce' && uri.host == 'oauth') {
      final success = uri.queryParameters['success'] == 'true';
      final platform = uri.queryParameters['platform'];
      final seller = uri.queryParameters['seller'];
      final openId = uri.queryParameters['openId'];
      final shopId = uri.queryParameters['shopId'];
      
      if (success && platform != null && seller != null && openId != null) {
        // Emit event to global stream (will be caught by ShopDashboardScreen)
        print('✅ Emitting OAuth success event to global stream');
        OAuthEventService().emitSuccess(
          platform: platform,
          seller: seller,
          openId: openId,
          shopId: shopId,
        );
      } else {
        // Emit error event
        print('❌ OAuth failed or cancelled');
        OAuthEventService().emitError(
          platform: platform ?? 'Unknown',
          errorMessage: 'OAuth gagal atau dibatalkan',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ecommerce Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Color(0xFF00AA5B),
        fontFamily: 'Inter', // Atau font yang Anda gunakan
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: AuthWrapper(), // Gunakan AuthWrapper sebagai entry point
    );
  }
}
