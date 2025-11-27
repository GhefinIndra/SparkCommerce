// backend_ecommerce_manager_mobile/server.js
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const config = require("./src/config/env");
const { securityHeaders, createRateLimit } = require("./src/middleware/auth");

// TikTok Routes
const tiktokAuthRoutes = require("./src/routes/tiktok/authRoutes");
const tiktokUserAuthRoutes = require("./src/routes/tiktok/userAuthRoutes");
const tiktokProductRoutes = require("./src/routes/tiktok/productRoutes");
const tiktokCreateProductRoutes = require("./src/routes/tiktok/createProductRoutes");
const tiktokCategoryRoutes = require("./src/routes/tiktok/categoryRoutes");
const tiktokOrderRoutes = require("./src/routes/tiktok/orderRoutes");
const tiktokCustomerServiceRoutes = require("./src/routes/tiktok/customerServiceRoute");
const tiktokImageUploadRoutes = require("./src/routes/tiktok/imageUploadRoutes");

// Shopee Routes
const shopeeAuthRoutes = require("./src/routes/shopee/authRoutes");
const shopeeProductRoutes = require("./src/routes/shopee/productRoutes");
const shopeeImageRoutes = require("./src/routes/shopee/imageRoutes");
const shopeeOrderRoutes = require("./src/routes/shopee/orderRoutes");
const shopeeCreateProductRoutes = require("./src/routes/shopee/createProductRoutes");

// Analytics Routes (Multi-Platform)
const analyticsRoutes = require("./src/routes/analyticsRoutes");

// Group Routes (Dashboard Integration)
const groupRoutes = require("./src/routes/groupRoutes");

const app = express();
const PORT = process.env.PORT || 5000;

// Basic middleware
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({ extended: true, limit: "50mb" }));

// CORS Configuration
app.use(
  cors({
    origin: [
      "http://localhost:3000",
      "http://10.0.2.2:5000",
      "http://127.0.0.1:5000",
      "http://192.168.137.142:5000",
      "http://192.168.137.142:3000",
    ],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "auth_token"],
    credentials: true,
    optionsSuccessStatus: 200,
  }),
);

// Handle preflight OPTIONS requests
app.options("*", (req, res) => {
  res.header("Access-Control-Allow-Origin", req.get("origin") || "*");
  res.header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
  res.header(
    "Access-Control-Allow-Headers",
    "Content-Type,Authorization,auth_token",
  );
  res.header("Access-Control-Allow-Credentials", "true");
  res.sendStatus(200);
});

// Security & Rate limiting middleware
app.use(securityHeaders());
app.use("/api/user", createRateLimit());
app.use("/api/oauth", createRateLimit());

// TikTok Routes Registration (New endpoints with /tiktok prefix)
app.use("/api/oauth/tiktok", tiktokAuthRoutes);
app.use("/api/user", tiktokUserAuthRoutes);
app.use("/api/tiktok/product", tiktokCreateProductRoutes);
app.use("/api/tiktok/categories", tiktokCategoryRoutes);
app.use("/api/tiktok/shops", tiktokCreateProductRoutes);
app.use("/api/tiktok/orders", tiktokOrderRoutes);
app.use("/api/tiktok/customer-service", tiktokCustomerServiceRoutes);
app.use("/api/tiktok/images", tiktokImageUploadRoutes);
app.use("/api/tiktok", tiktokProductRoutes);

// ️ BACKWARD COMPATIBILITY ROUTES (for existing mobile app)
// These routes redirect old endpoints to new TikTok endpoints
// TODO: Remove these after mobile app is updated
app.use("/api/oauth", tiktokAuthRoutes); // Old: /api/oauth/* -> New: /api/oauth/tiktok/*
app.use("/api/product", tiktokCreateProductRoutes); // Old: /api/product/* -> New: /api/tiktok/product/*
app.use("/api/categories", tiktokCategoryRoutes); // Old: /api/categories/* -> New: /api/tiktok/categories/*
app.use("/api/shops", tiktokCreateProductRoutes); // Old: /api/shops/* -> New: /api/tiktok/shops/*
app.use("/api/orders", tiktokOrderRoutes); // Old: /api/orders/* -> New: /api/tiktok/orders/*
app.use("/api/customer-service", tiktokCustomerServiceRoutes); // Old: /api/customer-service/* -> New: /api/tiktok/customer-service/*
app.use("/api/images", tiktokImageUploadRoutes); // Old: /api/images/* -> New: /api/tiktok/images/*
app.use("/api", tiktokProductRoutes); // Old: /api/* -> New: /api/tiktok/*

// Shopee Routes Registration
app.use("/api/oauth/shopee", shopeeAuthRoutes);
app.use("/api/shopee", shopeeCreateProductRoutes); // Create product routes (categories, attributes, logistics, create)
app.use("/api/shopee", shopeeProductRoutes); // Product management routes
app.use("/api/shopee/images", shopeeImageRoutes);
app.use("/api/shopee/orders", shopeeOrderRoutes);

// Analytics Routes Registration (Multi-Platform)
app.use("/api/analytics", analyticsRoutes);

