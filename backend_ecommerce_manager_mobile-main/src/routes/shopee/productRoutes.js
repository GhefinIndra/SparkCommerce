// src/routes/shopee/productRoutes.js
const express = require("express");
const router = express.Router();
const productController = require("../../controllers/shopee/productController");

/**
 * Shopee Product Routes
 * Base path: /api/shopee
 */

// Get products list for specific shop
router.get("/shops/:shopId/products", productController.getProducts);

// Get product detail
router.get(
  "/shops/:shopId/products/:productId",
  productController.getProductDetail
);

// Update product price
router.put(
  "/shops/:shopId/products/:productId/price",
  productController.updatePrice
);

// Update product stock
router.put(
  "/shops/:shopId/products/:productId/stock",
  productController.updateStock
);

// Update product info (title, description)
router.put(
  "/shops/:shopId/products/:productId/info",
  productController.updateInfo
);

// Update product images
router.put(
  "/shops/:shopId/products/:productId/images",
  productController.updateImages
);

// Unlist/List product (deactivate/activate)
// Body: { unlist: true } to deactivate, { unlist: false } to activate
router.put(
  "/shops/:shopId/products/:productId/unlist",
  productController.unlistProduct
);

// Delete product (permanent deletion)
router.delete(
  "/shops/:shopId/products/:productId",
  productController.deleteProduct
);

module.exports = router;
