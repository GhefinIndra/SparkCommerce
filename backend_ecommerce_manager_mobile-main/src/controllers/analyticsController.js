// controllers/analyticsController.js - Multi-Platform Analytics
const axios = require('axios');
const Token = require('../models/Token');
const UserShop = require('../models/UserShop');

/**
 *  MULTI-PLATFORM ANALYTICS CONTROLLER
 *
 * Provides analytics data aggregated from all marketplaces
 *
 *  Currently Implemented:
 *    - TikTok Shop analytics (fully functional)
 *
 *  Shopee Implementation: COMING SOON
 *    - API endpoints prepared for Shopee integration
 *    - Add Shopee-specific data fetching when ready
 *    - Filter by platform: 'all' | 'tiktok' | 'shopee'
 *
 * Architecture:
 * - Platform-agnostic design
 * - Easy to extend for new marketplaces (Lazada, Tokopedia, etc.)
 * - Unified data format across platforms
 */

// ============================================
// 1. SALES ANALYTICS
// ============================================

/**
 * Get sales summary analytics
 * Multi-platform support: aggregates data from TikTok (and Shopee when implemented)
 *
 * Query params:
 * - platform: 'all' | 'tiktok' | 'shopee' (default: 'all')
 * - shopId: specific shop (optional, if not provided = all shops)
 * - startDate, endDate: date range
 * - compareWithPrevious: boolean for growth calculation
 */
