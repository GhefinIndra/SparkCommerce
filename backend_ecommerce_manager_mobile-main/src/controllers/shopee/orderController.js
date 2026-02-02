// src/controllers/shopee/orderController.js
const OrderService = require('../../services/shopee/orderService');
const Token = require('../../models/Token');

class ShopeeOrderController {
  /**
   * Transform Shopee order data to unified format
   * Adapts Shopee-specific field names to match app's expected format
   */
  transformOrderData(shopeeResponse) {
    console.log(' Transform Debug - Raw Shopee Response Structure:', {
      hasResponse: !!shopeeResponse,
      responseType: typeof shopeeResponse,
      hasResponse: !!shopeeResponse?.response,
      responseType: typeof shopeeResponse?.response,
      hasOrderList: !!shopeeResponse?.response?.order_list,
      orderListLength: shopeeResponse?.response?.order_list?.length || 0,
    });

    if (!shopeeResponse || !shopeeResponse.response) {
      console.log('️ Transform: No valid shopeeResponse or response');
      return {
        orders: [],
        pagination: {
          total_count: 0,
          has_next_page: false,
          next_cursor: null,
        },
      };
    }

    const ordersArray = shopeeResponse.response.order_list;

    if (!ordersArray || !Array.isArray(ordersArray)) {
      console.log('️ Transform: No orders array found');
      return {
        orders: [],
        pagination: {
          total_count: 0,
          has_next_page: shopeeResponse.response.more || false,
          next_cursor: shopeeResponse.response.next_cursor || null,
        },
      };
    }

    console.log(` Transform: Found ${ordersArray.length} orders to transform`);

    const transformedOrders = ordersArray.map((order, index) => {
      //  EXTRACT PACKAGE INFORMATION
      const packageInfo = this.extractPackageInfo(order);

      console.log(` Order ${index + 1} Package Info:`, {
        orderSn: order.order_sn,
        packageNumber: packageInfo.packageNumber,
        packageStatus: packageInfo.packageStatus,
        hasPackages: packageInfo.hasPackages,
        packagesCount: packageInfo.packagesCount,
      });

      //  DEBUG: Log raw order data
      console.log(` Raw Order ${index + 1} Data:`, {
        order_sn: order.order_sn,
        create_time: order.create_time,
        pay_time: order.pay_time,
        update_time: order.update_time,
        create_time_type: typeof order.create_time,
        pay_time_type: typeof order.pay_time,
        update_time_type: typeof order.update_time,
      });

      const transformedOrder = {
        // Order Identifiers
        id: order.order_sn,
        orderId: order.order_sn,
        orderNumber: order.order_sn,

        // Status
        status: this.translateOrderStatus(order.order_status),
        statusCode: order.order_status,
        orderStatusName: this.translateOrderStatus(order.order_status),

        // Customer Information
        customerName: order.recipient_address?.name || 'N/A',
        buyerName: order.recipient_address?.name || 'N/A',
        customerPhone: order.recipient_address?.phone || 'N/A',
        customerAddress: order.recipient_address?.full_address || 'N/A',

        // Financial Information
        totalAmount: (this.parseAmount(order.total_amount) || 0).toString(),
        subTotal: (this.parseAmount(order.total_amount) || 0).toString(), // Shopee doesn't separate subtotal
        shippingFee: (this.parseAmount(order.estimated_shipping_fee) || 0).toString(),
        currency: order.currency || 'IDR',
        formattedAmount: this.formatCurrency(
          this.parseAmount(order.total_amount) || 0,
          order.currency || 'IDR'
        ),

        // Dates (Shopee uses Unix timestamp in seconds)
        orderDate: order.create_time
          ? new Date(order.create_time * 1000).toISOString()
          : '',
        paidDate: order.pay_time
          ? new Date(order.pay_time * 1000).toISOString()
          : '',
        updateDate: order.update_time
          ? new Date(order.update_time * 1000).toISOString()
          : '',
        formattedCreateTime: order.create_time
          ? this.formatDate(order.create_time)
          : 'N/A',

        // Items
        items: this.transformLineItems(order.item_list || []),
        itemCount: order.item_list?.length || 0,
        itemsSummary: this.generateItemsSummary(order.item_list || []),

        // Messages and Notes
        buyerMessage: order.message_to_seller || '',
        sellerNote: order.note || '',

        // Shipping Information
        trackingNumber: packageInfo.trackingNumber || '',
        shippingProvider: order.shipping_carrier || order.checkout_shipping_carrier || '',
        shippingCarrier: order.shipping_carrier || order.checkout_shipping_carrier || '',
        fulfillmentType: order.fulfillment_flag || 'fulfilled_by_local_seller',
        deliveryType: 'STANDARD_DELIVERY', // Shopee doesn't have this exact field
        paymentMethod: order.payment_method || '',

        // Flags
        isCod: order.cod || false,
        isOnHold: order.order_status === 'PENDING' || false,
        isBuyerRequestCancel: false, // Shopee doesn't have this field

        // Color coding
        statusColorInt: this.getStatusColor(order.order_status),

        // Package Information
        packageId: packageInfo.packageNumber,
        packageNumber: packageInfo.packageNumber,
        packageStatus: packageInfo.packageStatus,
        hasPackages: packageInfo.hasPackages,
        packagesCount: packageInfo.packagesCount,
        canShip: packageInfo.canShip,
        logisticsStatus: packageInfo.logisticsStatus,
        logisticsChannelId: packageInfo.logisticsChannelId,

        // Additional Shopee-specific fields
        region: order.region || '',
        daysToShip: order.days_to_ship || 0,
        shipByDate: order.ship_by_date
          ? new Date(order.ship_by_date * 1000).toISOString()
          : '',
        cancelBy: order.cancel_by || '',
        cancelReason: order.cancel_reason || '',
        buyerCancelReason: order.buyer_cancel_reason || '',
        actualShippingFeeConfirmed: order.actual_shipping_fee_confirmed || false,
        pickupDoneTime: order.pickup_done_time
          ? new Date(order.pickup_done_time * 1000).toISOString()
          : '',
        splitUp: order.split_up || false,
        bookingSn: order.booking_sn || null,
        advancePackage: order.advance_package || false,
      };

      //  DEBUG: Log transformed order dates
      console.log(` Transformed Order ${index + 1} Dates:`, {
        orderDate: transformedOrder.orderDate,
        orderDateType: typeof transformedOrder.orderDate,
        paidDate: transformedOrder.paidDate,
        paidDateType: typeof transformedOrder.paidDate,
        updateDate: transformedOrder.updateDate,
        updateDateType: typeof transformedOrder.updateDate,
      });

      return transformedOrder;
    });

    const result = {
      orders: transformedOrders,
      pagination: {
        total_count: transformedOrders.length, // Shopee doesn't provide total_count in list API
        has_next_page: shopeeResponse.response.more || false,
        next_cursor: shopeeResponse.response.next_cursor || null,
        current_count: transformedOrders.length,
      },
    };

    console.log(' Final transformed result structure:', {
      ordersCount: result.orders.length,
      firstOrderId: result.orders[0]?.orderId,
      firstOrderDateSample: result.orders[0]?.orderDate?.substring(0, 20),
    });

    return result;
  }

