// backend_ecommerce_manager_mobile/src/routes/createProductRoutes.js
const express = require("express");
const router = express.Router();
const createProductController = require("../../controllers/tiktok/createProductController");
const { authenticateToken } = require("../../middleware/auth"); //  Import yang benar

// Get brands for specific shop (with optional category filter)
router.get("/:shop_id/brands", createProductController.getBrands);

// Create custom brand for specific shop
router.post("/:shop_id/brands", createProductController.createBrand);

// Create new product for specific shop
router.post("/202309/products", createProductController.createProduct);

module.exports = router;
