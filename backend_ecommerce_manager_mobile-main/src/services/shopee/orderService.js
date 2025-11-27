// src/services/shopee/orderService.js
const config = require('../../config/env');
const { buildShopeeParams, buildShopeeUrl } = require('../../utils/shopeeSignature');
const ShopeeAuthService = require('./authService');

/**
 * Shopee Order Service
 * Handles all order-related API calls to Shopee Open Platform
 */
class ShopeeOrderService {
  constructor() {
    this.baseUrl = config.shopee.apiUrl;
    this.partnerId = config.shopee.partnerId;
    this.partnerKey = config.shopee.partnerKey;
  }

  /**
   * Get list of orders with filters
   * API: GET /api/v2/order/get_order_list
   *
   * @param {string} shopId - Shopee Shop ID
   * @param {object} filters - Filter options
   * @param {string} filters.time_range_field - 'create_time' or 'update_time'
   * @param {number} filters.time_from - Unix timestamp (seconds)
   * @param {number} filters.time_to - Unix timestamp (seconds)
   * @param {number} filters.page_size - Number of orders per page (1-100, default 20)
   * @param {string} filters.cursor - Pagination cursor (optional)
   * @param {string} filters.order_status - Order status filter (optional)
   * @param {boolean} filters.request_order_status_pending - Support PENDING status (optional)
   * @param {string} filters.response_optional_fields - Optional fields to include (optional)
   * @returns {Promise<object>} Order list response
   */
  async getOrderList(shopId, filters = {}) {
    try {
      console.log(` Fetching Shopee order list for shop: ${shopId}`);
      console.log(' Filters:', JSON.stringify(filters, null, 2));

      // Get valid access token
      const tokenRecord = await ShopeeAuthService.getValidToken(shopId);
      const accessToken = tokenRecord.access_token;

      // API path
      const apiPath = '/api/v2/order/get_order_list';

      // Build signature parameters (Shop API)
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add filter parameters
      if (filters.time_range_field) params.time_range_field = filters.time_range_field;
      if (filters.time_from) params.time_from = filters.time_from;
      if (filters.time_to) params.time_to = filters.time_to;
      if (filters.page_size) params.page_size = filters.page_size;
      if (filters.cursor) params.cursor = filters.cursor;
      if (filters.order_status) params.order_status = filters.order_status;
      if (filters.response_optional_fields) params.response_optional_fields = filters.response_optional_fields;
      if (filters.request_order_status_pending !== undefined) {
        params.request_order_status_pending = filters.request_order_status_pending;
      }

      // Build complete URL
      const url = buildShopeeUrl(this.baseUrl, apiPath, params);

      console.log(' Calling Shopee Get Order List API');
      console.log(' URL:', url.substring(0, 100) + '...');

      // Make API request
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();

      // Check for errors
      if (data.error) {
        console.error(' Shopee API Error:', {
          error: data.error,
          message: data.message,
          request_id: data.request_id,
        });
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      console.log(' Order list fetched successfully');
      console.log(' Orders found:', data.response?.order_list?.length || 0);
      console.log(' Has more pages:', data.response?.more || false);

      return data;
    } catch (error) {
      console.error(' Error fetching Shopee order list:', error.message);
      throw error;
    }
  }

  /**
   * Get detailed information for specific orders
   * API: GET /api/v2/order/get_order_detail
   *
   * @param {string} shopId - Shopee Shop ID
   * @param {string|string[]} orderSnList - Order serial number(s) (max 50)
   * @param {object} options - Additional options
   * @param {string} options.response_optional_fields - Optional fields to include
   * @param {boolean} options.request_order_status_pending - Support PENDING status
   * @returns {Promise<object>} Order detail response
   */
  async getOrderDetail(shopId, orderSnList, options = {}) {
    try {
      // Convert to array if single order_sn
      const orderSnArray = Array.isArray(orderSnList) ? orderSnList : [orderSnList];

      console.log(` Fetching Shopee order detail for shop: ${shopId}`);
      console.log(' Order SNs:', orderSnArray);

      // Validate order_sn_list limit
      if (orderSnArray.length > 50) {
        throw new Error('Maximum 50 order_sn allowed per request');
      }

      // Get valid access token
      const tokenRecord = await ShopeeAuthService.getValidToken(shopId);
      const accessToken = tokenRecord.access_token;

      // API path
      const apiPath = '/api/v2/order/get_order_detail';

      // Build signature parameters (Shop API)
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add order_sn_list (comma-separated)
      params.order_sn_list = orderSnArray.join(',');

      // Add optional parameters
      if (options.response_optional_fields) {
        params.response_optional_fields = options.response_optional_fields;
      }
      if (options.request_order_status_pending !== undefined) {
        params.request_order_status_pending = options.request_order_status_pending;
      }

      // Build complete URL
      const url = buildShopeeUrl(this.baseUrl, apiPath, params);

      console.log(' Calling Shopee Get Order Detail API');
      console.log(' URL:', url.substring(0, 100) + '...');

      // Make API request
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();

      // Check for errors
      if (data.error) {
        console.error(' Shopee API Error:', {
          error: data.error,
          message: data.message,
          request_id: data.request_id,
        });
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      console.log(' Order detail fetched successfully');
      console.log(' Orders retrieved:', data.response?.order_list?.length || 0);

      return data;
    } catch (error) {
      console.error(' Error fetching Shopee order detail:', error.message);
      throw error;
    }
  }

  /**
   * Get shipping parameters for an order
   * API: GET /api/v2/logistics/get_shipping_parameter
   *
   * @param {string} shopId - Shopee Shop ID
   * @param {string} orderSn - Order serial number
   * @returns {Promise<object>} Shipping parameters
   */
  async getShippingParameter(shopId, orderSn) {
    try {
      console.log(` Fetching shipping parameter for order: ${orderSn}`);

      // Get valid access token
      const tokenRecord = await ShopeeAuthService.getValidToken(shopId);
      const accessToken = tokenRecord.access_token;

      // API path
      const apiPath = '/api/v2/logistics/get_shipping_parameter';

      // Build signature parameters
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      params.order_sn = orderSn;

      // Build complete URL
      const url = buildShopeeUrl(this.baseUrl, apiPath, params);

      console.log(' Calling Shopee Get Shipping Parameter API');

      // Make API request
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();

      if (data.error) {
        console.error(' Shopee API Error:', data.message || data.error);
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      console.log(' Shipping parameter fetched successfully');

      return data;
    } catch (error) {
      console.error(' Error fetching shipping parameter:', error.message);
      throw error;
    }
  }

  /**
   * Ship an order
   * API: POST /api/v2/logistics/ship_order
   *
   * @param {string} shopId - Shopee Shop ID
   * @param {string} orderSn - Order serial number
   * @param {object} shipmentData - Shipment information
   * @returns {Promise<object>} Ship order response
   */
  async shipOrder(shopId, orderSn, shipmentData) {
    try {
      console.log(` Shipping order: ${orderSn}`);

      // Get valid access token
      const tokenRecord = await ShopeeAuthService.getValidToken(shopId);
      const accessToken = tokenRecord.access_token;

      // API path
      const apiPath = '/api/v2/logistics/ship_order';

      // Build signature parameters
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Build complete URL
      const url = buildShopeeUrl(this.baseUrl, apiPath, params);

      console.log(' Calling Shopee Ship Order API');

      // Request body
      const requestBody = {
        order_sn: orderSn,
        ...shipmentData,
      };

      // Make API request
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      const data = await response.json();

      if (data.error) {
        console.error(' Shopee API Error:', data.message || data.error);
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      console.log(' Order shipped successfully');

      return data;
    } catch (error) {
      console.error(' Error shipping order:', error.message);
      throw error;
    }
  }

  /**
   * Get tracking number for an order
   * API: GET /api/v2/logistics/get_tracking_number
   *
   * @param {string} shopId - Shopee Shop ID
   * @param {string} orderSn - Order serial number
   * @returns {Promise<object>} Tracking number response
   */
  async getTrackingNumber(shopId, orderSn) {
    try {
      console.log(` Fetching tracking number for order: ${orderSn}`);

      // Get valid access token
      const tokenRecord = await ShopeeAuthService.getValidToken(shopId);
      const accessToken = tokenRecord.access_token;

      // API path
      const apiPath = '/api/v2/logistics/get_tracking_number';

      // Build signature parameters
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      params.order_sn = orderSn;

      // Build complete URL
      const url = buildShopeeUrl(this.baseUrl, apiPath, params);

      console.log(' Calling Shopee Get Tracking Number API');

      // Make API request
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();

      if (data.error) {
        console.error(' Shopee API Error:', data.message || data.error);
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      console.log(' Tracking number fetched successfully');

      return data;
    } catch (error) {
      console.error(' Error fetching tracking number:', error.message);
      throw error;
    }
  }
}

module.exports = new ShopeeOrderService();