  /**
   * Extract package information from Shopee order
   * Shopee has package_list array with package details
   */
  extractPackageInfo(order) {
    console.log(' Extracting package info from Shopee order:', order.order_sn);

    let packageNumber = null;
    let packageStatus = null;
    let logisticsStatus = null;
    let logisticsChannelId = null;
    let hasPackages = false;
    let packagesCount = 0;
    let canShip = false;
    let trackingNumber = null;
    let shippingCarrier = null;

    // Shopee has package_list array
    if (order.package_list && Array.isArray(order.package_list) && order.package_list.length > 0) {
      hasPackages = true;
      packagesCount = order.package_list.length;

      // Take first package as primary
      const primaryPackage = order.package_list[0];
      packageNumber = primaryPackage.package_number;
      logisticsStatus = primaryPackage.logistics_status;
      logisticsChannelId = primaryPackage.logistics_channel_id;
      shippingCarrier = primaryPackage.shipping_carrier;

      // Package status mapping from logistics_status
      packageStatus = this.mapLogisticsStatus(logisticsStatus);

      console.log(' Found package_list:', {
        count: packagesCount,
        primaryPackageNumber: packageNumber,
        logisticsStatus: logisticsStatus,
        packageStatus: packageStatus,
      });
    }

    // Determine if order can be shipped
    // Shopee shippable statuses
    const shippableStatuses = ['READY_TO_SHIP', 'UNPAID', 'PROCESSED'];
    canShip = shippableStatuses.includes(order.order_status) && !!packageNumber;

    const result = {
      packageNumber: packageNumber ? packageNumber.toString() : null,
      packageStatus: packageStatus || 'UNKNOWN',
      logisticsStatus: logisticsStatus || 'UNKNOWN',
      logisticsChannelId: logisticsChannelId || null,
      hasPackages,
      packagesCount,
      canShip,
      trackingNumber: trackingNumber,
      shippingCarrier: shippingCarrier,
    };

    console.log(' Final package info:', result);
    return result;
  }

