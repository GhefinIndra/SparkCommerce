// src/routes/productRoutes.js
const express = require("express");
const router = express.Router();
const productController = require("../../controllers/tiktok/productController");
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");
const Token = require("../../models/Token");
const productApi = require("../../services/tiktok/productAPI");

// Routes untuk mobile product management

// Get all shops - untuk dashboard mobile
router.get("/shops", authenticateUserToken, productController.getShops);

// Product routes untuk shop tertentu
router.get(
  "/shops/:shopId/products",
  authenticateUserToken,
  verifyShopAccess,
  productController.getProducts,
);
router.get(
  "/shops/:shopId/products/:productId",
  authenticateUserToken,
  verifyShopAccess,
  productController.getProductDetail,
);
router.get(
  "/shops/:shopId/warehouses",
  authenticateUserToken,
  verifyShopAccess,
  async (req, res) => {
  try {
    const { shopId } = req.params;

    const token = await Token.findByShopId(shopId);
    if (!token) {
      return res.status(404).json({
        success: false,
        message: "Shop not found",
      });
    }

    const warehouses = await productApi.getActiveWarehouses(
      token.access_token,
      token.shop_cipher,
    );

    res.json({
      success: true,
      data: warehouses,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to get warehouses",
      error: error.message,
    });
  }
});

// Update product routes
router.put(
  "/shops/:shopId/products/:productId/info",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateProductInfo,
);
router.put(
  "/shops/:shopId/products/:productId/price",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateProductPrice,
);
router.put(
  "/shops/:shopId/products/:productId/stock",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateProductStock,
);

// Upload image sudah dipindah ke imageUploadRoutes.js
router.put(
  "/shops/:shopId/products/:productId/images",
  authenticateUserToken,
  verifyShopAccess,
  productController.updateProductImages,
);

// Delete product
router.delete(
  "/shops/:shopId/products/:productId",
  authenticateUserToken,
  verifyShopAccess,
  productController.deleteProduct,
);
// Activate/Deactivate/Recover product routes
router.post(
  "/shops/:shopId/products/:productId/activate",
  authenticateUserToken,
  verifyShopAccess,
  productController.activateProduct,
);
router.post(
  "/shops/:shopId/products/:productId/deactivate",
  authenticateUserToken,
  verifyShopAccess,
  productController.deactivateProduct,
);
router.post(
  "/shops/:shopId/products/:productId/recover",
  authenticateUserToken,
  verifyShopAccess,
  productController.recoverProduct,
);

// ============ SKU SYNC ROUTES ============

// Sync stock to marketplace (TikTok/Shopee)
router.put(
  "/shops/:shopId/products/:productId/sync-stock",
  authenticateUserToken,
  verifyShopAccess,
  productController.syncStockToMarketplace,
);

// Get stock from marketplace
router.get(
  "/shops/:shopId/products/:productId/get-stock",
  authenticateUserToken,
  verifyShopAccess,
  productController.getStockFromMarketplace,
);

module.exports = router;
