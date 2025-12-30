import 'dart:async';

/// OAuth Event Model
class OAuthEvent {
  final bool success;
  final String platform;
  final String seller;
  final String openId;
  final String? shopId;
  final String? errorMessage;

  OAuthEvent({
    required this.success,
    required this.platform,
    required this.seller,
    required this.openId,
    this.shopId,
    this.errorMessage,
  });
}

/// Global OAuth Event Service
/// Handles OAuth callback events and broadcasts to all listeners
class OAuthEventService {
  // Singleton pattern
  static final OAuthEventService _instance = OAuthEventService._internal();
  factory OAuthEventService() => _instance;
  OAuthEventService._internal();

  // Stream controller for OAuth events
  final _eventController = StreamController<OAuthEvent>.broadcast();

  // Public stream for listeners
  Stream<OAuthEvent> get eventStream => _eventController.stream;

  // Emit OAuth success event
  void emitSuccess({
    required String platform,
    required String seller,
    required String openId,
    String? shopId,
  }) {
    print('🎉 OAuth Event Service: Emitting SUCCESS event');
    print('   Platform: $platform');
    print('   Seller: $seller');
    print('   OpenID: $openId');
    print('   ShopID: $shopId');
    
    _eventController.add(OAuthEvent(
      success: true,
      platform: platform,
      seller: seller,
      openId: openId,
      shopId: shopId,
    ));
  }

  // Emit OAuth error event
  void emitError({
    required String platform,
    required String errorMessage,
  }) {
    print('❌ OAuth Event Service: Emitting ERROR event');
    print('   Platform: $platform');
    print('   Error: $errorMessage');
    
    _eventController.add(OAuthEvent(
      success: false,
      platform: platform,
      seller: '',
      openId: '',
      errorMessage: errorMessage,
    ));
  }

  // Dispose (call when app terminates)
  void dispose() {
    _eventController.close();
  }
}
