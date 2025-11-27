# SparkCommerce Mobile Application

Flutter-based cross-platform mobile application for managing multi-marketplace e-commerce operations. Provides unified interface for TikTok Shop and Shopee product management, order processing, and centralized SKU inventory control.

## System Requirements

- Flutter SDK >= 3.5.0
- Dart SDK >= 3.5.0
- Android Studio / Xcode for mobile development
- Android SDK (for Android builds)
- Xcode 14+ and CocoaPods (for iOS builds)

## Installation

### 1. Install Flutter Dependencies

```bash
flutter pub get
```

### 2. Environment Configuration

Copy example environment file:

```bash
cp .env.example .env
```

Configure API endpoint in `.env`:

```bash
# API Base URL
# For Android Emulator: http://10.0.2.2:5001
# For iOS Simulator: http://localhost:5001
# For Physical Devices: http://YOUR_COMPUTER_IP:5001
# Production: https://api.yourdomain.com
BASE_URL=http://10.0.2.2:5001
```

### 3. Platform-Specific Setup

**Android**
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- No additional configuration required

**iOS**
- Minimum iOS version: 12.0
- Run `pod install` in ios/ directory if needed
- Configure signing in Xcode

### 4. Run Application

Development mode with hot reload:
```bash
flutter run
```

Build release APK (Android):
```bash
flutter build apk --release
```

Build iOS IPA:
```bash
flutter build ios --release
```

## Application Architecture

### Directory Structure

```
lib/
├── main.dart                   # Application entry point
├── models/                     # Data models
│   ├── shop.dart              # Shop model (TikTok/Shopee)
│   ├── order.dart             # Order model
│   ├── product.dart           # Product model
│   └── user.dart              # User model
├── screens/                    # UI screens
│   ├── auth_wrapper.dart      # Authentication state handler
│   ├── login_screen.dart      # User login
│   ├── register_screen.dart   # User registration
│   ├── platform_selection_screen.dart  # Choose TikTok/Shopee
│   ├── auth_webview_screen.dart        # OAuth webview
│   ├── available_shops_screen.dart     # Shop listing
│   ├── shop_dashboard_screen.dart      # Shop overview
│   ├── manage_products_screen.dart     # Product list
│   ├── product_detail/        # Product detail screens
│   ├── create_product/        # Product creation flow
│   ├── view_order_screen.dart # Order list
│   ├── order_detail_screen.dart        # Order detail
│   ├── sku_master_screen.dart          # SKU management
│   ├── profile_screen.dart    # User profile
│   ├── conversations_screen.dart       # TikTok chat
│   ├── chat_screen.dart       # Chat messages
│   └── analytics/             # Analytics screens
└── services/                   # Business logic
    ├── api_service.dart       # HTTP API client
    ├── auth_service.dart      # Authentication service
    ├── database_helper.dart   # SQLite database
    ├── sku_sync_service.dart  # SKU synchronization
    └── transaction_sync_service.dart  # Order sync to dashboard
```

### Key Features

**Authentication**
- User registration and login
- Session management with token storage
- Auto-logout on token expiration

**Marketplace Connection**
- OAuth 2.0 flow for TikTok Shop
- OAuth 2.0 flow for Shopee
- Multi-shop support per user
- Shop switching capability

**Product Management**
- List products from connected shops
- Create new products with attributes
- Update product information (title, description)
- Update product pricing per SKU
- Update product stock levels
- Upload and manage product images
- Activate/deactivate products
- Delete products

**Order Management**
- View order lists with filtering
- Order detail with item breakdown
- Shipping status tracking
- Package management
- Print shipping labels
- Customer information display

**SKU Master System**
- Local SQLite database for SKU inventory
- Create and manage master SKUs
- Map SKUs to marketplace products
- Automatic stock reduction on orders
- Manual stock adjustments
- Bi-directional stock synchronization
  - Push: Update marketplace from master
  - Pull: Update master from marketplace

**Dashboard Integration**
- Automatic order sync to group dashboard
- Transaction logging
- Webhook delivery with retry logic

**Analytics**
- Cross-platform order statistics
- Revenue tracking
- Order status distribution
- Shop performance metrics

## Database Schema (Local SQLite)

### Tables

