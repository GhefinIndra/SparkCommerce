// src/routes/shopee/productRoutes.js
const express = require("express");
const router = express.Router();
const productController = require("../../controllers/shopee/productController");
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

/**
 * Shopee Product Routes
 * Base path: /api/shopee
 */

// Get products list for specific shop
router.get(
  "/shops/:shopId/products",
  authenticateUserToken,
  verifyShopAccess,
  productController.getProducts,
);

// Get product detail
router.get(
  "/shops/:shopId/products/:productId",
  authenticateUserToken,
  verifyShopAccess,
  productController.getProductDetail
);

// Update product price
router.put(
  "/shops/:shopId/products/:productId/price",
  authenticateUserToken,
  verifyShopAccess,
  productController.updatePrice
);

// Update product stock
router.put(
  "/shops/:shopId/products/:productId/stock",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateStock
);

// Update product info (title, description)
router.put(
  "/shops/:shopId/products/:productId/info",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateInfo
);

// Update product images
router.put(
  "/shops/:shopId/products/:productId/images",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateImages
);

// Unlist/List product (deactivate/activate)
// Body: { unlist: true } to deactivate, { unlist: false } to activate
router.put(
  "/shops/:shopId/products/:productId/unlist",
  authenticateUserToken,
  verifyShopAccess,
  productController.unlistProduct
);

// Delete product (permanent deletion)
router.delete(
  "/shops/:shopId/products/:productId",
  authenticateUserToken,
  verifyShopAccess,
  productController.deleteProduct
);

module.exports = router;
