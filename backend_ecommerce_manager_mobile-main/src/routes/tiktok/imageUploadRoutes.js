// backend_ecommerce_manager_mobile/src/routes/imageUploadRoutes.js
const express = require("express");
const router = express.Router();
const imageUploadController = require("../../controllers/tiktok/imageUploadController");

// Error handling middleware untuk multer
const handleMulterError = (err, req, res, next) => {
  if (err instanceof require("multer").MulterError) {
    if (err.code === "LIMIT_FILE_SIZE") {
      return res.status(400).json({
        success: false,
        message: "File size exceeds 10MB limit",
      });
    }
    if (err.code === "LIMIT_FILE_COUNT") {
      return res.status(400).json({
        success: false,
        message: "Maximum 9 files allowed",
      });
    }
    if (err.code === "LIMIT_UNEXPECTED_FILE") {
      return res.status(400).json({
        success: false,
        message: "Unexpected field name for file upload",
      });
    }
  }

  if (
    err.message &&
    err.message.includes("Only") &&
    err.message.includes("files are allowed")
  ) {
    return res.status(400).json({
      success: false,
      message: err.message,
    });
  }

  next(err);
};

router.post(
  "/:shop_id/upload",
  imageUploadController.uploadMiddleware.single("data"), // Field name 'data' sesuai TikTok API
  handleMulterError,
  imageUploadController.uploadImage,
);

router.post(
  "/:shop_id/upload-multiple",
  imageUploadController.uploadMiddleware.array("data", 9), // Max 9 files sesuai TikTok limit
  handleMulterError,
  imageUploadController.uploadMultipleImages,
);

module.exports = router;
