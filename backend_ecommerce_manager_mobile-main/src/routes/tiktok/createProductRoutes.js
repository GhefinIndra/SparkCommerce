// backend_ecommerce_manager_mobile/src/routes/createProductRoutes.js
const express = require("express");
const router = express.Router();
const createProductController = require("../../controllers/tiktok/createProductController");
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

// Get brands for specific shop (with optional category filter)
router.get(
  "/:shop_id/brands",
  authenticateUserToken,
  verifyShopAccess,
  createProductController.getBrands,
);

// Create custom brand for specific shop
router.post(
  "/:shop_id/brands",
  authenticateUserToken,
  verifyShopAccess,
  createProductController.createBrand,
);

// Create new product for specific shop
router.post(
  "/202309/products",
  authenticateUserToken,
  verifyShopAccess,
  createProductController.createProduct,
);

module.exports = router;
