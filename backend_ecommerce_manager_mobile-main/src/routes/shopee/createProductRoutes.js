// src/routes/shopee/createProductRoutes.js

const express = require('express');
const router = express.Router();
const createProductController = require('../../controllers/shopee/createProductController');
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

/**
 * Shopee Create Product Routes
 * All routes for creating products on Shopee
 */

// Get categories
// GET /api/shopee/categories?shop_id=xxx&language=en
router.get('/categories', authenticateUserToken, verifyShopAccess, createProductController.getCategories);

// Get category attributes
// GET /api/shopee/categories/:categoryId/attributes?shop_id=xxx&language=en
router.get(
  '/categories/:categoryId/attributes',
  authenticateUserToken,
  verifyShopAccess,
  createProductController.getCategoryAttributes,
);

// Get brand list for category
// GET /api/shopee/categories/:categoryId/brands?shop_id=xxx&offset=0&page_size=100&status=1&language=en
router.get(
  '/categories/:categoryId/brands',
  authenticateUserToken,
  verifyShopAccess,
  createProductController.getBrandList,
);

// Register new brand
// POST /api/shopee/brands
router.post('/brands', authenticateUserToken, verifyShopAccess, createProductController.registerBrand);

// Get item limits
// GET /api/shopee/item-limits?shop_id=xxx&category_id=xxx
router.get('/item-limits', authenticateUserToken, verifyShopAccess, createProductController.getItemLimits);

// Get logistics channels
// GET /api/shopee/logistics/channels?shop_id=xxx
router.get('/logistics/channels', authenticateUserToken, verifyShopAccess, createProductController.getLogisticsChannels);

// Create product
// POST /api/shopee/shops/:shopId/products
router.post(
  '/shops/:shopId/products',
  authenticateUserToken,
  verifyShopAccess,
  createProductController.createProduct,
);

module.exports = router;
