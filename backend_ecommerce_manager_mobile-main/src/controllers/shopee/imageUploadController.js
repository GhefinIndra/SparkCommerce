// src/controllers/shopee/imageUploadController.js

const multer = require("multer");
const imageApi = require("../../services/shopee/imageAPI");
const authService = require("../../services/shopee/authService");

// Use memory storage
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Check if file is an image with supported formats
  const supportedFormats = [
    "image/jpeg",
    "image/jpg",
    "image/png",
  ];

  if (supportedFormats.includes(file.mimetype.toLowerCase())) {
    cb(null, true);
  } else {
    cb(
      new Error("Only JPG, JPEG, PNG files are allowed!"),
      false,
    );
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit as per Shopee specs
  },
});

const shopeeImageUploadController = {
  // Upload single image to Shopee
  uploadImage: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { scene = "normal", ratio = "1:1" } = req.body;

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "No image file provided",
        });
      }

      console.log(" Uploading image to Shopee for shop:", shop_id);
      console.log(" File info:", {
        filename: req.file.originalname,
        size: req.file.size,
        mimetype: req.file.mimetype,
        scene,
        ratio,
      });

      // Validate scene
      const validScenes = ["normal", "desc"];
      if (!validScenes.includes(scene)) {
        return res.status(400).json({
          success: false,
          message: `Invalid scene. Must be one of: ${validScenes.join(", ")}`,
        });
      }

      // Validate ratio
      const validRatios = ["1:1", "3:4"];
      if (!validRatios.includes(ratio)) {
        return res.status(400).json({
          success: false,
          message: `Invalid ratio. Must be one of: ${validRatios.join(", ")}`,
        });
      }

      // Get shop token data (for validation, not used in media_space API)
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      console.log(" Using Shopee token for image upload");

      // Call Shopee Image Upload API
      const uploadResult = await imageApi.uploadImage(
        token.access_token, // Not used by API but passed for consistency
        req.file.buffer,
        req.file.originalname,
        scene,
        ratio
      );

      console.log(" Image uploaded successfully:", {
        image_id: uploadResult.image_id,
        has_url: !!uploadResult.image_url,
      });

      res.status(200).json({
        success: true,
        message: "Image uploaded successfully",
        data: {
          image_id: uploadResult.image_id,
          image_url: uploadResult.image_url,
          uri: uploadResult.image_id, // For compatibility with frontend
          url: uploadResult.image_url, // For compatibility with frontend
        },
      });
    } catch (error) {
      console.error(" Error uploading image to Shopee:", error);

      res.status(500).json({
        success: false,
        message: "Failed to upload image",
        error: error.message,
      });
    }
  },
};

module.exports = {
  upload,
  ...shopeeImageUploadController,
};