// Group Routes Registration (Dashboard Integration)
app.use("/api/groups", groupRoutes);

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    environment: config.server.nodeEnv || process.env.NODE_ENV || "development",
  });
});

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    message: "Multi-Platform E-commerce Manager API is running!",
    version: "2.0.0",
    status: "OK",
    timestamp: new Date().toISOString(),
    platforms: {
      tiktok: {
        status: "active",
        new_endpoints: [
          "/api/oauth/tiktok/* (TikTok OAuth routes)",
          "/api/tiktok/* (TikTok product routes)",
          "/api/tiktok/shops/* (TikTok shop routes)",
          "/api/tiktok/orders/* (TikTok order routes)",
          "/api/tiktok/categories/* (TikTok category routes)",
          "/api/tiktok/customer-service/* (TikTok chat routes)",
          "/api/tiktok/images/* (TikTok image upload routes)",
        ],
        legacy_endpoints: [
          "/api/oauth/* (DEPRECATED - use /api/oauth/tiktok/*)",
          "/api/product/* (DEPRECATED - use /api/tiktok/product/*)",
          "/api/shops/* (DEPRECATED - use /api/tiktok/shops/*)",
          "/api/orders/* (DEPRECATED - use /api/tiktok/orders/*)",
          "/api/categories/* (DEPRECATED - use /api/tiktok/categories/*)",
          "/api/customer-service/* (DEPRECATED - use /api/tiktok/customer-service/*)",
          "/api/images/* (DEPRECATED - use /api/tiktok/images/*)",
        ],
      },
      shopee: {
        status: "active",
        endpoints: [
          "/api/oauth/shopee/authorize (Shopee OAuth authorization)",
          "/api/oauth/shopee/callback (Shopee OAuth callback)",
          "/api/oauth/shopee/shops (Get Shopee shops)",
          "/api/oauth/shopee/shops/:shopId/info (Get specific shop info)",
          "/api/oauth/shopee/refresh-token (Refresh access token)",
          "/api/shopee/shops/:shopId/products (Get Shopee products)",
          "/api/shopee/shops/:shopId/products/:productId (Get Shopee product detail)",
          "/api/shopee/orders/:shopId/list (Get Shopee order list)",
          "/api/shopee/orders/:shopId/detail/:orderSns (Get Shopee order detail)",
          "/api/shopee/orders/:shopId/ship/:orderSn (Ship Shopee order)",
          "/api/shopee/orders/:shopId/tracking/:orderSn (Get tracking number)",
        ],
      },
    },
    common_endpoints: [
      "/api/user/* (user auth routes - shared)",
      "/health (health check)",
    ],
    note: "Legacy endpoints are supported for backward compatibility. Please migrate to new endpoints with platform prefix.",
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error("Server Error:", error.message);

  // Handle file upload errors
  if (error.code === "LIMIT_FILE_SIZE") {
    return res.status(400).json({
      success: false,
      message: "File too large. Maximum size is 50MB per file.",
    });
  }

  if (error.code === "LIMIT_FILE_COUNT") {
    return res.status(400).json({
      success: false,
      message: "Too many files. Maximum 9 files allowed.",
    });
  }

  if (error.message && error.message.includes("Only image files are allowed")) {
    return res.status(400).json({
      success: false,
      message: "Only image files are allowed (jpg, jpeg, png, gif, etc.)",
    });
  }

  // General error response
  res.status(500).json({
    success: false,
    message: "Internal server error",
    error:
      process.env.NODE_ENV === "development"
        ? error.message
        : "Something went wrong",
  });
});

// 404 handler
app.use("*", (req, res) => {
  res.status(404).json({
    success: false,
    message: "Endpoint not found",
  });
});

// Database sync function
async function syncDatabase() {
  try {
    console.log("Connecting to database...");
    const sequelize = require("./src/config/sequelize");

    console.log("Loading models...");
    const Token = require("./src/models/Token");
    const User = require("./src/models/User");
    const UserShop = require("./src/models/UserShop");

    // Test connection
    console.log("Testing database connection...");
    await sequelize.authenticate();
    console.log("Database connection established");

    console.log("Syncing database tables...");
    await sequelize.sync({ alter: true });
    console.log("Database tables synced");

    return true;
  } catch (error) {
    console.error("Database sync failed:", error.message);
    console.error("Error details:", error);
    return false;
  }
}

// SQLite Database for SKU Master
function initSQLiteDatabase() {
  try {
    console.log("Initializing SQLite database for SKU Master...");
    const sqlite3 = require("sqlite3").verbose();
    const path = require("path");
    const dbPath = path.join(__dirname, "sku_master.db");

    const db = new sqlite3.Database(dbPath, (err) => {
      if (err) {
        console.error("Error opening SQLite database:", err.message);
      } else {
        console.log("SQLite database connected");
      }
    });

    // Create SKUs table if not exists
    db.run(`
      CREATE TABLE IF NOT EXISTS skus (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        price REAL DEFAULT 0,
        stock INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create SKU-Product mapping table if not exists
    db.run(`
      CREATE TABLE IF NOT EXISTS sku_product_mapping (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT NOT NULL,
        platform TEXT NOT NULL,
        shop_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(sku, platform, shop_id, product_id)
      )
    `);

    // Make db available globally
    app.locals.db = db;

    return db;
  } catch (error) {
    console.error("SQLite initialization failed:", error.message);
    return null;
  }
}

// Start server
async function startServer() {
  try {
    // Sync PostgreSQL/MySQL database tables
    const dbOk = await syncDatabase();
    if (!dbOk) {
      console.log("Database sync failed, but server will continue...");
    }

    // Initialize SQLite for SKU Master
    initSQLiteDatabase();

    // Start listening
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
      console.log(
        `Environment: ${config.server.nodeEnv || process.env.NODE_ENV || "development"}`,
      );
      console.log(`Databases connected and synced`);
    });
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
}

startServer();