  /**
   * Map Shopee logistics_status to general package status
   */
  mapLogisticsStatus(logisticsStatus) {
    const statusMap = {
      'LOGISTICS_NOT_STARTED': 'READY_TO_SHIP',
      'LOGISTICS_REQUEST_CREATED': 'PROCESSING',
      'LOGISTICS_PICKUP_DONE': 'PICKED_UP',
      'LOGISTICS_PICKUP_RETRY': 'PICKUP_RETRY',
      'LOGISTICS_PICKUP_FAILED': 'PICKUP_FAILED',
      'LOGISTICS_DELIVERY_DONE': 'DELIVERED',
      'LOGISTICS_DELIVERY_FAILED': 'DELIVERY_FAILED',
      'LOGISTICS_DELIVERY_RETRY': 'DELIVERY_RETRY',
      'LOGISTICS_ON_HOLD': 'ON_HOLD',
      'LOGISTICS_RETURNED': 'RETURNED',
      'LOGISTICS_LOST': 'LOST',
      'LOGISTICS_CANCELLED': 'CANCELLED',
      'LOGISTICS_INVALID': 'INVALID',
    };

    return statusMap[logisticsStatus] || logisticsStatus || 'UNKNOWN';
  }

  /**
   * Parse amount (Shopee returns float)
   */
  parseAmount(amount) {
    if (!amount) return 0;
    if (typeof amount === 'number') return amount;
    if (typeof amount === 'string') return parseFloat(amount) || 0;
    return 0;
  }

  /**
   * Transform Shopee item_list to unified format
   */
  transformLineItems(itemList) {
    if (!itemList || !Array.isArray(itemList)) return [];

    return itemList.map((item) => ({
      id: item.item_id ? item.item_id.toString() : '',
      skuId: item.model_id ? item.model_id.toString() : '', // Shopee uses model_id as variation ID
      productId: item.item_id ? item.item_id.toString() : '',
      productName: item.item_name || item.model_name || 'Produk Tidak Dikenal',
      sellerSku: item.model_sku || item.item_sku || '',
      skuName: item.model_name || '',
      skuImage: item.image_info?.image_url || '',
      quantity: item.model_quantity_purchased || 1,
      price: this.parseAmount(item.model_discounted_price || item.model_original_price).toString(),
      originalPrice: this.parseAmount(item.model_original_price).toString(),
      currency: 'IDR', // Default, Shopee doesn't have currency per item
      itemStatus: this.translateItemStatus(item.promotion_type),
      itemStatusCode: item.promotion_type || 'NORMAL',

      // Additional Shopee fields
      orderItemId: item.order_item_id ? item.order_item_id.toString() : '',
      promotionType: item.promotion_type || '',
      promotionId: item.promotion_id || 0,
      promotionGroupId: item.promotion_group_id || 0,
      addOnDeal: item.add_on_deal || false,
      mainItem: item.main_item || false,
      wholesale: item.wholesale || false,
      weight: item.weight || 0,
      productLocationId: item.product_location_id || [],
    }));
  }

  /**
   * Generate summary of items for display
   */
  generateItemsSummary(itemList) {
    if (!itemList || !Array.isArray(itemList) || itemList.length === 0) {
      return 'Tidak ada item';
    }

    if (itemList.length === 1) {
      return itemList[0].item_name || itemList[0].model_name || 'Produk';
    }

    const firstItem = itemList[0].item_name || itemList[0].model_name || 'Produk';
    return `${firstItem} dan ${itemList.length - 1} lainnya`;
  }

  /**
   * Get status color for UI
   * Returns color in ARGB format
   */
  getStatusColor(status) {
    const colorMap = {
      'UNPAID': 0xffff9800, // Orange
      'PENDING': 0xffff9800, // Orange
      'READY_TO_SHIP': 0xff2196f3, // Blue
      'PROCESSED': 0xff9c27b0, // Purple
      'SHIPPED': 0xff03a9f4, // Light Blue
      'IN_TRANSIT': 0xff03a9f4, // Light Blue
      'TO_CONFIRM_RECEIVE': 0xff00bcd4, // Cyan
      'IN_CANCEL': 0xffff5722, // Red Orange
      'CANCELLED': 0xfff44336, // Red
      'TO_RETURN': 0xffff5722, // Red Orange
      'COMPLETED': 0xff4caf50, // Green
      'INVOICE_PENDING': 0xffff9800, // Orange
    };

    return colorMap[status] || 0xff9e9e9e; // Grey as default
  }

