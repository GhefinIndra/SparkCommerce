const OrderService = require("../../services/tiktok/orderService");
const Token = require("../../models/Token");
const Shop = require("../../models/Shop");
const Group = require('../../models/Group');
const axios = require('axios');
const { Op } = require("sequelize"); 

const getPublicShopId = (token, fallback = null) =>
  token?.marketplace_shop_id || token?.shop_id || fallback;

class OrderController {
  // Transform methods remain the same...
  transformOrderData(tikTokResponse) {
    console.log(" Transform Debug - Raw Response Structure:", {
      hasResponse: !!tikTokResponse,
      responseType: typeof tikTokResponse,
      hasData: !!tikTokResponse?.data,
      dataType: typeof tikTokResponse?.data,
      dataKeys: tikTokResponse?.data ? Object.keys(tikTokResponse.data) : null,
      hasOrders: !!tikTokResponse?.data?.orders,
      ordersType: typeof tikTokResponse?.data?.orders,
      ordersLength: tikTokResponse?.data?.orders?.length || 0,
    });

    //  DEBUG: Log full response structure for package information
    if (tikTokResponse?.data?.orders?.[0]) {
      const sampleOrder = tikTokResponse.data.orders[0];
      console.log(" Sample Order Keys:", Object.keys(sampleOrder));
      console.log(" Package Fields Check:", {
        hasPackages: !!sampleOrder.packages,
        packagesType: typeof sampleOrder.packages,
        packagesLength: Array.isArray(sampleOrder.packages)
          ? sampleOrder.packages.length
          : "not array",
        hasPackageIds: !!sampleOrder.package_ids,
        packageIdsType: typeof sampleOrder.package_ids,
        hasPackageId: !!sampleOrder.package_id,
        packageId: sampleOrder.package_id,
        hasFulfillmentInfo: !!sampleOrder.fulfillment_details,
        fulfillmentKeys: sampleOrder.fulfillment_details
          ? Object.keys(sampleOrder.fulfillment_details)
          : null,
      });

      // Log other potential package-related fields
      const packageRelatedFields = Object.keys(sampleOrder).filter(
        (key) =>
          key.toLowerCase().includes("package") ||
          key.toLowerCase().includes("fulfill") ||
          key.toLowerCase().includes("ship"),
      );
      console.log(" Found Package-related fields:", packageRelatedFields);
    }

    if (!tikTokResponse || !tikTokResponse.data) {
      console.log("️ Transform: No valid tikTokResponse or data");
      return {
        orders: [],
        pagination: {
          total_count: 0,
          has_next_page: false,
          next_page_token: null,
        },
      };
    }

    let ordersArray = null;
    if (tikTokResponse.data.orders) {
      ordersArray = tikTokResponse.data.orders;
    } else if (tikTokResponse.data.order_list) {
      ordersArray = tikTokResponse.data.order_list;
    } else if (Array.isArray(tikTokResponse.data)) {
      ordersArray = tikTokResponse.data;
    }

    if (!ordersArray || !Array.isArray(ordersArray)) {
      console.log(
        "️ Transform: No orders array found. Available keys:",
        Object.keys(tikTokResponse.data),
      );
      return {
        orders: [],
        pagination: {
          total_count: tikTokResponse.data.total_count || 0,
          has_next_page: !!tikTokResponse.data.next_page_token,
          next_page_token: tikTokResponse.data.next_page_token || null,
        },
      };
    }

    console.log(
      ` Transform: Found ${ordersArray.length} orders to transform`,
    );

    const transformedOrders = ordersArray.map((order, index) => {
      //  EXTRACT PACKAGE INFORMATION
      const packageInfo = this.extractPackageInfo(order);

      console.log(` Order ${index + 1} Package Info:`, {
        orderId: order.id,
        packageId: packageInfo.packageId,
        packageStatus: packageInfo.packageStatus,
        hasPackages: packageInfo.hasPackages,
        packagesCount: packageInfo.packagesCount,
      });

      const transformedOrder = {
        id: order.id || order.order_id,
        orderId: order.id || order.order_id,
        orderNumber: order.id || order.order_id,
        status: this.translateOrderStatus(order.status),
        statusCode: order.status,
        orderStatusName: this.translateOrderStatus(order.status),

        customerName:
          order.recipient_address?.name || order.buyer_name || "N/A",
        buyerName: order.recipient_address?.name || order.buyer_name || "N/A",
        customerPhone: order.recipient_address?.phone_number || "N/A",
        customerAddress: order.recipient_address?.full_address || "N/A",

        totalAmount:
          this.parseAmount(order.payment?.total_amount) ||
          this.parseAmount(order.total_amount) ||
          0,
        subTotal:
          this.parseAmount(order.payment?.sub_total) ||
          this.parseAmount(order.sub_total) ||
          0,
        shippingFee:
          this.parseAmount(order.payment?.shipping_fee) ||
          this.parseAmount(order.shipping_fee) ||
          0,
        currency: order.payment?.currency || order.currency || "IDR",

        formattedAmount: this.formatCurrency(
          this.parseAmount(order.payment?.total_amount) ||
            this.parseAmount(order.total_amount) ||
            0,
        ),

        orderDate: order.create_time
          ? new Date(order.create_time * 1000).toISOString()
          : null,
        paidDate: order.paid_time
          ? new Date(order.paid_time * 1000).toISOString()
          : null,
        updateDate: order.update_time
          ? new Date(order.update_time * 1000).toISOString()
          : null,

        formattedCreateTime: order.create_time
          ? this.formatDate(order.create_time)
          : "N/A",

        items: this.transformLineItems(order.line_items || []),

        itemCount: order.line_items?.length || 0,
        itemsSummary: this.generateItemsSummary(order.line_items || []),

        buyerMessage: order.buyer_message || "",
        sellerNote: order.seller_note || "",
        trackingNumber: order.tracking_number || "",
        shippingProvider: order.shipping_provider || "",
        fulfillmentType: order.fulfillment_type,
        deliveryType: order.delivery_type,
        paymentMethod: order.payment_method_name || "",

        isCod: order.is_cod || false,
        isOnHold: order.is_on_hold_order || false,
        isBuyerRequestCancel: order.is_buyer_request_cancel || false,

        statusColorInt: this.getStatusColor(order.status),

        //  PACKAGE INFORMATION
        packageId: packageInfo.packageId,
        packageStatus: packageInfo.packageStatus,
        hasPackages: packageInfo.hasPackages,
        packagesCount: packageInfo.packagesCount,
        canShip: packageInfo.canShip,
        shippingType: packageInfo.shippingType,
      };

      return transformedOrder;
    });

    const result = {
      orders: transformedOrders,
      pagination: {
        total_count:
          tikTokResponse.data.total_count || transformedOrders.length,
        has_next_page: !!tikTokResponse.data.next_page_token,
        next_page_token: tikTokResponse.data.next_page_token || null,
        current_count: transformedOrders.length,
      },
    };

    return result;
  }

