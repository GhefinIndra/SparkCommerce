const Token = require("../../models/Token");
const User = require("../../models/User");
const UserShop = require("../../models/UserShop");
const { generateTikTokSignature } = require("../../utils/tiktokSignature");
const config = require("../../config/env");
const { Op } = require("sequelize"); // Tambahkan ini di bagian import

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

// Helper function to get user from auth token - FIXED
async function getUserFromAuthToken(authToken) {
  if (!authToken || authToken === "none" || authToken === "null") {
    console.log(" No valid auth token provided:", authToken);
    return null;
  }

  try {
    const user = await User.findByAuthToken(authToken);
    if (!user) {
      console.log(" User not found for token:", authToken);
    } else {
      console.log(" User found:", user.email);
    }
    return user;
  } catch (error) {
    console.error(" Error getting user from token:", error.message);
    return null;
  }
}

// Function untuk mengambil shop info
async function fetchShopInfoWithSignature(accessToken, openId) {
  try {
    console.log(" Fetching shop info with signature...");

    const appKey = config.tiktok.appKey;
    const appSecret = config.tiktok.appSecret;

    const timestamp = Math.floor(Date.now() / 1000);
    const path = "/authorization/202309/shops";

    const queryParams = {
      app_key: appKey,
      timestamp: timestamp.toString(),
    };

    const signature = generateTikTokSignature(path, queryParams, "", appSecret);
    queryParams.sign = signature;

    const queryString = new URLSearchParams(queryParams).toString();
    const url = `https://open-api.tiktokglobalshop.com${path}?${queryString}`;

    console.log(" Calling TikTok Authorization API:", path);

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "x-tts-access-token": accessToken,
        "User-Agent": "TikTokShop-OAuth/1.0",
      },
    });

    const shopData = await response.json();
    console.log(" Shop API Response Code:", shopData.code);

    if (shopData.code === 0 && shopData.data && shopData.data.shops) {
      const shops = shopData.data.shops;
      console.log(" Found shops:", shops.length);

      if (shops.length > 0) {
        const firstShop = shops[0];

        const updateData = {
          shop_id: firstShop.id,
          shop_code: firstShop.code,
          shop_name: firstShop.name,
          shop_cipher: firstShop.cipher,
          shop_region: firstShop.region,
          seller_type: firstShop.seller_type,
          seller_id: firstShop.id,
          status: "active",
          updated_at: new Date(),
        };

        const updatedToken = await Token.update(updateData, {
          where: { open_id: openId },
          returning: true,
        });

        console.log(" Shop info updated successfully");
        return updatedToken;
      }
    } else {
      console.error(
        " Failed to get shop info:",
        shopData.message || "Unknown error",
      );
    }
  } catch (error) {
    console.error(" Error in fetchShopInfoWithSignature:", error.message);
  }
}

// OAuth Authorization
exports.authorize = (req, res) => {
  try {
    // Get user auth token from query params
    const { user_token } = req.query;

    let authUrl =
      `https://auth.tiktok-shops.com/oauth/authorize?` +
      `app_key=${config.tiktok.appKey}&` +
      `state=${user_token || "no_user"}&` +
      `redirect_uri=${encodeURIComponent(config.tiktok.redirectUri)}`;

    console.log(" Redirecting to TikTok OAuth...");
    res.redirect(authUrl);
  } catch (error) {
    console.error("Error in authorize:", error);
    res.status(500).json({ success: false, message: "Authorization error" });
  }
};

