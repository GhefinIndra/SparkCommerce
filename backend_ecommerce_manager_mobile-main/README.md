# SparkCommerce Backend API

RESTful API server for SparkCommerce multi-platform e-commerce management system. Provides OAuth integration, product management, order processing, and SKU synchronization for TikTok Shop and Shopee marketplaces.

## System Requirements

- Node.js >= 16.0.0
- npm or yarn
- MySQL/MariaDB 5.7+ or 10.x+
- SQLite3 (bundled with node-sqlite3)

## Installation

### 1. Install Dependencies

```bash
npm install
```

### 2. Database Setup

Create MySQL database and import schema:

```bash
mysql -u root -p
CREATE DATABASE ecommerce_manager;
USE ecommerce_manager;
SOURCE ../ecommerce_manager.sql;
```

SQLite database for SKU master will be created automatically on first run.

### 3. Environment Configuration

Copy example environment file:

```bash
cp .env.example .env
```

Configure the following variables in `.env`:

```bash
# TikTok Shop API Credentials
TIKTOK_APP_KEY=your_app_key
TIKTOK_APP_SECRET=your_app_secret
TIKTOK_REDIRECT_URI=http://localhost:5001/api/oauth/tiktok/callback
TIKTOK_API_URL=https://open-api.tiktokglobalshop.com

# Shopee API Credentials
SHOPEE_PARTNER_ID=your_partner_id
SHOPEE_PARTNER_KEY=your_partner_key
SHOPEE_REDIRECT_URI=http://localhost:5001/api/oauth/shopee/callback
SHOPEE_API_URL=https://partner.test-stable.shopee.sg  # Use sandbox for testing

# Server Configuration
PORT=5001
NODE_ENV=development
CLIENT_URL=http://localhost:3000

# Database Configuration
DB_HOST=localhost
DB_NAME=ecommerce_manager
DB_USERNAME=root
DB_PASSWORD=your_password
DB_PORT=3306
```

### 4. Start Server

Development mode with auto-reload:
```bash
npm run dev
```

Production mode:
```bash
npm start
```

Server will start on `http://localhost:5001` (or configured PORT).

## API Documentation

### Authentication

User authentication uses JWT tokens. After login, include auth token in requests:

```http
Authorization: Bearer <auth_token>
```

Or use custom header:

```http
auth_token: <auth_token>
```

### Endpoint Structure

**User Management**
- `POST /api/user/register` - Create new user account
- `POST /api/user/login` - Authenticate and receive token
- `GET /api/user/profile` - Get current user profile
- `PUT /api/user/profile` - Update user profile
- `POST /api/user/change-password` - Change user password

**TikTok Shop Integration**
- `GET /api/oauth/tiktok/authorize` - Initiate OAuth flow
- `GET /api/oauth/tiktok/callback` - OAuth callback handler
- `GET /api/oauth/tiktok/shops` - List connected TikTok shops
- `GET /api/tiktok/shops/:shopId/products` - Get products
- `GET /api/tiktok/shops/:shopId/products/:productId` - Get product detail
- `POST /api/tiktok/product/202309/products` - Create new product
- `PUT /api/tiktok/shops/:shopId/products/:productId/price` - Update price
- `PUT /api/tiktok/shops/:shopId/products/:productId/stock` - Update stock
- `DELETE /api/tiktok/shops/:shopId/products/:productId` - Delete product
- `GET /api/tiktok/categories/:shopId` - Get category tree
- `GET /api/tiktok/categories/:shopId/:categoryId/attributes` - Get category attributes
- `POST /api/tiktok/orders/:shopId/list` - Get order list
- `GET /api/tiktok/orders/:shopId/detail/:orderId` - Get order detail
- `POST /api/tiktok/images/:shopId/upload` - Upload product image