  extractPackageInfo(order) {
    console.log(" Extracting package info from order:", order.id);

    let packageId = null;
    let packageStatus = null;
    let hasPackages = false;
    let packagesCount = 0;
    let canShip = false;
    let shippingType = null;

    // Method 1: Direct package_id field
    if (order.package_id) {
      packageId = order.package_id;
      console.log(" Found package_id directly:", packageId);
    }

    // Method 2: packages array (most likely location)
    if (
      order.packages &&
      Array.isArray(order.packages) &&
      order.packages.length > 0
    ) {
      hasPackages = true;
      packagesCount = order.packages.length;

      // Take first package as primary (usually there's only one)
      const primaryPackage = order.packages[0];
      packageId = primaryPackage.id || primaryPackage.package_id;
      packageStatus = primaryPackage.status || primaryPackage.package_status;
      shippingType = primaryPackage.shipping_type;

      console.log(" Found packages array:", {
        count: packagesCount,
        primaryPackageId: packageId,
        primaryPackageStatus: packageStatus,
      });
    }

    // Method 3: package_ids array
    if (
      !packageId &&
      order.package_ids &&
      Array.isArray(order.package_ids) &&
      order.package_ids.length > 0
    ) {
      packageId = order.package_ids[0];
      console.log(" Found package_ids array, using first:", packageId);
    }

    // Method 4: fulfillment_details
    if (order.fulfillment_details) {
      if (!packageId && order.fulfillment_details.package_id) {
        packageId = order.fulfillment_details.package_id;
        console.log(" Found package_id in fulfillment_details:", packageId);
      }

      if (!packageStatus && order.fulfillment_details.package_status) {
        packageStatus = order.fulfillment_details.package_status;
      }

      if (!shippingType && order.fulfillment_details.shipping_type) {
        shippingType = order.fulfillment_details.shipping_type;
      }
    }

    // Method 5: Check fulfillment_list if exists
    if (
      !packageId &&
      order.fulfillment_list &&
      Array.isArray(order.fulfillment_list)
    ) {
      for (const fulfillment of order.fulfillment_list) {
        if (fulfillment.package_id) {
          packageId = fulfillment.package_id;
          packageStatus = fulfillment.package_status || packageStatus;
          console.log(" Found package_id in fulfillment_list:", packageId);
          break;
        }
      }
    }

    // Determine if order can be shipped
    const shippableStatuses = ["AWAITING_SHIPMENT", "TO_SHIP", "TO_FULFILL"];
    canShip = shippableStatuses.includes(order.status) && !!packageId;

    const result = {
      packageId: packageId ? packageId.toString() : null,
      packageStatus: packageStatus || "UNKNOWN",
      hasPackages,
      packagesCount,
      canShip,
      shippingType: shippingType || "UNKNOWN",
    };

    console.log(" Final package info:", result);
    return result;
  }

