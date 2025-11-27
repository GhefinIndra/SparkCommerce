// src/routes/shopee/createProductRoutes.js

const express = require('express');
const router = express.Router();
const createProductController = require('../../controllers/shopee/createProductController');

/**
 * Shopee Create Product Routes
 * All routes for creating products on Shopee
 */

// Get categories
// GET /api/shopee/categories?shop_id=xxx&language=en
router.get('/categories', createProductController.getCategories);

// Get category attributes
// GET /api/shopee/categories/:categoryId/attributes?shop_id=xxx&language=en
router.get('/categories/:categoryId/attributes', createProductController.getCategoryAttributes);

// Get brand list for category
// GET /api/shopee/categories/:categoryId/brands?shop_id=xxx&offset=0&page_size=100&status=1&language=en
router.get('/categories/:categoryId/brands', createProductController.getBrandList);

// Register new brand
// POST /api/shopee/brands
router.post('/brands', createProductController.registerBrand);

// Get item limits
// GET /api/shopee/item-limits?shop_id=xxx&category_id=xxx
router.get('/item-limits', createProductController.getItemLimits);

// Get logistics channels
// GET /api/shopee/logistics/channels?shop_id=xxx
router.get('/logistics/channels', createProductController.getLogisticsChannels);

// Create product
// POST /api/shopee/shops/:shopId/products
router.post('/shops/:shopId/products', createProductController.createProduct);

module.exports = router;
