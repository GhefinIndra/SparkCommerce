// src/controllers/shopee/authController.js
const Token = require("../../models/Token");
const User = require("../../models/User");
const UserShop = require("../../models/UserShop");
const { buildShopeeParams, buildShopeeUrl } = require("../../utils/shopeeSignature");
const config = require("../../config/env");
const { Op } = require("sequelize");
const ShopService = require("../../services/shopee/ShopService");

// Helper function untuk format date
function formatDate(date) {
  const now = new Date();
  const diff = now - new Date(date);
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const days = Math.floor(hours / 24);

  if (hours < 1) return "Baru saja";
  if (hours < 24) return `${hours} jam lalu`;
  if (days < 7) return `${days} hari lalu`;
  return new Date(date).toLocaleDateString("id-ID");
}

// Helper function to get user from auth token
async function getUserFromAuthToken(authToken) {
  if (!authToken || authToken === "none" || authToken === "null") {
    console.log("No valid auth token provided:", authToken);
    return null;
  }

  try {
    const user = await User.findByAuthToken(authToken);
    if (!user) {
      console.log("User not found for token:", authToken);
    } else {
      console.log("User found:", user.email);
    }
    return user;
  } catch (error) {
    console.error("Error getting user from token:", error.message);
    return null;
  }
}

/**
 * Shopee OAuth Authorization
 * Redirect user to Shopee authorization page
 */
exports.authorize = (req, res) => {
  try {
    const { user_token } = req.query;
    const { partnerId, partnerKey, redirectUri, apiUrl } = config.shopee;

    console.log(" Shopee Authorization Request Received!");
    console.log("   API URL:", apiUrl);
    console.log("   Partner ID:", partnerId);
    console.log("   Redirect URI:", redirectUri);
    console.log("   User Token:", user_token || "no_user");

    // WORKAROUND: Shopee doesn't support state parameter, so encode user_token in redirect URI
    const modifiedRedirectUri = user_token
      ? `${redirectUri}?user_token=${encodeURIComponent(user_token)}`
      : redirectUri;

    console.log("   Modified Redirect URI:", modifiedRedirectUri);

    // Generate timestamp and signature for authorization request
    const apiPath = '/api/v2/shop/auth_partner';
    const params = buildShopeeParams(partnerId, apiPath, partnerKey);

    console.log("   Timestamp:", params.timestamp);
    console.log("   Signature (full):", params.sign);

    // Build authorization URL with signature
    const authUrl = buildShopeeUrl(apiUrl, apiPath, {
      ...params,
      redirect: modifiedRedirectUri,
    });

    console.log(" Redirecting to (FULL URL):");
    console.log(authUrl);

    res.redirect(authUrl);
  } catch (error) {
    console.error(" Error in authorize:", error);
    res.status(500).json({ success: false, message: "Authorization error" });
  }
};

/**
 * Shopee OAuth Callback
 * Handle callback from Shopee after authorization
 */