  /**
   * Translate Shopee order status to Indonesian
   */
  translateOrderStatus(status) {
    const statusMap = {
      'UNPAID': 'Belum Bayar',
      'PENDING': 'Menunggu',
      'READY_TO_SHIP': 'Siap Dikirim',
      'PROCESSED': 'Diproses',
      'RETRY_SHIP': 'Coba Kirim Ulang',
      'SHIPPED': 'Dikirim',
      'IN_TRANSIT': 'Dalam Pengiriman',
      'TO_CONFIRM_RECEIVE': 'Menunggu Konfirmasi',
      'IN_CANCEL': 'Dalam Pembatalan',
      'CANCELLED': 'Dibatalkan',
      'TO_RETURN': 'Dalam Pengembalian',
      'COMPLETED': 'Selesai',
      'INVOICE_PENDING': 'Menunggu Invoice',
    };

    return statusMap[status] || status || 'Status Tidak Dikenal';
  }

  /**
   * Translate item status to Indonesian
   */
  translateItemStatus(promotionType) {
    // Shopee doesn't have direct item status like TikTok
    // Using promotion_type as indicator
    const itemStatusMap = {
      'product_promotion': 'Promo Produk',
      'flash_sale': 'Flash Sale',
      'bundle_deal': 'Paket Bundle',
      'add_on_deal_main': 'Add-On Utama',
      'add_on_deal_sub': 'Add-On Tambahan',
      'NORMAL': 'Normal',
    };

    return itemStatusMap[promotionType] || 'Normal';
  }

  /**
   * Format currency for display
   */
  formatCurrency(amount, currency = 'IDR') {
    if (!amount || amount === 0) return 'Rp 0';

    const numAmount = this.parseAmount(amount);

    const formatter = new Intl.NumberFormat('id-ID', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });

    return formatter.format(numAmount);
  }

  /**
   * Format timestamp to readable date
   */
  formatDate(timestamp) {
    if (!timestamp) return null;

    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString('id-ID', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  /**
   * Get order list
   * GET /api/orders/:shopId/list
   */
  async getOrderList(req, res) {
    try {
      const { shopId } = req.params;
      const {
        time_range_field = 'create_time',
        time_from,
        time_to,
        page_size = 20,
        cursor = '',
        order_status,
        // Sesuai dokumentasi Shopee: get_order_list hanya support order_status
        response_optional_fields = 'order_status',
      } = req.body || req.query;

      console.log('\n === GET SHOPEE ORDER LIST ===');
      console.log('Shop ID:', shopId);
      console.log('Filters:', {
        time_range_field,
        time_from,
        time_to,
        page_size,
        cursor,
        order_status,
      });

      // Validate required parameters
      if (!time_from || !time_to) {
        return res.status(400).json({
          success: false,
          message: 'time_from and time_to are required',
        });
      }

      // Build filters
      const filters = {
        time_range_field,
        time_from: parseInt(time_from),
        time_to: parseInt(time_to),
        page_size: parseInt(page_size),
        cursor,
        response_optional_fields,
      };

      if (order_status) {
        filters.order_status = order_status;
      }

      // Call Shopee API to get order list (only order_sn)
      const shopeeResponse = await OrderService.getOrderList(shopId, filters);

      console.log(' Got order list, now fetching details...');

      // Extract order_sn array from response
      const orderSnList = shopeeResponse.response?.order_list?.map(order => order.order_sn) || [];

      if (orderSnList.length === 0) {
        console.log('️ No orders found');
        return res.json({
          success: true,
          data: {
            orders: [],
            pagination: {
              total_count: 0,
              has_next_page: shopeeResponse.response?.more || false,
              next_cursor: shopeeResponse.response?.next_cursor || null,
              current_count: 0,
            },
          },
          request_id: shopeeResponse.request_id,
        });
      }

      console.log(` Fetching details for ${orderSnList.length} orders: ${orderSnList.join(', ')}`);

      // Fetch order details for all orders (Shopee supports up to 50 order_sn per request)
      const detailResponse = await OrderService.getOrderDetail(shopId, orderSnList, {
        response_optional_fields: 'buyer_username,estimated_shipping_fee,recipient_address,actual_shipping_fee,item_list,pay_time,update_time,package_list,shipping_carrier,payment_method,total_amount,cod,days_to_ship,ship_by_date,buyer_cancel_reason,cancel_by,cancel_reason,actual_shipping_fee_confirmed,fulfillment_flag,pickup_done_time,message_to_seller,note',
      });

      // Transform detail data
      const transformedData = this.transformOrderData(detailResponse);

      // Add pagination info from original list response
      transformedData.pagination.has_next_page = shopeeResponse.response?.more || false;
      transformedData.pagination.next_cursor = shopeeResponse.response?.next_cursor || null;

      res.json({
        success: true,
        data: transformedData,
        request_id: detailResponse.request_id,
      });
    } catch (error) {
      console.error(' Error in getOrderList:', error);
      res.status(500).json({
        success: false,
        message: error.message,
        error: error.toString(),
      });
    }
  }

  /**
   * Get order detail
   * GET /api/orders/:shopId/detail/:orderSns
   */
  async getOrderDetail(req, res) {
    try {
      const { shopId, orderSns } = req.params;
      const {
        response_optional_fields = 'buyer_user_id,buyer_username,estimated_shipping_fee,recipient_address,actual_shipping_fee,goods_to_declare,note,note_update_time,item_list,pay_time,dropshipper,dropshipper_phone,split_up,buyer_cancel_reason,cancel_by,cancel_reason,actual_shipping_fee_confirmed,fulfillment_flag,pickup_done_time,package_list,shipping_carrier,payment_method,total_amount,invoice_data,order_chargeable_weight_gram',
      } = req.query;

      console.log('\n === GET SHOPEE ORDER DETAIL ===');
      console.log('Shop ID:', shopId);
      console.log('Order SNs:', orderSns);

      // Split comma-separated order SNs
      const orderSnArray = orderSns.split(',');

      // Call Shopee API
      const shopeeResponse = await OrderService.getOrderDetail(shopId, orderSnArray, {
        response_optional_fields,
      });

      // Transform data
      const transformedData = this.transformOrderData(shopeeResponse);

      res.json({
        success: true,
        data: transformedData,
        request_id: shopeeResponse.request_id,
      });
    } catch (error) {
      console.error(' Error in getOrderDetail:', error);
      res.status(500).json({
        success: false,
        message: error.message,
        error: error.toString(),
      });
    }
  }

  /**
   * Ship order
   * POST /api/orders/:shopId/ship/:orderSn
   */
  async shipOrder(req, res) {
    try {
      const { shopId, orderSn } = req.params;
      const shipmentData = req.body;

      console.log('\n === SHIP SHOPEE ORDER ===');
      console.log('Shop ID:', shopId);
      console.log('Order SN:', orderSn);
      console.log('Shipment Data:', shipmentData);

      // Call Shopee API
      const shopeeResponse = await OrderService.shipOrder(shopId, orderSn, shipmentData);

      res.json({
        success: true,
        data: shopeeResponse.response,
        request_id: shopeeResponse.request_id,
        message: 'Order shipped successfully',
      });
    } catch (error) {
      console.error(' Error in shipOrder:', error);
      res.status(500).json({
        success: false,
        message: error.message,
        error: error.toString(),
      });
    }
  }

  /**
   * Get tracking number
   * GET /api/orders/:shopId/tracking/:orderSn
   */
  async getTrackingNumber(req, res) {
    try {
      const { shopId, orderSn } = req.params;

      console.log('\n === GET SHOPEE TRACKING NUMBER ===');
      console.log('Shop ID:', shopId);
      console.log('Order SN:', orderSn);

      // Call Shopee API
      const shopeeResponse = await OrderService.getTrackingNumber(shopId, orderSn);

      res.json({
        success: true,
        data: shopeeResponse.response,
        request_id: shopeeResponse.request_id,
      });
    } catch (error) {
      console.error(' Error in getTrackingNumber:', error);
      res.status(500).json({
        success: false,
        message: error.message,
        error: error.toString(),
      });
    }
  }

  /**
   * Test connection
   * GET /api/orders/test
   */
  async testConnection(req, res) {
    try {
      console.log('\n=== SHOPEE ORDER CONTROLLER TEST ===');

      const { shopId } = req.query;
      console.log('- shopId from query:', shopId);

      if (shopId) {
        const tokenRecord = await Token.findByShopId(shopId, null, 'shopee');
        console.log('- Token found for shopId:', !!tokenRecord);
        console.log('- Access token:', tokenRecord?.access_token ? 'SET' : 'NOT SET');
        console.log('- Shop name:', tokenRecord?.shop_name);
      }

      res.json({
        success: true,
        message: 'Shopee Order controller test successful',
        data: {
          shopId: shopId || 'not provided',
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      console.error('Test error:', error);
      res.status(500).json({
        success: false,
        message: error.message,
      });
    }
  }
}

module.exports = new ShopeeOrderController();