**Shopee Integration**
- `GET /api/oauth/shopee/authorize` - Initiate OAuth flow
- `GET /api/oauth/shopee/callback` - OAuth callback handler
- `GET /api/oauth/shopee/shops` - List connected Shopee shops
- `GET /api/shopee/shops/:shopId/products` - Get products
- `GET /api/shopee/shops/:shopId/products/:productId` - Get product detail
- `POST /api/shopee/shops/:shopId/products` - Create new product
- `PUT /api/shopee/shops/:shopId/products/:productId/price` - Update price
- `PUT /api/shopee/shops/:shopId/products/:productId/stock` - Update stock
- `DELETE /api/shopee/shops/:shopId/products/:productId` - Delete product
- `PUT /api/shopee/shops/:shopId/products/:productId/unlist` - Unlist/list product
- `GET /api/shopee/categories` - Get category list
- `GET /api/shopee/categories/:categoryId/attributes` - Get category attributes
- `POST /api/shopee/orders/:shopId/list` - Get order list
- `GET /api/shopee/orders/:shopId/detail/:orderSn` - Get order detail
- `POST /api/shopee/orders/:shopId/ship/:orderSn` - Ship order
- `GET /api/shopee/orders/:shopId/tracking/:orderSn` - Get tracking number
- `POST /api/shopee/images/:shopId/upload` - Upload product image

**Group Management (Dashboard Integration)**
- `GET /api/groups/:groupId` - Get group configuration
- `POST /api/groups` - Create new group
- `PUT /api/groups/:groupId` - Update group settings

**Analytics**
- `GET /api/analytics/summary` - Get aggregated analytics across platforms
- `GET /api/analytics/orders` - Get order statistics
- `GET /api/analytics/revenue` - Get revenue data

**Health Check**
- `GET /health` - Server health status
- `GET /` - API information and available endpoints

## Database Schema

### MySQL Tables

**users**
- `id` (INT, PRIMARY KEY)
- `name` (VARCHAR 255)
- `email` (VARCHAR 255, UNIQUE)
- `password` (VARCHAR 255, hashed)
- `phone` (VARCHAR 20)
- `group_id` (VARCHAR 50, FK to groups)
- `auth_token` (VARCHAR 500)
- `token_expires_at` (DATETIME)
- `status` (ENUM: active, inactive)
- `created_at`, `updated_at`

**tokens**
- Platform OAuth tokens (TikTok, Shopee)
- Access token, refresh token, expiration

**user_shops**
- Maps users to their connected marketplace shops

**groups**
- `GID` (VARCHAR 50, PRIMARY KEY)
- `nama_group` (VARCHAR 255)
- `url` (VARCHAR 500) - Dashboard webhook URL
- `secret` (VARCHAR 255) - Webhook authentication secret
- `created_at`, `updated_at`

### SQLite Tables

**skus**
- `id` (INTEGER PRIMARY KEY)
- `sku` (TEXT UNIQUE)
- `name` (TEXT)
- `price` (REAL)
- `stock` (INTEGER)
- `created_at`, `updated_at`

**sku_product_mapping**
- `id` (INTEGER PRIMARY KEY)
- `sku` (TEXT)
- `platform` (TEXT) - TIKTOK or SHOPEE
- `shop_id` (TEXT)
- `product_id` (TEXT)
- `created_at`

## Architecture

### Directory Structure

```
src/
├── config/
│   ├── env.js              # Environment variable configuration
│   └── sequelize.js        # Database connection setup
├── controllers/
│   ├── analyticsController.js
│   ├── shopee/             # Shopee-specific controllers
│   └── tiktok/             # TikTok-specific controllers
├── middleware/
│   └── auth.js             # Authentication and rate limiting
├── models/
│   ├── User.js             # User model with authentication methods
│   ├── Token.js            # OAuth token storage
│   ├── UserShop.js         # Shop ownership mapping
│   └── Group.js            # Dashboard group configuration
├── routes/
│   ├── analyticsRoutes.js
│   ├── groupRoutes.js
│   ├── shopee/             # Shopee API routes
│   └── tiktok/             # TikTok API routes
├── services/
│   ├── shopee/             # Shopee API integration logic
│   └── tiktok/             # TikTok API integration logic
└── utils/
    ├── shopeeSignature.js  # Shopee API signature generation
    └── tiktokSignature.js  # TikTok API signature generation
```

### Key Components

