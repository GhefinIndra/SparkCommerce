const Token = require("../models/Token");
const User = require("../models/User");
const UserShop = require("../models/UserShop");
const shopeeOrderService = require("../services/shopee/orderService");
const tiktokOrderService = require("../services/tiktok/orderService");
const { Op } = require("sequelize");

// Helper: Get user from auth token
async function getUserFromAuthToken(authToken) {
  if (!authToken || authToken === "none" || authToken === "null") return null;
  try {
    return await User.findByAuthToken(authToken);
  } catch (error) {
    console.error("Error getting user from token:", error.message);
    return null;
  }
}

/**
 * Get Aggregated Dashboard Stats
 * Returns total shops, total orders (last 30 days), and other key metrics.
 */
exports.getDashboardStats = async (req, res) => {
  try {
    console.log("📊 Getting aggregated dashboard stats...");

    const authToken =
      req.headers.auth_token ||
      req.headers["auth-token"] ||
      req.headers.authorization?.replace("Bearer ", "");

    if (!authToken) {
      return res.status(401).json({ success: false, message: "Auth token required" });
    }

    const user = await getUserFromAuthToken(authToken);
    if (!user) {
      return res.status(401).json({ success: false, message: "Invalid token" });
    }

    // 1. Get all shops user has access to
    const userShops = await UserShop.findUserShops(user.id);
    const userShopIds = userShops.map((us) => us.shop_id);

    if (userShopIds.length === 0) {
      return res.json({
        success: true,
        data: { totalShops: 0, totalOrders: 0, totalSKUs: 0 },
      });
    }

    // 2. Get tokens for these shops to identify platform and credentials
    const tokens = await Token.findAll({
      where: {
        shop_id: { [Op.in]: userShopIds },
        status: "active",
      },
    });

    // 3. Aggregate Data in Parallel
    let totalOrders = 0;
    const shopCount = tokens.length;

    // Calculate time range (Last 30 days)
    const now = Math.floor(Date.now() / 1000);
    const thirtyDaysAgo = now - 30 * 24 * 60 * 60;

    const statsPromises = tokens.map(async (token) => {
      try {
        if (token.platform === "shopee") {
          const marketplaceShopId = token.marketplace_shop_id || token.shop_id;
          // Fetch Shopee Orders
          const result = await shopeeOrderService.getOrderList(marketplaceShopId, {
            time_range_field: "create_time",
            time_from: thirtyDaysAgo,
            time_to: now,
            page_size: 100, // Fetch up to 100 recent orders
          });
          
          return (result.response && result.response.order_list) ? result.response.order_list.length : 0;

        } else if (token.platform === "tiktok") {
          // Fetch TikTok Orders
          const result = await tiktokOrderService.getOrderList(
            token.access_token,
            token.shop_cipher, 
            {
              create_time_ge: thirtyDaysAgo,
              page_size: 1, // We only need total_count
            }
          );
          return (result.data && result.data.total_count) ? result.data.total_count : 0;
        }
      } catch (e) {
        console.error(`Failed to fetch stats for shop ${token.shop_id} (${token.platform}):`, e.message);
        // Don't throw, just return 0 so other shops can still load
        return 0;
      }
      return 0;
    });

    const orderCounts = await Promise.all(statsPromises);
    totalOrders = orderCounts.reduce((a, b) => a + b, 0);

    console.log(`✅ Dashboard stats for ${user.email}: ${shopCount} shops, ${totalOrders} orders`);

    res.json({
      success: true,
      data: {
        totalShops: shopCount,
        totalOrders: totalOrders,
        totalSKUs: 0, // Placeholder
      },
    });

  } catch (error) {
    console.error("Error generating dashboard stats:", error);
    res.status(500).json({ success: false, message: "Internal Server Error" });
  }
};