**skus**
```sql
CREATE TABLE skus (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  price REAL DEFAULT 0,
  stock INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

**sku_product_mapping**
```sql
CREATE TABLE sku_product_mapping (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sku TEXT NOT NULL,
  platform TEXT NOT NULL,
  shop_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  variant_id TEXT,
  variant_name TEXT,
  last_sync_at TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(sku, platform, shop_id, product_id, variant_id)
);
```

**transaction_sync_log**
```sql
CREATE TABLE transaction_sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id TEXT NOT NULL,
  shop_id TEXT NOT NULL,
  platform TEXT NOT NULL,
  synced_at TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(order_id, shop_id)
);
```

## Key Workflows

### OAuth Connection Flow

1. User navigates to Platform Selection screen
2. User selects TikTok Shop or Shopee
3. App opens WebView with OAuth URL
4. User authorizes app on marketplace platform
5. Marketplace redirects to backend callback
6. Backend exchanges code for access token
7. Backend stores token and returns shop data
8. App navigates to shop dashboard

### Product Creation Flow

1. User selects "Create Product" from shop dashboard
2. App loads category tree from marketplace
3. User selects category and enters product details
4. User uploads product images
5. User configures variants/SKUs and pricing
6. User sets stock levels and logistics
7. App validates all required fields
8. App sends create request to backend
9. Backend calls marketplace API
10. Product created and displayed in product list

### Order Processing Flow

1. User views order list from shop dashboard
2. User selects order to view details
3. App fetches full order information
4. If user has group_id, app checks sync status
5. If order not synced, app sends to dashboard webhook
6. App reduces stock in SKU master for matched SKUs
7. User can mark order as shipped (if supported)
8. Transaction logged in sync_log table

### SKU Synchronization Flow

**Push to Marketplace**
1. User edits stock in SKU Master screen
2. User clicks "Sync to Marketplace"
3. App queries sku_product_mapping for linked products
4. App calls API to update stock for each linked product
5. API updates marketplace product stock
6. App updates last_sync_at timestamp

**Pull from Marketplace**
1. User clicks "Pull Stock from Marketplace"
2. App fetches current stock from marketplace
3. App updates local SKU Master stock
4. User reviews changes and confirms
5. Local database updated

## API Integration

### HTTP Client Configuration

Base URL configured in `.env` file. API calls use `http` and `dio` packages.

**Request Headers**
```dart
{
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'auth_token': '<user_auth_token>'  // For authenticated requests
}
```

**Error Handling**
- Network errors (SocketException)
- HTTP status code errors (4xx, 5xx)
- JSON parsing errors
- Timeout errors (configurable per endpoint)

### Key Services

**AuthService**
- User registration and login
- Token storage in SharedPreferences
- Session validation
- Logout and token cleanup

**ApiService**
- Shop management (list, get info)
- Product CRUD operations
- Order retrieval and management
- Category and attribute queries
- Image upload
- Analytics data

**DatabaseHelper**
- SQLite database initialization
- SKU CRUD operations
- Product mapping management
- Transaction sync logging

**SKUSyncService**
- Stock synchronization logic
- Marketplace API integration
- Conflict resolution
- Sync status tracking

**TransactionSyncService**
- Order data transformation
- Dashboard webhook delivery
- Retry logic for failed syncs

## Configuration

### Environment Variables

**BASE_URL**
- Development (Emulator): `http://10.0.2.2:5001`
- Development (Physical): `http://192.168.x.x:5001`
- Production: `https://api.yourdomain.com`

### Build Configuration

**Android**
- Application ID: `com.example.ecommerce_manager_mobile`
- Min SDK: 21
- Target SDK: 34

**iOS**
- Bundle ID: Configure in Xcode
- Min iOS: 12.0

## Testing

Run tests:
```bash
flutter test
```

## Deployment

### Android Release

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS Release

```bash
flutter build ios --release
```

Then archive in Xcode for App Store submission.

## Troubleshooting

**Cannot connect to backend**
- Verify BASE_URL in `.env`
- Use `10.0.2.2` for Android emulator
- Use actual IP for physical devices
- Ensure backend is running

**Build failures**
```bash
flutter clean
flutter pub get
flutter run
```

**Database errors**
- Clear app data and reinstall
- Check SQLite permissions

For detailed support, refer to main project README.
