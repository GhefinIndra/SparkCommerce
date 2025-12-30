const express = require("express");
const router = express.Router();
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

// Import controller dengan error handling
let authController;
try {
  authController = require("../../controllers/tiktok/authController");
  console.log(" AuthController loaded successfully");
} catch (error) {
  console.error(" Error loading authController:", error.message);
  process.exit(1);
}

// Verify all required functions exist
const requiredFunctions = [
  "authorize",
  "callback",
  "getShops",
  "getShopInfo",
  "getAvailableShops",
  "claimShop",
  "deleteShop",
];
requiredFunctions.forEach((func) => {
  if (typeof authController[func] !== "function") {
    console.error(` Missing function: ${func} in authController`);
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

// Routes for claiming shops (untuk testing sandbox)
router.get("/shops-available", authenticateUserToken, authController.getAvailableShops);
router.post("/shops/claim/:shopId", authenticateUserToken, authController.claimShop);

console.log(" Auth routes registered successfully");

module.exports = router;