// OAuth Callback - FIXED
exports.callback = async (req, res) => {
  console.log(" TikTok CALLBACK ROUTE HIT!");
  const { code, state, error } = req.query;

  if (error) {
    return res.redirect(
      `${config.server.clientUrl}/error?message=${encodeURIComponent(error)}`,
    );
  }

  if (!code) {
    return res.redirect(`${config.server.clientUrl}/error?message=no_code`);
  }

  try {
    console.log(" Exchanging code for token...");

    const params = {
      app_key: config.tiktok.appKey,
      app_secret: config.tiktok.appSecret,
      auth_code: code,
      grant_type: "authorized_code",
    };

    const queryString = new URLSearchParams(params).toString();
    const tokenUrl = `https://auth.tiktok-shops.com/api/v2/token/get?${queryString}`;

    const response = await fetch(tokenUrl, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "User-Agent": "TikTokShop-OAuth/1.0",
      },
    });

    const data = await response.json();
    console.log(" Token API Response Code:", data.code);

    if (data.code === 0 && data.data && data.data.access_token) {
      const responseData = data.data;

      // Simpan token ke database dengan Sequelize
      const savedToken = await Token.upsert({
        platform: "tiktok",
        open_id: responseData.open_id,
        access_token: responseData.access_token,
        refresh_token: responseData.refresh_token,
        seller_name: responseData.seller_name,
        region: responseData.seller_base_region,
        user_type: responseData.user_type,
        granted_scopes: responseData.granted_scopes,
        status: "pending",
        expire_at: new Date(responseData.access_token_expire_in * 1000),
        user_id: null,
      });

      console.log(" Token saved successfully");

      // Ambil shop information
      await fetchShopInfoWithSignature(
        responseData.access_token,
        responseData.open_id,
      );

      if (state && state !== "no_user") {
        console.log(" Looking for user with token:", state);
        const user = await getUserFromAuthToken(state);

        if (user) {
          // Get the updated token with shop info
          const tokenWithShop = await Token.findByOpenId(responseData.open_id);

          if (tokenWithShop && tokenWithShop.shop_id) {
            try {
              // Check if relation already exists (for multiple auth attempts)
              const existingRelation = await UserShop.findOne({
                where: {
                  user_id: user.id,
                  shop_id: tokenWithShop.shop_id,
                },
              });

              if (existingRelation) {
                console.log(
                  " User-shop relation already exists, updating...",
                );
                await existingRelation.update({
                  status: "active",
                  updated_at: new Date(),
                });
              } else {
                console.log(" Creating new user-shop relation...");
                await UserShop.createRelation(
                  user.id,
                  tokenWithShop.shop_id,
                  "owner",
                );
              }

              console.log(" Shop connected to user:", user.email);
            } catch (relationError) {
              console.error(
                "️ Failed to create user-shop relation:",
                relationError.message,
              );
            }
          } else {
            console.error("️ No shop_id found in token after fetch");
          }
        } else {
          console.error("️ User not found for state token:", state);
        }
      } else {
        console.log(
          "️ No user token provided in state, shop will be orphaned",
        );
      }

      const successUrl = `${config.server.clientUrl}/success?openId=${responseData.open_id}&seller=${encodeURIComponent(responseData.seller_name)}`;
      res.redirect(successUrl);
    } else {
      throw new Error(`TikTok API Error: ${data.message || "Unknown error"}`);
    }
  } catch (error) {
    console.error(" OAuth Callback Error:", error.message);
    res.redirect(
      `${config.server.clientUrl}/error?message=${encodeURIComponent(error.message)}`,
    );
  }
};

