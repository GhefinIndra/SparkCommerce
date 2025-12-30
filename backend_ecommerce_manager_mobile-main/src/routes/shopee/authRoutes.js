// src/routes/shopee/authRoutes.js
const express = require("express");
const router = express.Router();
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

// Import controller dengan error handling
let authController;
try {
  authController = require("../../controllers/shopee/authController");
  console.log(" Shopee AuthController loaded successfully");
} catch (error) {
  console.error(" Error loading Shopee authController:", error.message);
  process.exit(1);
}

// Verify all required functions exist
const requiredFunctions = [
  "authorize",
  "callback",
  "getShops",
  "getShopInfo",
  "refreshAccessToken",
  "deleteShop",
];

requiredFunctions.forEach((func) => {
  if (typeof authController[func] !== "function") {
    console.error(` Missing function: ${func} in Shopee authController`);
    process.exit(1);
  }
});

// OAuth routes
router.get("/authorize", authController.authorize);
router.get("/callback", authController.callback);

// Shop management routes (for mobile app)
router.get("/shops", authenticateUserToken, authController.getShops);
router.get("/shops/:shopId/info", authenticateUserToken, verifyShopAccess, authController.getShopInfo);
router.delete("/shops/:shopId", authenticateUserToken, verifyShopAccess, authController.deleteShop);

// Token refresh
router.post("/refresh-token", authenticateUserToken, verifyShopAccess, authController.refreshAccessToken);

console.log(" Shopee auth routes registered successfully");

module.exports = router;