exports.callback = async (req, res) => {
  console.log("Shopee CALLBACK ROUTE HIT!");
  const { code, shop_id, user_token } = req.query;

  console.log("Callback params:", { code: code ? "received" : "missing", shop_id, user_token });

  if (!code || !shop_id) {
    console.error("Missing code or shop_id in callback");
    return res.redirect(
      `${config.server.clientUrl}/error?message=missing_code_or_shop_id`
    );
  }

  try {
    const { partnerId, partnerKey, apiUrl } = config.shopee;
    const apiPath = "/api/v2/auth/token/get";

    console.log("Exchanging code for access token...");

    // Build signature for token request (Public API)
    const params = buildShopeeParams(partnerId, apiPath, partnerKey);
    const url = buildShopeeUrl(apiUrl, apiPath, params);

    // Request body
    const requestBody = {
      code,
      shop_id: parseInt(shop_id),
      partner_id: parseInt(partnerId),
    };

    console.log("Calling Shopee Token API:", apiPath);
    console.log("   URL:", url.substring(0, 100) + "...");

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Shopee-OAuth/1.0",
      },
      body: JSON.stringify(requestBody),
    });

    const data = await response.json();
    console.log("Token API Response:", {
      hasError: !!data.error,
      hasAccessToken: !!data.access_token,
      hasRefreshToken: !!data.refresh_token,
      expireIn: data.expire_in,
    });

    if (data.error || !data.access_token) {
      throw new Error(`Shopee API Error: ${data.message || data.error || "Unknown error"}`);
    }

    // Fetch shop info from Shopee API
    console.log("Fetching shop information from Shopee...");
    const shopInfo = await ShopService.getShopInfo(shop_id, data.access_token);

    // Save token to database with shop info
    const tokenData = {
      platform: "shopee",
      open_id: `shopee_${shop_id}`,
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      shop_id: shop_id.toString(),
      shop_name: shopInfo.shop_name,
      shop_region: shopInfo.region,
      status: "active",
      expire_at: new Date(Date.now() + data.expire_in * 1000),
      user_id: null,
    };

    console.log("   Saving token to database...");
    console.log("   Shop Name:", shopInfo.shop_name);
    console.log("   Region:", shopInfo.region);
    console.log("   Status:", shopInfo.status);

    const savedToken = await Token.upsert(tokenData);
    console.log("Token and shop info saved successfully");

    console.log("Linking shop to most recent active user...");

    try {
      // Get the most recently active user (by token expiry)
      const recentUser = await User.findOne({
        where: {
          status: "active",
          token_expires_at: {
            [Op.gt]: new Date(),
          },
        },
        order: [["token_expires_at", "DESC"]],
      });

      if (recentUser) {
        // Check if relation already exists
        const existingRelation = await UserShop.findOne({
          where: {
            user_id: recentUser.id,
            shop_id: shop_id.toString(),
          },
        });

        if (existingRelation) {
          console.log("User-shop relation already exists, updating...");
          await existingRelation.update({
            status: "active",
            updated_at: new Date(),
          });
        } else {
          console.log("Creating new user-shop relation...");
          await UserShop.createRelation(recentUser.id, shop_id.toString(), "owner");
        }

        console.log("Shopee shop connected to user:", recentUser.email);
      } else {
        console.log("No active user found, shop will be orphaned (can be claimed later)");
      }
    } catch (relationError) {
      console.error("Failed to create user-shop relation:", relationError.message);
    }

    res.redirect(
      `${config.server.clientUrl}/success?platform=shopee&shopId=${shop_id}`
    );
  } catch (error) {
    console.error("Shopee OAuth Callback Error:", error.message);
    res.redirect(
      `${config.server.clientUrl}/error?message=${encodeURIComponent(error.message)}`
    );
  }
};

/**
 * Get all Shopee shops for authenticated user
 */