  parseAmount(amount) {
    if (!amount) return 0;
    if (typeof amount === "number") return amount;
    if (typeof amount === "string") return parseInt(amount) || 0;
    return 0;
  }

  transformLineItems(lineItems) {
    if (!lineItems || !Array.isArray(lineItems)) return [];

    return lineItems.map((item) => ({
      id: item.id,
      skuId: item.sku_id, // SKU ID from TikTok for mapping to SKU Master
      productId: item.product_id,
      productName: item.product_name || item.sku_name || "Produk Tidak Dikenal",
      sellerSku: item.seller_sku,
      skuName: item.sku_name,
      skuImage: item.sku_image,
      quantity: item.quantity || 1,
      price: this.parseAmount(item.sale_price || item.original_price),
      originalPrice: this.parseAmount(item.original_price),
      currency: item.currency || "IDR",
      itemStatus: this.translateItemStatus(item.display_status),
      itemStatusCode: item.display_status,
    }));
  }

  generateItemsSummary(lineItems) {
    if (!lineItems || !Array.isArray(lineItems) || lineItems.length === 0) {
      return "Tidak ada item";
    }

    if (lineItems.length === 1) {
      return lineItems[0].product_name || lineItems[0].sku_name || "Produk";
    }

    const firstItem =
      lineItems[0].product_name || lineItems[0].sku_name || "Produk";
    return `${firstItem} dan ${lineItems.length - 1} lainnya`;
  }

  getStatusColor(status) {
    const colorMap = {
      UNPAID: 0xffff9800,
      ON_HOLD: 0xffff5722,
      AWAITING_SHIPMENT: 0xff2196f3,
      PARTIALLY_SHIPPING: 0xff9c27b0,
      AWAITING_COLLECTION: 0xff795548,
      IN_TRANSIT: 0xff03a9f4,
      DELIVERED: 0xff4caf50,
      COMPLETED: 0xff8bc34a,
      CANCELLED: 0xfff44336,
    };

    return colorMap[status] || 0xff9e9e9e;
  }

  translateOrderStatus(status) {
    const statusMap = {
      UNPAID: "Belum Bayar",
      ON_HOLD: "Ditahan",
      AWAITING_SHIPMENT: "Menunggu Pengiriman",
      PARTIALLY_SHIPPING: "Sebagian Dikirim",
      AWAITING_COLLECTION: "Menunggu Penjemputan",
      IN_TRANSIT: "Dalam Pengiriman",
      DELIVERED: "Terkirim",
      COMPLETED: "Selesai",
      CANCELLED: "Dibatalkan",
    };

    return statusMap[status] || status || "Status Tidak Dikenal";
  }

  translateItemStatus(status) {
    const itemStatusMap = {
      UNPAID: "Belum Bayar",
      TO_FULFILL: "Siap Dikirim",
      AWAITING_SHIPMENT: "Menunggu Pengiriman",
      PARTIALLY_SHIPPED: "Sebagian Dikirim",
      SHIPPED: "Dikirim",
      DELIVERED: "Terkirim",
      CANCELLED: "Dibatalkan",
      RETURNED: "Dikembalikan",
    };

    return itemStatusMap[status] || status || "Status Item Tidak Dikenal";
  }

