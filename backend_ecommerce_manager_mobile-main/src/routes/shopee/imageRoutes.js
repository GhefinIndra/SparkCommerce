// src/routes/shopee/imageRoutes.js
const express = require("express");
const router = express.Router();
const { upload, uploadImage } = require("../../controllers/shopee/imageUploadController");

/**
 * Shopee Image Upload Routes
 * Base path: /api/shopee/images
 */

// Upload single image
router.post("/:shop_id/upload", upload.single("image"), uploadImage);

module.exports = router;