exports.getShops = async (req, res) => {
  try {
    console.log("Getting Shopee shops for mobile app...");

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    console.log("Auth token from headers:", authToken);

    if (!authToken || authToken === "none" || authToken === "null") {
      console.log("No valid auth token provided");
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    // Get user from auth token
    const user = await getUserFromAuthToken(authToken);
    if (!user) {
      console.log("Invalid or expired token:", authToken);
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    console.log("User authenticated:", user.email);

    // Since UserShop doesn't have platform field, we query Token table with platform filter
    // and then check if user has access to these shops via UserShop

    // First, get all Shopee tokens
    const shopeeTokens = await Token.findAll({
      where: {
        platform: "shopee",
        status: "active",
      },
      order: [["updated_at", "DESC"]],
    });

    console.log("Found active Shopee tokens:", shopeeTokens.length);

    if (shopeeTokens.length === 0) {
      console.log("No Shopee shops found in system");
      return res.json({
        success: true,
        data: [],
        message: "No Shopee shops available",
      });
    }

    // Get user's shop relations
    const userShops = await UserShop.findUserShops(user.id);
    const userShopIds = userShops.map((us) => us.shop_id);
    console.log("User has access to shop IDs:", userShopIds);

    // Filter Shopee tokens to only include shops the user has access to
    const userShopeeTokens = shopeeTokens.filter((token) =>
      userShopIds.includes(token.shop_id)
    );

    console.log(`User has access to ${userShopeeTokens.length} Shopee shops`);

    const shopList = userShopeeTokens.map((shop) => ({
      id: shop.shop_id || "",
      name: shop.shop_name || "Unknown Shopee Shop",
      platform: "Shopee",
      lastSync: shop.updated_at ? formatDate(shop.updated_at) : "Baru saja",
      seller_name: shop.shop_name || "Unknown Seller",
      region: shop.shop_region || "",
      status: shop.status,
    }));

    console.log(`Returning ${shopList.length} Shopee shops for user:`, user.email);
    res.json({
      success: true,
      data: shopList,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    console.error("Error fetching Shopee shops:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

/**
 * Get specific Shopee shop info
 */
exports.getShopInfo = async (req, res) => {
  try {
    const { shopId } = req.params;

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    console.log(`Getting Shopee shop info for ID: ${shopId}`);

    if (!authToken || authToken === "none" || authToken === "null") {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    // Get user from auth token
    const user = await getUserFromAuthToken(authToken);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    // Check if user has access to this shop
    const userShop = await UserShop.findOne({
      where: {
        user_id: user.id,
        shop_id: shopId,
        status: "active",
      },
    });

    if (!userShop) {
      console.log(`User ${user.email} has no access to Shopee shop ${shopId}`);
      return res.status(403).json({
        success: false,
        message: "Access denied to this shop",
      });
    }

    const shop = await Token.findOne({
      where: {
        shop_id: shopId,
        platform: "shopee",
      },
    });

    if (!shop) {
      return res.status(404).json({
        success: false,
        message: "Shop not found",
      });
    }

    const shopData = {
      id: shop.shop_id,
      name: shop.shop_name,
      platform: "Shopee",
      lastSync: shop.updated_at ? formatDate(shop.updated_at) : "Baru saja",
      region: shop.shop_region,
      status: shop.status,
      role: userShop.role,
    };

    console.log(`Returning Shopee shop info for user ${user.email}:`, shopData.name);
    res.json({ success: true, data: shopData });
  } catch (error) {
    console.error("Error fetching Shopee shop info:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

/**
 * Refresh Shopee access token
 */
exports.refreshAccessToken = async (req, res) => {
  try {
    const { shop_id } = req.body;

    if (!shop_id) {
      return res.status(400).json({
        success: false,
        message: "shop_id is required",
      });
    }

    console.log(`Refreshing access token for Shopee shop: ${shop_id}`);

    // Get current token from database
    const tokenRecord = await Token.findOne({
      where: {
        shop_id: shop_id.toString(),
        platform: "shopee",
      },
    });

    if (!tokenRecord || !tokenRecord.refresh_token) {
      return res.status(404).json({
        success: false,
        message: "Token not found or refresh token missing",
      });
    }

    const { partnerId, partnerKey, apiUrl } = config.shopee;
    const apiPath = "/api/v2/auth/access_token/get";

    // Build signature (Public API)
    const params = buildShopeeParams(partnerId, apiPath, partnerKey);
    const url = buildShopeeUrl(apiUrl, apiPath, params);

    // Request body
    const requestBody = {
      refresh_token: tokenRecord.refresh_token,
      partner_id: parseInt(partnerId),
      shop_id: parseInt(shop_id),
    };

    console.log("Calling Shopee Refresh Token API");

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Shopee-OAuth/1.0",
      },
      body: JSON.stringify(requestBody),
    });

    const data = await response.json();

    if (data.error || !data.access_token) {
      throw new Error(`Shopee API Error: ${data.message || data.error}`);
    }

    // Update token in database
    await tokenRecord.update({
      access_token: data.access_token,
      refresh_token: data.refresh_token,
      expire_at: new Date(Date.now() + data.expire_in * 1000),
      updated_at: new Date(),
    });

    console.log("Access token refreshed successfully");

    res.json({
      success: true,
      message: "Access token refreshed successfully",
      data: {
        expire_in: data.expire_in,
      },
    });
  } catch (error) {
    console.error("Error refreshing access token:", error);
    res.status(500).json({
      success: false,
      message: "Failed to refresh access token",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

module.exports = exports;