**OAuth Flow**
1. Frontend redirects to `/api/oauth/{platform}/authorize`
2. User authenticates on marketplace platform
3. Marketplace redirects to `/api/oauth/{platform}/callback`
4. Backend exchanges authorization code for access token
5. Token stored in database, associated with user

**API Signature Generation**
- TikTok: HMAC-SHA256 signature for API authentication
- Shopee: HMAC-SHA256 signature for API authentication
- Automatic signature generation in service layers

**Rate Limiting**
- Applied to user registration and OAuth endpoints
- Default: 5 requests per 15 minutes per IP
- Configurable in middleware/auth.js

**Error Handling**
- Centralized error middleware
- Consistent error response format:
  ```json
  {
    "success": false,
    "message": "Error description"
  }
  ```

## Security

**Password Storage**
- Bcrypt hashing with salt rounds: 12
- Automatic hashing on user creation and password updates

**Token Management**
- JWT for user sessions
- OAuth tokens encrypted in database
- Automatic token refresh for expired marketplace tokens

**API Security**
- Helmet.js for HTTP header security
- CORS configuration for trusted origins
- Input validation and sanitization
- SQL injection prevention via Sequelize ORM

**Environment Variables**
- Never commit `.env` to version control
- Use strong secrets in production
- Rotate API keys regularly

## Development

### Running Tests

```bash
npm test
```

### Code Formatting

```bash
npm run format
```

### Testing Marketplace Integration

Test files included for API validation:
- `test-shopee.js` - Validate Shopee API configuration
- `test-shopee-orders.js` - Test Shopee order retrieval

Run tests:
```bash
node test-shopee.js
node test-shopee-orders.js
```

### Debugging

Enable verbose logging in development:
```bash
NODE_ENV=development npm run dev
```

Logs include:
- API request/response details
- Database query execution
- OAuth flow steps
- Error stack traces

## Deployment

### Production Checklist

1. Set `NODE_ENV=production` in environment
2. Use production database credentials
3. Configure production OAuth redirect URIs
4. Enable HTTPS (use nginx or similar as reverse proxy)
5. Set up process manager (PM2, systemd, etc.)
6. Configure firewall rules
7. Set up database backups
8. Enable application monitoring
9. Configure log rotation
10. Use production-grade secrets

### PM2 Deployment

```bash
npm install -g pm2
pm2 start server.js --name sparkcommerce-api
pm2 save
pm2 startup
```

### Nginx Reverse Proxy Example

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:5001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Troubleshooting

**Database Connection Fails**
- Verify MySQL credentials in `.env`
- Check MySQL server is running
- Ensure database exists
- Verify network connectivity

**OAuth Callback Errors**
- Confirm redirect URI matches marketplace app settings
- Check callback URL is accessible from internet (use ngrok for local testing)
- Verify app credentials are correct

**API Signature Errors**
- Ensure partner key/app secret are correct
- Check timestamp synchronization
- Verify API endpoint URLs

**SQLite Database Issues**
- Check file permissions in project directory
- Ensure sqlite3 module is installed
- Delete `sku_master.db` and restart to recreate

## Performance Optimization

**Database**
- Add indexes on frequently queried columns
- Use connection pooling (configured in sequelize.js)
- Optimize N+1 queries with eager loading

**Caching**
- Implement Redis for token caching
- Cache category and attribute data
- Use CDN for static assets

**Rate Limiting**
- Adjust limits based on usage patterns
- Implement per-user rate limiting
- Use distributed rate limiting for scaled deployments

## API Changes and Versioning

**Backward Compatibility Routes**

Legacy endpoints without platform prefix are maintained for backward compatibility:
- `/api/oauth/*` routes to TikTok endpoints
- `/api/product/*` routes to TikTok product endpoints

New implementations should use platform-specific routes:
- `/api/oauth/tiktok/*`
- `/api/oauth/shopee/*`
- `/api/tiktok/*`
- `/api/shopee/*`

**Deprecation Notice**

Legacy routes will be removed in v3.0.0. Migrate to platform-specific endpoints.

## Support

For backend-specific issues:
- Check server logs for error details
- Review database connectivity
- Verify environment configuration
- Test API endpoints with tools like Postman or curl

Refer to main project README for general support guidelines.
