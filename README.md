# SparkCommerce

Multi-platform e-commerce management system with centralized SKU management and real-time marketplace synchronization. Supports TikTok Shop and Shopee integration with group-based dashboard reporting.

## Architecture Overview

```
SparkCommerce/
├── backend_ecommerce_manager_mobile-main/   # RESTful API Server
├── frontend_ecommerce_manager_mobile-main/  # Flutter Mobile Application
└── dashboard_receiver_example/              # External Dashboard Webhook Receiver
```

### System Components

**Backend API Server**
- Node.js + Express.js REST API
- Multi-tenancy with group-based access control
- OAuth 2.0 integration for TikTok Shop and Shopee
- MySQL/MariaDB for user management and token storage
- SQLite for local SKU master data

**Mobile Application**
- Flutter cross-platform application (Android/iOS)
- OAuth authentication flow for marketplace connections
- Local SQLite database for offline SKU management
- Real-time stock synchronization across platforms
- Bi-directional sync: push to marketplace or pull from marketplace

**Dashboard Integration**
- Webhook-based transaction sync to external dashboards
- Group-level data isolation
- HMAC-based authentication for secure data transfer

## Core Features

### Marketplace Integration
- OAuth-based shop connection for TikTok Shop and Shopee
- Multi-shop management per user
- Platform-specific product operations (create, read, update, delete)
- Order management with shipping integration
- Image upload handling for product catalogs

### SKU Master System
- Centralized SKU database with cross-platform mapping
- Automatic stock reduction on order fulfillment
- Manual stock adjustment capabilities
- Bi-directional stock synchronization
  - Push: Update marketplace stock from master
  - Pull: Sync marketplace stock to master

### Group-Based Dashboard Sync
- Users assigned to groups with dedicated dashboard endpoints
- Automatic transaction forwarding to group dashboard
- Secret-based webhook authentication
- Filters for shop-specific or platform-specific data

### Analytics
- Cross-platform order aggregation
- Revenue tracking per shop and platform
- Order status monitoring

## Quick Start

Refer to component-specific README files:
- [Backend Setup](./backend_ecommerce_manager_mobile-main/README.md)
- [Frontend Setup](./frontend_ecommerce_manager_mobile-main/README.md)
- [Dashboard Integration](./dashboard_receiver_example/README.md)

Detailed database setup instructions available in [DATABASE_SETUP.md](./DATABASE_SETUP.md).

## Technology Stack

**Backend**
- Runtime: Node.js 16+
- Framework: Express.js
- Databases: MySQL/MariaDB, SQLite3
- ORM: Sequelize
- Authentication: JWT, bcrypt
- Security: Helmet, express-rate-limit, CORS

**Frontend**
- Framework: Flutter 3.5+
- State Management: Provider
- Local Storage: SQLite (sqflite), SharedPreferences
- HTTP Client: dio, http
- WebView: webview_flutter (OAuth flows)

**Infrastructure**
- API Documentation: OpenAPI/Swagger compatible
- Version Control: Git
- Environment Management: dotenv

## Security Considerations

**Credential Management**
- Never commit `.env` files containing real credentials
- Use `.env.example` templates for documentation
- Rotate API keys and secrets regularly
- Separate development and production credentials

**API Security**
- Rate limiting on sensitive endpoints
- HMAC-based webhook validation
- Token expiration and refresh mechanisms
- Input validation and sanitization

**Data Protection**
- Encrypted password storage (bcrypt)
- HTTPS-only in production
- CORS configuration for trusted origins
- SQL injection prevention via parameterized queries

## Development Workflow

1. Clone repository
2. Install dependencies for backend and frontend
3. Configure environment variables using `.env.example` templates
4. Initialize databases (MySQL + SQLite)
5. Start backend server
6. Launch mobile application in emulator or physical device
7. Connect marketplace accounts via OAuth
8. Configure group settings and dashboard webhooks if needed

## API Endpoints

Backend exposes RESTful API with the following route prefixes:

- `/api/oauth/tiktok/*` - TikTok Shop OAuth and shop management
- `/api/oauth/shopee/*` - Shopee OAuth and shop management
- `/api/tiktok/*` - TikTok Shop product and order operations
- `/api/shopee/*` - Shopee product and order operations
- `/api/user/*` - User authentication and profile management
- `/api/groups/*` - Group configuration for dashboard integration
- `/api/analytics/*` - Cross-platform analytics data

## Database Schema

**MySQL/MariaDB Tables**
- `users` - User accounts with group assignments
- `tokens` - OAuth tokens for marketplace connections
- `user_shops` - Shop ownership mapping
- `groups` - Dashboard webhook configurations
- `transaction_sync_log` - Sync history tracking

**SQLite Tables**
- `skus` - Master SKU inventory
- `sku_product_mapping` - SKU-to-marketplace-product relationships

Detailed schema available in `ecommerce_manager.sql`.

## Deployment

**Backend**
- Deploy to Node.js hosting (AWS, DigitalOcean, Heroku, etc.)
- Configure MySQL/MariaDB instance
- Set environment variables for production
- Enable HTTPS with valid SSL certificate
- Configure firewall rules

**Frontend**
- Build Android APK: `flutter build apk --release`
- Build iOS IPA: `flutter build ios --release`
- Distribute via Google Play Store or Apple App Store
- Configure production BASE_URL in `.env`

**Dashboard**
- Deploy webhook receiver to accessible endpoint
- Configure secret keys matching backend groups
- Implement database persistence for production
- Set up monitoring and logging

## Troubleshooting

Common issues and solutions:

**Backend fails to start**
- Verify MySQL connection credentials
- Check port 5001 is not in use
- Ensure all dependencies are installed

**Frontend cannot connect to backend**
- Verify BASE_URL in frontend `.env`
- Use `10.0.2.2` for Android emulator
- Use actual IP address for physical devices
- Check firewall allows backend port

**OAuth authorization fails**
- Verify TikTok/Shopee app credentials
- Check redirect URI matches app configuration
- Ensure callback URL is accessible

**Dashboard not receiving transactions**
- Verify group dashboard URL is correct
- Check secret key matches between app and dashboard
- Ensure dashboard endpoint is publicly accessible
- Review backend logs for webhook errors

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork repository and create feature branch
2. Follow existing code style and conventions
3. Write tests for new functionality
4. Update documentation as needed
5. Submit pull request with clear description

## License

Proprietary software. All rights reserved.

## Support

For technical issues, create a GitHub issue with:
- Detailed problem description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, versions, etc.)
- Relevant log excerpts
