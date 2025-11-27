// backend_ecommerce_manager_mobile/src/routes/customerServiceRoutes.js
const express = require("express");
const multer = require("multer");
const customerServiceController = require("../../controllers/tiktok/customerServiceController");

const router = express.Router();

// Setup multer untuk upload image
const upload = multer({
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max file size
  },
  fileFilter: (req, file, cb) => {
    // Check file type
    const allowedTypes = [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/webp",
    ];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(
        new Error("Invalid file type. Only JPG, PNG, GIF, WEBP are allowed."),
        false,
      );
    }
  },
});

// Customer Service Routes
// Base path: /api/customer-service

// Get conversations for a shop
router.get(
  "/:shopId/conversations",
  customerServiceController.getConversations,
);

// Get messages from specific conversation
router.get(
  "/:shopId/conversations/:conversationId/messages",
  customerServiceController.getMessages,
);

// Create new conversation
router.post(
  "/:shopId/conversations",
  customerServiceController.createConversation,
);

// Send message to conversation
router.post(
  "/:shopId/conversations/:conversationId/messages",
  customerServiceController.sendMessage,
);

// Mark messages as read
router.post(
  "/:shopId/conversations/:conversationId/read",
  customerServiceController.readMessages,
);

// Upload image
router.post(
  "/:shopId/images/upload",
  upload.single("data"),
  customerServiceController.uploadImage,
);

module.exports = router;
