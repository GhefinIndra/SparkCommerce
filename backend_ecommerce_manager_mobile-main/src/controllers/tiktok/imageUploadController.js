// backend_ecommerce_manager_mobile/src/controllers/imageUploadController.js

const multer = require("multer");
const axios = require("axios");
const FormData = require("form-data");
const config = require("../../config/env");
const { generateSignature } = require("../../utils/tiktokSignature");

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  // Check if file is an image with supported formats
  const supportedFormats = [
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/bmp",
  ];

  if (supportedFormats.includes(file.mimetype.toLowerCase())) {
    cb(null, true);
  } else {
    cb(
      new Error("Only JPG, JPEG, PNG, WEBP, HEIC, BMP files are allowed!"),
      false,
    );
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit as per TikTok Shop specs
  },
});

const imageUploadController = {
  // Upload single image to TikTok Shop
  uploadImage: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { use_case = "MAIN_IMAGE" } = req.body; // Default to MAIN_IMAGE

      if (!req.file) {
        return res.status(400).json({
          success: false,
          message: "No image file provided",
        });
      }

      console.log(" Uploading image for shop:", shop_id);
      console.log(" File info:", {
        filename: req.file.originalname,
        size: req.file.size,
        mimetype: req.file.mimetype,
        use_case: use_case,
      });

      // Validate use_case
      const validUseCases = [
        "MAIN_IMAGE",
        "ATTRIBUTE_IMAGE",
        "DESCRIPTION_IMAGE",
        "CERTIFICATION_IMAGE",
        "SIZE_CHART_IMAGE",
      ];
      if (!validUseCases.includes(use_case)) {
        return res.status(400).json({
          success: false,
          message: `Invalid use_case. Must be one of: ${validUseCases.join(", ")}`,
        });
      }

      // Get shop token data
      const Token = require("../../models/Token");
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token, shop_cipher } = tokenData;

      const formData = new FormData();
      formData.append("data", req.file.buffer, {
        filename: req.file.originalname,
        contentType: req.file.mimetype,
      });

      // Add use_case parameter
      formData.append("use_case", use_case);

      // Generate API signature for image upload
      const timestamp = Math.floor(Date.now() / 1000);
      const appKey = config.tiktok.appKey;
      const appSecret = config.tiktok.appSecret;

      const params = {
        app_key: appKey,
        timestamp: timestamp,
      };

      // Generate signature for POST request
      const signature = generateSignature(
        params,
        appSecret,
        "/product/202309/images/upload",
        "POST",
        "",
      );

      // Call TikTok Shop Upload Image API
      const apiUrl = `${config.tiktok.apiUrl}/product/202309/images/upload`;

      console.log(" Upload Image API Call:", {
        url: apiUrl,
        params: { ...params, sign: "***" },
        fileSize: req.file.size,
        use_case: use_case,
      });

      const response = await axios.post(apiUrl, formData, {
        headers: {
          ...formData.getHeaders(),
          "content-type": "multipart/form-data",
          "x-tts-access-token": access_token,
        },
        params: {
          ...params,
          sign: signature,
        },
        timeout: 60000, // 60 seconds timeout for image upload
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
      });

      console.log(" TikTok Shop Upload Image API Response:", {
        code: response.data.code,
        message: response.data.message,
        data: response.data.data,
      });

      if (response.data.code === 0) {
        console.log(" Image uploaded successfully:", response.data.data.uri);

        res.json({
          success: true,
          message: "Image uploaded successfully",
          data: {
            uri: response.data.data.uri,
            url: response.data.data.url,
            width: response.data.data.width,
            height: response.data.data.height,
            use_case: response.data.data.use_case,
          },
        });
      } else {
        console.error(" TikTok Shop Upload API Error:", {
          code: response.data.code,
          message: response.data.message,
        });
        res.status(400).json({
          success: false,
          message: response.data.message || "Failed to upload image",
          error_code: response.data.code,
        });
      }
    } catch (error) {
      console.error(" Error uploading image:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });

      res.status(500).json({
        success: false,
        message: "Failed to upload image",
        error: error.response?.data || error.message,
      });
    }
  },

  // Upload multiple images
  uploadMultipleImages: async (req, res) => {
    try {
      const { shop_id } = req.params;
      const { use_case = "MAIN_IMAGE" } = req.body;

      if (!req.files || req.files.length === 0) {
        return res.status(400).json({
          success: false,
          message: "No image files provided",
        });
      }

      // Validate TikTok Shop limit (usually max 9 images per product)
      if (req.files.length > 9) {
        return res.status(400).json({
          success: false,
          message: "Maximum 9 images allowed per upload",
        });
      }

      console.log(" Uploading multiple images for shop:", shop_id);
      console.log(" Files count:", req.files.length);

      const uploadResults = [];
      const errors = [];

      // Get shop token data once
      const Token = require("../../models/Token");
      const tokenData = await Token.findByShopId(shop_id);
      if (!tokenData) {
        return res.status(404).json({
          success: false,
          message: "Shop not found",
        });
      }

      const { access_token } = tokenData;

      // Upload each image sequentially to avoid rate limiting
      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        try {
          console.log(
            ` Uploading image ${i + 1}/${req.files.length}: ${file.originalname}`,
          );

          const formData = new FormData();
          formData.append("data", file.buffer, {
            filename: file.originalname,
            contentType: file.mimetype,
          });
          formData.append("use_case", use_case);

          // Generate API signature
          const timestamp = Math.floor(Date.now() / 1000);
          const params = {
            app_key: config.tiktok.appKey,
            timestamp: timestamp,
          };

          const signature = generateSignature(
            params,
            config.tiktok.appSecret,
            "/product/202309/images/upload",
            "POST",
            "",
          );
          const apiUrl = `${config.tiktok.apiUrl}/product/202309/images/upload`;

          const response = await axios.post(apiUrl, formData, {
            headers: {
              ...formData.getHeaders(),
              "content-type": "multipart/form-data",
              "x-tts-access-token": access_token,
            },
            params: {
              ...params,
              sign: signature,
            },
            timeout: 60000,
            maxContentLength: Infinity,
            maxBodyLength: Infinity,
          });

          if (response.data.code === 0) {
            uploadResults.push({
              index: i,
              filename: file.originalname,
              uri: response.data.data.uri,
              url: response.data.data.url,
              width: response.data.data.width,
              height: response.data.data.height,
              use_case: response.data.data.use_case,
              success: true,
            });
          } else {
            errors.push({
              index: i,
              filename: file.originalname,
              error: response.data.message || "Upload failed",
              error_code: response.data.code,
              success: false,
            });
          }

          // Add small delay between uploads to avoid rate limiting
          if (i < req.files.length - 1) {
            await new Promise((resolve) => setTimeout(resolve, 500));
          }
        } catch (error) {
          console.error(
            ` Failed to upload image ${i + 1}: ${file.originalname}`,
            error,
          );

          errors.push({
            index: i,
            filename: file.originalname,
            error: error.message || "Upload failed",
            error_code: error.response?.data?.code,
            success: false,
          });
        }
      }

      const successCount = uploadResults.length;
      const totalCount = req.files.length;

      res.json({
        success: successCount > 0,
        message: `Uploaded ${successCount}/${totalCount} images successfully`,
        data: {
          successful_uploads: uploadResults,
          failed_uploads: errors,
          total_files: totalCount,
          successful_count: successCount,
          failed_count: errors.length,
        },
      });
    } catch (error) {
      console.error(" Error uploading multiple images:", error.message);

      res.status(500).json({
        success: false,
        message: "Failed to upload images",
        error: error.message,
      });
    }
  },
};

// Export multer middleware
imageUploadController.uploadMiddleware = upload;

module.exports = imageUploadController;
