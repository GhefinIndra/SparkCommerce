// routes/analyticsRoutes.js - Multi-Platform Analytics
const express = require('express');
const router = express.Router();
const analyticsController = require('../controllers/analyticsController');
const {
  authenticateUserToken,
  verifyShopAccess,
  attachUserShopIds,
} = require('../middleware/auth');
// NOTE: analytics routes require auth_token via authenticateUserToken

/**
 *  ANALYTICS ROUTES - Multi-Platform
 *
 * All routes support query parameters:
 * - platform: 'all' | 'tiktok' | 'shopee' (default: 'all')
 * - startDate: ISO date string (default: 30 days ago)
 * - endDate: ISO date string (default: now)
 *
 * Shop-specific routes: /analytics/shops/:shopId/...
 * All-shops routes: /analytics/...
 */

// ============================================
// 1. SALES ANALYTICS
// ============================================

/**
 * GET /api/analytics/sales-summary
 * Get sales summary for all shops
 * Query: ?platform=all&startDate=2024-01-01&endDate=2024-01-31
 */
router.get(
  '/sales-summary',
  authenticateUserToken,
  attachUserShopIds,
  analyticsController.getSalesSummary
);

/**
 * GET /api/analytics/shops/:shopId/sales-summary
 * Get sales summary for specific shop
 */
router.get(
  '/shops/:shopId/sales-summary',
  authenticateUserToken,
  verifyShopAccess,
  analyticsController.getSalesSummary
);

/**
 * GET /api/analytics/revenue-trend
 * Get revenue trend over time (for charts)
 * Query: ?groupBy=day|week|month
 */
router.get(
  '/revenue-trend',
  authenticateUserToken,
  attachUserShopIds,
  analyticsController.getRevenueTrend
);

/**
 * GET /api/analytics/shops/:shopId/revenue-trend
 * Get revenue trend for specific shop
 */
router.get(
  '/shops/:shopId/revenue-trend',
  authenticateUserToken,
  verifyShopAccess,
  analyticsController.getRevenueTrend
);

// ============================================
// 2. ORDER ANALYTICS
// ============================================

/**
 * GET /api/analytics/order-status-breakdown
 * Get order status distribution (for pie/donut chart)
 */
router.get(
  '/order-status-breakdown',
  authenticateUserToken,
  attachUserShopIds,
  analyticsController.getOrderStatusBreakdown
);

/**
 * GET /api/analytics/shops/:shopId/order-status-breakdown
 * Get order status breakdown for specific shop
 */
router.get(
  '/shops/:shopId/order-status-breakdown',
  authenticateUserToken,
  verifyShopAccess,
  analyticsController.getOrderStatusBreakdown
);

// ============================================
// 3. PRODUCT ANALYTICS
// ============================================

/**
 * GET /api/analytics/top-products
 * Get top selling products across all shops
 * Query: ?sortBy=quantity|revenue&limit=10
 */
router.get(
  '/top-products',
  authenticateUserToken,
  attachUserShopIds,
  analyticsController.getTopProducts
);

/**
 * GET /api/analytics/shops/:shopId/top-products
 * Get top products for specific shop
 */
router.get(
  '/shops/:shopId/top-products',
  authenticateUserToken,
  verifyShopAccess,
  analyticsController.getTopProducts
);

// ============================================
// 4. SKU ANALYTICS
// ============================================

/**
 * GET /api/analytics/sku-analytics
 * Get SKU performance and inventory analytics
 */
router.get(
  '/sku-analytics',
  authenticateUserToken,
  analyticsController.getSKUAnalytics
);

// ============================================
// 5. SHOP COMPARISON
// ============================================

/**
 * GET /api/analytics/shop-comparison
 * Compare performance across all shops
 * Returns ranked list of shops by revenue
 */
router.get(
  '/shop-comparison',
  authenticateUserToken,
  attachUserShopIds,
  analyticsController.getShopComparison
);

module.exports = router;
