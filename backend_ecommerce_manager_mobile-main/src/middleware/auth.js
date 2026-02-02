// backend_ecommerce_manager_mobile/src/middleware/auth.js
const jwt = require("jsonwebtoken");
const Token = require("../models/Token");
const UserShop = require("../models/UserShop");
const Shop = require("../models/Shop");

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

const resolveShopIdentifier = (req) => {
  let shopId =
    req.params.shopId ||
    req.params.shop_id ||
    req.body?.shopId ||
    req.body?.shop_id ||
    req.query?.shopId ||
    req.query?.shop_id ||
    req.query?.sellerId;

  if (!shopId && req.query?.filters) {
    try {
      const parsed = JSON.parse(req.query.filters);
      shopId = parsed.shopId || parsed.shop_id || parsed.sellerId;
    } catch (_) {
      // ignore malformed filters
    }
  }

  return {
    shopId,
    shopCipher: req.query?.shop_cipher || req.body?.shop_cipher,
  };
};

// Middleware to verify shop access for authenticated user
const verifyShopAccess = async (req, res, next) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: "Authentication required",
      });
    }

    const { shopId, shopCipher } = resolveShopIdentifier(req);

    if (!shopId && !shopCipher) {
      return res.status(400).json({
        success: false,
        message: "Shop ID required",
      });
    }

    // Resolve token record
    let shop = null;
    if (shopId) {
      shop = await Token.findByShopId(shopId);
    } else if (shopCipher) {
      const shopRecord = await Shop.findOne({
        where: { shop_cipher: shopCipher },
      });
      if (shopRecord) {
        shop = await Token.findByShopId(
          shopRecord.id,
          null,
          shopRecord.marketplace_platform,
        );
      }
    }

    if (!shop) {
      return res.status(404).json({
        success: false,
        message: "Shop not found or access denied",
      });
    }

    // Verify user-shop relation
    const relation = await UserShop.findOne({
      where: {
        user_id: userId,
        shop_id: shop.shop_id,
        status: "active",
      },
    });

    if (!relation) {
      return res.status(403).json({
        success: false,
        message: "Access denied to this shop",
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

// Rate limiting middleware (IP-based)
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

// Rate limiting middleware (auth_token or IP-based)
const createAuthRateLimit = (windowMs = 15 * 60 * 1000, max = 120) => {
  const rateLimit = require("express-rate-limit");

  return rateLimit({
    windowMs,
    max,
    keyGenerator: (req) => {
      const authToken = req.headers["auth_token"];
      const bearer = req.headers["authorization"]?.split(" ")[1];
      return authToken || bearer || req.ip;
    },
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
  attachUserShopIds: async (req, res, next) => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({
          success: false,
          message: "Authentication required",
        });
      }

      const shops = await UserShop.findAll({
        where: { user_id: userId, status: "active" },
        attributes: ["shop_id"],
      });

      req.allowedShopIds = shops.map((row) => row.shop_id);
      next();
    } catch (error) {
      console.error("Failed to resolve user shops:", error.message);
      return res.status(500).json({
        success: false,
        message: "Failed to resolve user shops",
      });
    }
  },
  verifyShopAccess,
  createRateLimit,
  createAuthRateLimit,
  securityHeaders,
};