  formatCurrency(amount, currency = "IDR") {
    if (!amount || amount === 0) return "Rp 0";

    const numAmount = this.parseAmount(amount);

    const formatter = new Intl.NumberFormat("id-ID", {
      style: "currency",
      currency: currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });

    return formatter.format(numAmount);
  }

  formatDate(timestamp) {
    if (!timestamp) return null;

    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString("id-ID", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  async testConnection(req, res) {
    try {
      console.log("\n=== ORDER CONTROLLER TEST ===");

      const { sellerId, shop_cipher } = req.query;
      console.log("- sellerId from query:", sellerId);
      console.log("- shop_cipher from query:", shop_cipher);

      if (sellerId) {
        const shopRecord =
          (await Shop.findOne({ where: { seller_id: sellerId } })) ||
          (await Shop.findOne({ where: { marketplace_shop_id: sellerId } }));

        const tokenRecord = shopRecord
          ? await Token.findByShopId(shopRecord.id, null, "tiktok")
          : null;
        console.log("- Token found for sellerId:", !!tokenRecord);
        console.log(
          "- Access token:",
          tokenRecord?.access_token ? "SET" : "NOT SET",
        );
        console.log(
          "- Shop cipher:",
          tokenRecord?.shop_cipher ? "SET" : "NOT SET",
        );
        console.log("- Shop name:", tokenRecord?.shop_name);
      } else if (shop_cipher) {
        const shopRecord = await Shop.findOne({
          where: { shop_cipher },
        });
        const tokenRecord = shopRecord
          ? await Token.findByShopId(shopRecord.id, null, "tiktok")
          : null;
        console.log("- Token found for shop_cipher:", !!tokenRecord);
      }

      res.json({
        success: true,
        message: "Order controller test successful",
        data: {
          sellerId: sellerId || "not provided",
          shopCipher: shop_cipher || "not provided",
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      console.error("Test error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }

  async debugTokens(req, res) {
    try {
      console.log("\n=== DEBUG TOKENS ===");

      const allTokens = await Token.findAll({
        attributes: [
          "id",
          "shop_cipher",
          "access_token",
          "shop_name",
          "seller_name",
          "seller_id",
          "shop_id",
          "created_at",
        ],
        order: [["created_at", "DESC"]],
      });

      console.log("Found tokens:", allTokens.length);

      const tokenInfo = allTokens.map((token) => ({
        id: token.id,
        seller_id: token.seller_id,
        shop_id: token.shop_id,
        shop_cipher: token.shop_cipher,
        shop_name: token.shop_name,
        seller_name: token.seller_name,
        has_access_token: !!token.access_token,
        access_token_length: token.access_token ? token.access_token.length : 0,
        created_at: token.created_at,
      }));

      console.log("Token info:", tokenInfo);

      res.json({
        success: true,
        data: {
          total_tokens: allTokens.length,
          tokens: tokenInfo,
        },
      });
    } catch (error) {
      console.error("Debug tokens error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }

  async getOrderList(req, res) {
    try {
      console.log("\n=== ORDER CONTROLLER DEBUG ===");
      console.log("getOrderList called");
      console.log("req.method:", req.method);
      console.log("req.url:", req.url);
      console.log("req.params:", req.params);
      console.log("req.query:", req.query);
      console.log("req.body:", req.body);

      let sellerId = req.params.shopId || req.query.sellerId;
      console.log("Extracted sellerId:", sellerId);

      if (!sellerId) {
        console.log("ERROR: No sellerId provided");
        return res.status(400).json({
          success: false,
          message: "sellerId or shopId is required",
        });
      }

      console.log("Step 1: Looking for token by sellerId...");

      const token = await Token.findByShopId(sellerId, null, "tiktok");

      console.log("Step 1 result - token found:", !!token);

      if (token) {
        console.log("Token details:", {
          seller_id: token.seller_id,
          shop_id: token.shop_id,
          shop_name: token.shop_name,
          shop_cipher: token.shop_cipher,
          has_access_token: !!token.access_token,
        });
      }

      if (!token || !token.access_token) {
        console.log("ERROR: No token found for sellerId:", sellerId);
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired for this seller",
        });
      }

      console.log("Step 2: Found token for shop:", token.shop_name);
      console.log("Step 3: Calling OrderService.getOrderList...");

      try {
        const rawOrderList = await OrderService.getOrderList(
          token.access_token,
          token.shop_cipher,
          req.body || {},
        );

        console.log("Step 3 result - OrderService success");
        console.log("Orders found:", rawOrderList?.data?.orders?.length || 0);

        const transformedData = this.transformOrderData(rawOrderList);
        //  REMOVED: Dashboard sync moved to frontend (view_order_screen only)
        // await this.syncToGroupDashboard(token, transformedData.orders);

        console.log("Step 4: Data transformation completed");
        console.log("Transformed orders count:", transformedData.orders.length);

        const publicShopId = getPublicShopId(token, sellerId);
        const sellerIdentifier =
          token.seller_id || token.marketplace_shop_id || sellerId;

        res.json({
          success: true,
          data: transformedData,
          seller: {
            sellerId: sellerIdentifier,
            shopName: token.shop_name,
            shopId: publicShopId,
            internalShopId: token.shop_id,
            shopCipher: token.shop_cipher,
          },
        });
      } catch (serviceError) {
        console.error("Step 3 error - OrderService failed:", serviceError);
        throw serviceError;
      }
    } catch (error) {
      console.error("=== ORDER CONTROLLER ERROR ===");
      console.error("Error message:", error.message);
      console.error("Error stack:", error.stack);

      res.status(500).json({
        success: false,
        message: error.message,
        stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
      });
    }
  }

  async syncToGroupDashboard(tokenRecord, orders) {
    try {
      // Cari user berdasarkan shop untuk dapat group_id
      const UserShop = require('../../models/UserShop');
      const User = require('../../models/User');
    
    const userShop = await UserShop.findOne({ 
      where: { shop_id: tokenRecord.shop_id }
    });
    
    if (!userShop) return;
    
    const user = await User.findByPk(userShop.user_id);
    if (!user || !user.group_id) {
      console.log(' User without group_id - skipping dashboard sync');
      return;
    }

    // Cari group berdasarkan user group_id
    const group = await Group.findByGID(user.group_id);
    if (!group) {
      console.log(`️ Group ${user.group_id} not found in groups table`);
      return;
    }

    // Kirim data ke dashboard grup
    console.log(` Sending ${orders.length} orders to ${group.nama_group} dashboard...`);
    console.log(` Target URL: ${group.url}`);

    // Real HTTP request
    try {
      const response = await axios.post(group.url, {
        orders: orders,
        shop_info: {
          shop_id: getPublicShopId(tokenRecord),
          shop_name: tokenRecord.shop_name
        },
        secret: group.secret
      }, {
        timeout: 5000,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SparkCommerce/1.0'
        }
      });

      console.log(` Order data sent to ${group.nama_group} dashboard (${orders.length} orders)`);
      console.log(` Response status: ${response.status}`);
      console.log(` Response data:`, response.data);
    } catch (httpError) {
      console.log(` Failed to send data to ${group.nama_group}: ${httpError.message}`);
      if (httpError.response) {
        console.log(` Response status: ${httpError.response.status}`);
        console.log(` Response data:`, httpError.response.data);
      }
    }

  } catch (error) {
    console.log(` Failed to sync data to group dashboard: ${error.message}`);
  }
}

  async getOrderDetail(req, res) {
    try {
      console.log("\n=== ORDER DETAIL CONTROLLER DEBUG ===");
      console.log("getOrderDetail called");
      console.log("req.params:", req.params);
      console.log("req.query:", req.query);

      const shopId = req.params.shopId || req.query.sellerId;
      const orderIds = req.params.orderIds || req.query.ids;
      const shop_cipher = req.query.shop_cipher;

      console.log("Extracted params:", { shopId, orderIds, shop_cipher });

      let tokenRecord;

      if (shopId) {
        console.log("Looking for token by shopId:", shopId);
        tokenRecord = await Token.findByShopId(shopId, null, "tiktok");
      } else if (shop_cipher) {
        console.log("Looking for token by shop_cipher:", shop_cipher);
        const shopRecord = await Shop.findOne({ where: { shop_cipher } });
        tokenRecord = shopRecord
          ? await Token.findByShopId(shopRecord.id, null, "tiktok")
          : null;
      }

      if (!tokenRecord) {
        return res.status(404).json({
          success: false,
          message: "Shop not found or token expired",
        });
      }

      if (!orderIds) {
        return res.status(400).json({
          success: false,
          message: "Order IDs are required",
        });
      }

      console.log("Token found for shop:", tokenRecord.shop_name);

      const rawOrderDetail = await OrderService.getOrderDetail(
        tokenRecord.access_token,
        tokenRecord.shop_cipher,
        orderIds,
      );

      const transformedData = this.transformOrderData(rawOrderDetail);

      const publicShopId = getPublicShopId(tokenRecord, shopId);

      res.json({
        success: true,
        data: transformedData,
        seller: {
          sellerId: tokenRecord.seller_id || tokenRecord.marketplace_shop_id,
          shopName: tokenRecord.shop_name,
          shopId: publicShopId,
          internalShopId: tokenRecord.shop_id,
          shopCipher: tokenRecord.shop_cipher,
        },
      });
    } catch (error) {
      console.error("OrderDetail error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }

  async testTransformation(req, res) {
    try {
      const { sellerId } = req.query;

      if (!sellerId) {
        return res.status(400).json({
          success: false,
          message: "sellerId is required for testing",
        });
      }

      const token = await Token.findByShopId(sellerId, null, "tiktok");

      if (!token || !token.access_token) {
        return res.status(404).json({
          success: false,
          message: "Token not found",
        });
      }

      const rawData = await OrderService.getOrderList(
        token.access_token,
        token.shop_cipher,
        { page_size: 5 },
      );

      const transformedData = this.transformOrderData(rawData);

      res.json({
        success: true,
        message: "Transformation test completed",
        data: {
          raw_sample: rawData.data?.orders?.[0] || null,
          transformed_sample: transformedData.orders[0] || null,
          raw_count: rawData.data?.orders?.length || 0,
          transformed_count: transformedData.orders.length,
          pagination: transformedData.pagination,
        },
      });
    } catch (error) {
      console.error("Test transformation error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }

  // Tambah method ini ke OrderController class

  async shipPackage(req, res) {
    try {
      console.log("\n=== SHIP PACKAGE CONTROLLER ===");
      console.log("Request params:", req.params);
      console.log("Request body:", req.body);

      const { shopId, packageId } = req.params;
      const { handover_method, pickup_slot, self_shipment } = req.body;

      if (!shopId || !packageId) {
        return res.status(400).json({
          success: false,
          message: "Shop ID and Package ID are required",
        });
      }

      const tokenRecord = await Token.findByShopId(shopId, null, "tiktok");

      if (!tokenRecord || !tokenRecord.access_token) {
        return res.status(404).json({
          success: false,
          message: "Shop token not found",
        });
      }

      //  STEP 1: Verify package exists and can be shipped BEFORE attempting ship
      console.log("STEP 1: Checking package detail before ship...");

      let packageDetail = null;
      try {
        packageDetail = await OrderService.getPackageDetail(
          tokenRecord.access_token,
          tokenRecord.shop_cipher,
          packageId,
        );

        console.log(" Package Detail Retrieved:", {
          packageId: packageDetail.data?.package_id,
          packageStatus: packageDetail.data?.package_status,
          handoverMethod: packageDetail.data?.handover_method,
          hasOrders: !!packageDetail.data?.orders,
        });

        //  Validate package status
        const packageStatus = packageDetail.data?.package_status;
        const shippableStatuses = ["PROCESSING", "READY_TO_SHIP", "TO_SHIP"];

        if (!shippableStatuses.includes(packageStatus)) {
          return res.status(400).json({
            success: false,
            message: `Package cannot be shipped. Current status: ${packageStatus}`,
            data: {
              packageId: packageId,
              currentStatus: packageStatus,
              allowedStatuses: shippableStatuses,
            },
          });
        }
      } catch (detailError) {
        console.error("Failed to get package detail:", detailError.message);

        //  Check if it's a "package not found" vs other errors
        if (
          detailError.message.includes("21011001") ||
          detailError.message.includes("Package not found")
        ) {
          return res.status(404).json({
            success: false,
            message: `Package ID ${packageId} not found. Please verify the package ID is correct.`,
            error_code: "PACKAGE_NOT_FOUND",
          });
        }

        //  For other errors (like 21011005), still attempt to ship but log the issue
        console.log(
          "️ Could not verify package status due to API error, proceeding with ship attempt...",
        );
        console.log("️ API Error:", detailError.message);
      }

      //  STEP 2: Proceed with shipping
      console.log("STEP 2: Proceeding with package shipment...");

      // Prepare shipment data
      const shipmentData = {
        handover_method: handover_method || "PICKUP",
      };

      if (pickup_slot) {
        shipmentData.pickup_slot = pickup_slot;
      }

      if (self_shipment) {
        shipmentData.self_shipment = self_shipment;
      }

      // Call ship package API
      const result = await OrderService.shipPackage(
        tokenRecord.access_token,
        tokenRecord.shop_cipher,
        packageId,
        shipmentData,
      );

      console.log(" Ship package successful:", result);

      res.json({
        success: true,
        message: "Package shipped successfully",
        data: result.data,
        packageId: packageId,
        handover_method: shipmentData.handover_method,
      });
    } catch (error) {
      console.error(" Ship package error:", error);

      let errorMessage = error.message;
      let statusCode = 500;

      if (error.message.includes("21011005")) {
        errorMessage =
          "Invalid order parameters. The order may not be ready for shipment or may have invalid data.";
        statusCode = 400;
      } else if (error.message.includes("21011001")) {
        errorMessage =
          "Package not found. Please verify the package ID is correct.";
        statusCode = 404;
      } else if (error.message.includes("21011040")) {
        errorMessage = "Package has already been shipped.";
        statusCode = 400;
      } else if (error.message.includes("21008044")) {
        errorMessage =
          "Package has after-sale request. Please process the after-sale request first.";
        statusCode = 400;
      }

      res.status(statusCode).json({
        success: false,
        message: errorMessage,
        originalError: error.message,
        packageId: req.params.packageId,
      });
    }
  }

  async getShippingDocument(req, res) {
    try {
      console.log("\n=== GET SHIPPING DOCUMENT CONTROLLER ===");
      console.log("Request params:", req.params);
      console.log("Request query:", req.query);

      const { shopId, packageId } = req.params;
      const {
        document_type = "SHIPPING_LABEL",
        document_size = "A6",
        document_format = "PDF",
      } = req.query;

      if (!shopId || !packageId) {
        return res.status(400).json({
          success: false,
          message: "Shop ID and Package ID are required",
        });
      }

      // Find token
      const tokenRecord = await Token.findByShopId(shopId, null, "tiktok");

      if (!tokenRecord || !tokenRecord.access_token) {
        return res.status(404).json({
          success: false,
          message: "Shop token not found",
        });
      }

      // Get shipping document
      const result = await OrderService.getShippingDocument(
        tokenRecord.access_token,
        tokenRecord.shop_cipher,
        packageId,
        document_type,
        document_size,
        document_format,
      );

      console.log("Get shipping document successful:", result);

      res.json({
        success: true,
        message: "Shipping document retrieved successfully",
        data: {
          doc_url: result.data.doc_url,
          tracking_number: result.data.tracking_number,
          document_type: document_type,
          document_format: document_format,
        },
        packageId: packageId,
      });
    } catch (error) {
      console.error("Get shipping document error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }

  async getPackageDetail(req, res) {
    try {
      console.log("\n=== GET PACKAGE DETAIL CONTROLLER ===");
      console.log("Request params:", req.params);

      const { shopId, packageId } = req.params;

      if (!shopId || !packageId) {
        return res.status(400).json({
          success: false,
          message: "Shop ID and Package ID are required",
        });
      }

      // Find token
      const tokenRecord = await Token.findByShopId(shopId, null, "tiktok");

      if (!tokenRecord || !tokenRecord.access_token) {
        return res.status(404).json({
          success: false,
          message: "Shop token not found",
        });
      }

      // Get package detail
      const result = await OrderService.getPackageDetail(
        tokenRecord.access_token,
        tokenRecord.shop_cipher,
        packageId,
      );

      console.log("Get package detail successful:", result);

      res.json({
        success: true,
        message: "Package detail retrieved successfully",
        data: result.data,
        packageId: packageId,
      });
    } catch (error) {
      console.error("Get package detail error:", error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }
}

module.exports = new OrderController();
