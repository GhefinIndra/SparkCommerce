// backend_ecommerce_manager_mobile/src/middleware/auth.js
const jwt = require("jsonwebtoken");
const Token = require("../models/Token");

// JWT Secret (add to env later)
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key-change-this";

// Generate JWT token for mobile app sessions
const generateToken = (payload) => {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
};

// Verify JWT token
const verifyToken = (token) => {
  return jwt.verify(token, JWT_SECRET);
};

// Middleware to authenticate requests
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1]; // Bearer TOKEN

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Access token required",
      });
    }

    const decoded = verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    console.error("Auth middleware error:", error.message);
    return res.status(403).json({
      success: false,
      message: "Invalid or expired token",
    });
  }
};

// Middleware to verify shop access
const verifyShopAccess = async (req, res, next) => {
  try {
    const { shopId } = req.params;
    const userId = req.user?.id;

    if (!shopId) {
      return res.status(400).json({
        success: false,
        message: "Shop ID required",
      });
    }

    // Check if user has access to this shop
    const shop = await Token.findOne({
      where: {
        shop_id: shopId,
        status: "active",
      },
    });

    if (!shop) {
      return res.status(404).json({
        success: false,
        message: "Shop not found or access denied",
      });
    }

    req.shop = shop;
    next();
  } catch (error) {
    console.error("Shop access verification error:", error.message);
    return res.status(500).json({
      success: false,
      message: "Error verifying shop access",
    });
  }
};

// Rate limiting middleware
const createRateLimit = (windowMs = 15 * 60 * 1000, max = 100) => {
  const rateLimit = require("express-rate-limit");

  return rateLimit({
    windowMs, // 15 minutes
    max, // limit each IP to max requests per windowMs
    message: {
      success: false,
      message: "Too many requests, please try again later.",
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
};

// Middleware to authenticate with auth_token (for User model)
const authenticateUserToken = async (req, res, next) => {
  try {
    const User = require("../models/User");
    const authToken = req.headers["auth_token"];

    if (!authToken) {
      return res.status(401).json({
        success: false,
        message: "Access token required",
      });
    }

    // Find user by auth_token using static method
    const user = await User.findByAuthToken(authToken);

    if (!user) {
      return res.status(403).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error("User auth middleware error:", error.message);
    return res.status(403).json({
      success: false,
      message: "Invalid or expired token",
    });
  }
};

// Security headers middleware
const securityHeaders = require("helmet");

module.exports = {
  generateToken,
  verifyToken,
  authenticateToken,
  authenticate: authenticateToken, // Alias for convenience (JWT)
  authenticateUserToken, // NEW: For auth_token in header
  verifyShopAccess,
  createRateLimit,
  securityHeaders,
};