exports.getSalesSummary = async (req, res) => {
  try {
    const { shopId } = req.params;
    const { startDate, endDate, compareWithPrevious = true, platform = 'all' } = req.query;

    console.log(' Getting sales summary - Platform:', platform, 'Shop:', shopId || 'ALL');

    // Calculate date ranges
    const currentStart = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const currentEnd = endDate ? new Date(endDate) : new Date();

    let allOrders = [];

    // Get shops based on filter
    let shopsToQuery = [];
    if (shopId) {
      // Single shop
      const tokenDoc = await Token.findOne({ shop_id: shopId });
      if (!tokenDoc) {
        return res.status(404).json({
          success: false,
          message: 'Shop not found or not authorized',
        });
      }
      shopsToQuery.push(tokenDoc);
    } else {
      // All shops (filter by platform)
      if (platform === 'all' || platform === 'tiktok') {
        const tiktokShops = await Token.find({});
        shopsToQuery.push(...tiktokShops);
      }

      //  TODO: Shopee Implementation
      // if (platform === 'all' || platform === 'shopee') {
      //   const shopeeShops = await ShopeeToken.find({});
      //   shopsToQuery.push(...shopeeShops);
      // }
    }

    // Get orders from all shops
    for (const shop of shopsToQuery) {
      try {
        const orders = await getOrdersInPeriod(shop.shop_id, shop.access_token, currentStart, currentEnd, shop.platform || 'tiktok');
        allOrders.push(...orders);
      } catch (error) {
        console.error(`Error fetching orders for shop ${shop.shop_id}:`, error.message);
      }
    }

    const currentOrders = allOrders;

    // Calculate metrics
    const totalRevenue = currentOrders.reduce((sum, order) => {
      const amount = parseFloat(order.payment?.total_amount || 0);
      return sum + amount;
    }, 0);

    const orderCount = currentOrders.length;
    const avgOrderValue = orderCount > 0 ? totalRevenue / orderCount : 0;

    // Calculate previous period if requested
    let growth = null;
    if (compareWithPrevious) {
      const periodDuration = currentEnd - currentStart;
      const previousStart = new Date(currentStart.getTime() - periodDuration);
      const previousEnd = new Date(currentStart.getTime());

      const previousOrders = await getOrdersInPeriod(shopId, tokenDoc.access_token, previousStart, previousEnd);
      const previousRevenue = previousOrders.reduce((sum, order) => {
        return sum + parseFloat(order.payment?.total_amount || 0);
      }, 0);

      const revenueGrowth = previousRevenue > 0
        ? ((totalRevenue - previousRevenue) / previousRevenue) * 100
        : 0;

      const orderGrowth = previousOrders.length > 0
        ? ((orderCount - previousOrders.length) / previousOrders.length) * 100
        : 0;

      growth = {
        revenue: parseFloat(revenueGrowth.toFixed(2)),
        orders: parseFloat(orderGrowth.toFixed(2)),
      };
    }

    res.json({
      success: true,
      data: {
        totalRevenue: parseFloat(totalRevenue.toFixed(2)),
        orderCount,
        avgOrderValue: parseFloat(avgOrderValue.toFixed(2)),
        growth,
        period: {
          start: currentStart.toISOString(),
          end: currentEnd.toISOString(),
        },
      },
    });

  } catch (error) {
    console.error(' Error getting sales summary:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Get revenue trend over time
 * Returns: daily revenue data for charts
 */
exports.getRevenueTrend = async (req, res) => {
  try {
    const { shopId } = req.params;
    const { startDate, endDate, groupBy = 'day' } = req.query;

    console.log(' Getting revenue trend for shop:', shopId);

    const tokenDoc = await Token.findOne({ shop_id: shopId });
    if (!tokenDoc) {
      return res.status(404).json({
        success: false,
        message: 'Shop not found',
      });
    }

    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    const orders = await getOrdersInPeriod(shopId, tokenDoc.access_token, start, end);

    // Group by day/week/month
    const groupedData = {};
    orders.forEach(order => {
      const date = new Date(order.create_time * 1000);
      let key;

      if (groupBy === 'day') {
        key = date.toISOString().split('T')[0]; // YYYY-MM-DD
      } else if (groupBy === 'week') {
        const weekStart = new Date(date);
        weekStart.setDate(date.getDate() - date.getDay());
        key = weekStart.toISOString().split('T')[0];
      } else if (groupBy === 'month') {
        key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      }

      if (!groupedData[key]) {
        groupedData[key] = { revenue: 0, orders: 0 };
      }

      groupedData[key].revenue += parseFloat(order.payment?.total_amount || 0);
      groupedData[key].orders += 1;
    });

    // Convert to array and sort by date
    const trendData = Object.keys(groupedData)
      .sort()
      .map(date => ({
        date,
        revenue: parseFloat(groupedData[date].revenue.toFixed(2)),
        orders: groupedData[date].orders,
      }));

    res.json({
      success: true,
      data: trendData,
    });

  } catch (error) {
    console.error(' Error getting revenue trend:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================
// 2. ORDER ANALYTICS
// ============================================

/**
 * Get order status breakdown
 * Returns: count per status for pie/donut chart
 */
exports.getOrderStatusBreakdown = async (req, res) => {
  try {
    const { shopId } = req.params;
    const { startDate, endDate } = req.query;

    console.log(' Getting order status breakdown for shop:', shopId);

    const tokenDoc = await Token.findOne({ shop_id: shopId });
    if (!tokenDoc) {
      return res.status(404).json({
        success: false,
        message: 'Shop not found',
      });
    }

    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    const orders = await getOrdersInPeriod(shopId, tokenDoc.access_token, start, end);

    // Count by status
    const statusCount = {};
    orders.forEach(order => {
      const status = order.status_name || order.order_status || 'UNKNOWN';
      statusCount[status] = (statusCount[status] || 0) + 1;
    });

    // Map to readable labels with colors
    const statusMapping = {
      'UNPAID': { label: 'Unpaid', color: '#FF9800' },
      'AWAITING_SHIPMENT': { label: 'Awaiting Shipment', color: '#2196F3' },
      'AWAITING_COLLECTION': { label: 'Ready to Ship', color: '#00BCD4' },
      'IN_TRANSIT': { label: 'In Transit', color: '#9C27B0' },
      'DELIVERED': { label: 'Delivered', color: '#4CAF50' },
      'CANCELLED': { label: 'Cancelled', color: '#F44336' },
      'COMPLETED': { label: 'Completed', color: '#00AA5B' },
    };

    const breakdown = Object.keys(statusCount).map(status => ({
      status,
      label: statusMapping[status]?.label || status,
      count: statusCount[status],
      color: statusMapping[status]?.color || '#757575',
      percentage: parseFloat(((statusCount[status] / orders.length) * 100).toFixed(2)),
    }));

    res.json({
      success: true,
      data: {
        total: orders.length,
        breakdown,
      },
    });

  } catch (error) {
    console.error(' Error getting order status breakdown:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================
// 3. PRODUCT ANALYTICS
// ============================================

/**
 * Get top selling products
 * Returns: top products by quantity or revenue
 */
exports.getTopProducts = async (req, res) => {
  try {
    const { shopId } = req.params;
    const { startDate, endDate, limit = 10, sortBy = 'quantity' } = req.query;

    console.log('️ Getting top products for shop:', shopId);

    const tokenDoc = await Token.findOne({ shop_id: shopId });
    if (!tokenDoc) {
      return res.status(404).json({
        success: false,
        message: 'Shop not found',
      });
    }

    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    const orders = await getOrdersInPeriod(shopId, tokenDoc.access_token, start, end);

    // Aggregate products
    const productStats = {};
    orders.forEach(order => {
      if (order.item_list) {
        order.item_list.forEach(item => {
          const productId = item.product_id;
          const productName = item.product_name || 'Unknown Product';
          const quantity = parseInt(item.quantity || 0);
          const revenue = parseFloat(item.sale_price || 0) * quantity;

          if (!productStats[productId]) {
            productStats[productId] = {
              productId,
              productName,
              imageUrl: item.image?.thumb_url_list?.[0] || '',
              totalQuantity: 0,
              totalRevenue: 0,
              orderCount: 0,
            };
          }

          productStats[productId].totalQuantity += quantity;
          productStats[productId].totalRevenue += revenue;
          productStats[productId].orderCount += 1;
        });
      }
    });

    // Convert to array and sort
    let topProducts = Object.values(productStats);

    if (sortBy === 'quantity') {
      topProducts.sort((a, b) => b.totalQuantity - a.totalQuantity);
    } else if (sortBy === 'revenue') {
      topProducts.sort((a, b) => b.totalRevenue - a.totalRevenue);
    }

    topProducts = topProducts.slice(0, parseInt(limit)).map((product, index) => ({
      rank: index + 1,
      ...product,
      totalRevenue: parseFloat(product.totalRevenue.toFixed(2)),
    }));

    res.json({
      success: true,
      data: topProducts,
    });

  } catch (error) {
    console.error(' Error getting top products:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================
// 4. SKU ANALYTICS
// ============================================

/**
 * Get SKU performance analytics
 * Returns: SKU stats from database
 */
exports.getSKUAnalytics = async (req, res) => {
  try {
    const db = req.app.locals.db;

    // Get all SKUs
    const skus = await new Promise((resolve, reject) => {
      db.all('SELECT * FROM skus', [], (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      });
    });

    // Get SKU mappings count
    const mappings = await new Promise((resolve, reject) => {
      db.all(`
        SELECT sku, COUNT(*) as marketplace_count
        FROM sku_product_mapping
        GROUP BY sku
      `, [], (err, rows) => {
        if (err) reject(err);
        else resolve(rows || []);
      });
    });

    const mappingMap = {};
    mappings.forEach(m => {
      mappingMap[m.sku] = m.marketplace_count;
    });

    // Calculate metrics
    const totalSKUs = skus.length;
    const linkedSKUs = mappings.length;
    const unlinkedSKUs = totalSKUs - linkedSKUs;

    const totalStockValue = skus.reduce((sum, sku) => {
      const stock = parseInt(sku.stock || 0);
      const price = parseFloat(sku.price || 0);
      return sum + (stock * price);
    }, 0);

    // Get low stock items (stock < 10)
    const lowStockItems = skus.filter(sku => parseInt(sku.stock || 0) < 10).length;

    // Top SKUs by stock value
    const topSKUsByValue = skus
      .map(sku => ({
        sku: sku.sku,
        name: sku.name,
        stock: parseInt(sku.stock || 0),
        price: parseFloat(sku.price || 0),
        stockValue: parseInt(sku.stock || 0) * parseFloat(sku.price || 0),
        marketplaceCount: mappingMap[sku.sku] || 0,
      }))
      .sort((a, b) => b.stockValue - a.stockValue)
      .slice(0, 10);

    res.json({
      success: true,
      data: {
        summary: {
          totalSKUs,
          linkedSKUs,
          unlinkedSKUs,
          totalStockValue: parseFloat(totalStockValue.toFixed(2)),
          lowStockItems,
        },
        topSKUs: topSKUsByValue.map((item, index) => ({
          rank: index + 1,
          ...item,
          stockValue: parseFloat(item.stockValue.toFixed(2)),
        })),
      },
    });

  } catch (error) {
    console.error(' Error getting SKU analytics:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================
// 5. SHOP COMPARISON ANALYTICS
// ============================================

/**
 * Get performance comparison across all shops
 * Returns: metrics for each shop
 */
exports.getShopComparison = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    console.log(' Getting shop comparison analytics');

    // Get all shops
    const tokens = await Token.find({});

    const start = startDate ? new Date(startDate) : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate ? new Date(endDate) : new Date();

    // Get metrics for each shop
    const shopMetrics = await Promise.all(
      tokens.map(async (tokenDoc) => {
        try {
          const orders = await getOrdersInPeriod(tokenDoc.shop_id, tokenDoc.access_token, start, end);

          const revenue = orders.reduce((sum, order) => {
            return sum + parseFloat(order.payment?.total_amount || 0);
          }, 0);

          const orderCount = orders.length;
          const avgOrderValue = orderCount > 0 ? revenue / orderCount : 0;

          return {
            shopId: tokenDoc.shop_id,
            shopName: tokenDoc.shop_name || tokenDoc.shop_id,
            platform: 'TikTok',
            revenue: parseFloat(revenue.toFixed(2)),
            orderCount,
            avgOrderValue: parseFloat(avgOrderValue.toFixed(2)),
          };
        } catch (error) {
          console.error(`Error getting metrics for shop ${tokenDoc.shop_id}:`, error.message);
          return {
            shopId: tokenDoc.shop_id,
            shopName: tokenDoc.shop_name || tokenDoc.shop_id,
            platform: 'TikTok',
            revenue: 0,
            orderCount: 0,
            avgOrderValue: 0,
            error: error.message,
          };
        }
      })
    );

    // Sort by revenue
    shopMetrics.sort((a, b) => b.revenue - a.revenue);

    // Add rankings
    const rankedShops = shopMetrics.map((shop, index) => ({
      rank: index + 1,
      ...shop,
    }));

    res.json({
      success: true,
      data: rankedShops,
    });

  } catch (error) {
    console.error(' Error getting shop comparison:', error);
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Get orders within a date period - Multi-platform support
 *
 * @param {string} shopId - Shop identifier
 * @param {string} accessToken - Access token for API
 * @param {Date} startDate - Start date
 * @param {Date} endDate - End date
 * @param {string} platform - 'tiktok' | 'shopee' (default: 'tiktok')
 * @returns {Array} Orders array
 */
async function getOrdersInPeriod(shopId, accessToken, startDate, endDate, platform = 'tiktok') {
  const startTime = Math.floor(startDate.getTime() / 1000);
  const endTime = Math.floor(endDate.getTime() / 1000);

  try {
    if (platform === 'tiktok') {
      //  TikTok implementation
      const response = await axios.get(
        'https://open-api.tiktokglobalshop.com/order/202309/orders/search',
        {
          params: {
            app_key: process.env.TIKTOK_APP_KEY,
            access_token: accessToken,
            shop_cipher: shopId,
            create_time_from: startTime,
            create_time_to: endTime,
            page_size: 50,
          },
          headers: {
            'Content-Type': 'application/json',
          },
        }
      );

      if (response.data?.data?.orders) {
        return response.data.data.orders;
      }
    }

    //  TODO: Shopee Implementation
    // else if (platform === 'shopee') {
    //   const response = await axios.post(
    //     'https://partner.shopeemobile.com/api/v2/order/get_order_list',
    //     {
    //       partner_id: parseInt(process.env.SHOPEE_PARTNER_ID),
    //       shop_id: parseInt(shopId),
    //       access_token: accessToken,
    //       time_range_field: 'create_time',
    //       time_from: startTime,
    //       time_to: endTime,
    //       page_size: 50,
    //     }
    //   );
    //
    //   if (response.data?.response?.order_list) {
    //     return response.data.response.order_list;
    //   }
    // }

    return [];
  } catch (error) {
    console.error(`Error fetching ${platform} orders for shop ${shopId}:`, error.message);
    return [];
  }
}

/**
 * Normalize order data across platforms
 * Converts platform-specific order format to unified format
 *
 *  TODO: Add Shopee order normalization
 */
function normalizeOrderData(order, platform = 'tiktok') {
  if (platform === 'tiktok') {
    return order; // TikTok format is already our base format
  }

  //  TODO: Shopee normalization
  // if (platform === 'shopee') {
  //   return {
  //     order_id: order.order_sn,
  //     create_time: order.create_time,
  //     payment: {
  //       total_amount: order.total_amount,
  //     },
  //     status_name: order.order_status,
  //     item_list: order.item_list,
  //     // ... map other fields
  //   };
  // }

  return order;
}
