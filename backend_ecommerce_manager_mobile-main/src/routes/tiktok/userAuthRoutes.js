// routes/userAuthRoutes.js
const express = require("express");
const router = express.Router();
const userAuthController = require("../../controllers/tiktok/userAuthController");

// User authentication routes
router.post("/register", userAuthController.register);
router.post("/login", userAuthController.login);
router.get("/profile", userAuthController.profile);
router.post("/logout", userAuthController.logout);
router.put("/profile", userAuthController.updateProfile);
router.put("/change-password", userAuthController.changePassword);

module.exports = router;