//  NEW: Get available shops (unclaimed)
// Update method ini di authController.js
exports.getAvailableShops = async (req, res) => {
  try {
    console.log(" Getting available shops...");

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    if (!authToken || authToken === "none" || authToken === "null") {
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    const user = await getUserFromAuthToken(authToken);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    // Get ALL available shops (tidak filter unclaimed)
    const availableShops = await Token.findAll({
      where: {
        status: "active",
        shop_id: { [Op.ne]: null },
      },
      order: [["updated_at", "DESC"]],
    });

    // Filter shops yang BELUM di-claim oleh user ini
    const userShops = await UserShop.findUserShops(user.id);
    const userShopIds = userShops.map((us) => us.shop_id);

    const unclaimedByUser = availableShops.filter(
      (shop) => !userShopIds.includes(shop.shop_id),
    );

    const shopList = unclaimedByUser.map((shop) => ({
      id: shop.shop_id,
      name: shop.shop_name || "Unknown Shop",
      platform: "TikTok Shop",
      seller_name: shop.seller_name || "",
      region: shop.shop_region || "",
      status: shop.status,
      lastSync: shop.updated_at ? formatDate(shop.updated_at) : "Baru saja",
      open_id: shop.open_id,
    }));

    console.log(
      ` Returning ${shopList.length} available shops for user ${user.email}`,
    );
    res.json({
      success: true,
      data: shopList,
      message:
        shopList.length === 0
          ? "No unclaimed shops available for you"
          : `Found ${shopList.length} available shops`,
    });
  } catch (error) {
    console.error(" Error fetching available shops:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

//  NEW: Claim shop
exports.claimShop = async (req, res) => {
  try {
    const { shopId } = req.params;
    console.log(` User attempting to claim shop: ${shopId}`);

    // Check auth token
    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

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

    // Check if shop exists in tokens
    const shop = await Token.findByShopId(shopId);
    if (!shop) {
      return res.status(404).json({
        success: false,
        message: "Shop not found",
      });
    }

    // Check if user already has access to this shop
    const existingRelation = await UserShop.findOne({
      where: {
        user_id: user.id,
        shop_id: shopId,
      },
    });

    if (existingRelation) {
      if (existingRelation.status === "active") {
        return res.status(400).json({
          success: false,
          message: "You already have access to this shop",
        });
      } else {
        // Reactivate existing relation
        await existingRelation.update({
          status: "active",
          updated_at: new Date(),
        });

        console.log(
          ` Reactivated shop access for user ${user.email}: ${shop.shop_name}`,
        );
        return res.json({
          success: true,
          message: "Shop access reactivated successfully",
          data: {
            shop_id: shopId,
            shop_name: shop.shop_name,
            role: existingRelation.role,
          },
        });
      }
    }

    // Create new relation
    const newRelation = await UserShop.createRelation(user.id, shopId, "owner");

    console.log(
      ` Shop claimed successfully by user ${user.email}: ${shop.shop_name}`,
    );
    res.json({
      success: true,
      message: "Shop claimed successfully",
      data: {
        shop_id: shopId,
        shop_name: shop.shop_name,
        role: newRelation.role,
        claimed_at: newRelation.created_at,
      },
    });
  } catch (error) {
    console.error(" Error claiming shop:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// Get all shops for mobile app - FIXED
exports.getShops = async (req, res) => {
  try {
    console.log(" Getting shops for mobile app...");

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    console.log(" Auth token from headers:", authToken);

    if (!authToken || authToken === "none" || authToken === "null") {
      console.log(" No valid auth token provided");
      return res.status(401).json({
        success: false,
        message: "Auth token required",
      });
    }

    // Get user from auth token
    const user = await getUserFromAuthToken(authToken);
    if (!user) {
      console.log(" Invalid or expired token:", authToken);
      return res.status(401).json({
        success: false,
        message: "Invalid or expired token",
      });
    }

    console.log(" User authenticated:", user.email);

    // Since UserShop doesn't have platform field, we query Token table with platform filter
    // and then check if user has access to these shops via UserShop

    // First, get all TikTok tokens
    const tiktokTokens = await Token.findAll({
      where: {
        platform: "tiktok",
        status: "active",
      },
      order: [["updated_at", "DESC"]],
    });

    console.log(" Found active TikTok tokens:", tiktokTokens.length);

    if (tiktokTokens.length === 0) {
      console.log(" No TikTok shops found in system");
      return res.json({
        success: true,
        data: [],
        message: "No TikTok shops available",
      });
    }

    // Get user's shop relations
    const userShops = await UserShop.findUserShops(user.id);
    const userShopIds = userShops.map((us) => us.shop_id);
    console.log(" User has access to shop IDs:", userShopIds);

    // Filter TikTok tokens to only include shops the user has access to
    const userTikTokTokens = tiktokTokens.filter((token) =>
      userShopIds.includes(token.shop_id)
    );

    console.log(` User has access to ${userTikTokTokens.length} TikTok shops`);

    const shopList = userTikTokTokens.map((shop) => ({
      id: shop.shop_id || "",
      name: shop.shop_name || "Unknown Shop",
      platform: "TikTok Shop",
      lastSync: shop.updated_at ? formatDate(shop.updated_at) : "Baru saja",
      seller_name: shop.seller_name || "",
      region: shop.shop_region || "",
      status: shop.status,
    }));

    console.log(` Returning ${shopList.length} TikTok shops for user:`, user.email);
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
    console.error(" Error fetching shops:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};

// Get specific shop info - FIXED
exports.getShopInfo = async (req, res) => {
  try {
    const { shopId } = req.params;

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    console.log(` Getting shop info for ID: ${shopId}`);
    console.log(" Auth token:", authToken);

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
      console.log(` User ${user.email} has no access to shop ${shopId}`);
      return res.status(403).json({
        success: false,
        message: "Access denied to this shop",
      });
    }

    const shop = await Token.findByShopId(shopId);

    if (!shop) {
      return res.status(404).json({
        success: false,
        message: "Shop not found",
      });
    }

    const shopData = {
      id: shop.shop_id,
      name: shop.shop_name,
      platform: "TikTok Shop",
      lastSync: shop.updated_at ? formatDate(shop.updated_at) : "Baru saja",
      seller_name: shop.seller_name,
      region: shop.shop_region,
      status: shop.status,
      role: userShop.role, // Include user's role for this shop
    };

    console.log(
      ` Returning shop info for user ${user.email}:`,
      shopData.name,
    );
    res.json({ success: true, data: shopData });
  } catch (error) {
    console.error(" Error fetching shop info:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
      error: process.env.NODE_ENV === "development" ? error.message : undefined,
    });
  }
};
