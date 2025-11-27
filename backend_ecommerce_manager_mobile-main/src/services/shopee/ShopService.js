// src/services/shopee/ShopService.js
const { buildShopeeParams, buildShopeeUrl } = require('../../utils/shopeeSignature');
const config = require('../../config/env');

class ShopService {
  constructor() {
    const { partnerId, partnerKey, apiUrl } = config.shopee;
    this.partnerId = partnerId;
    this.partnerKey = partnerKey;
    this.apiUrl = apiUrl;
  }

  /**
   * Get shop information from Shopee API
   * API Doc: v2.shop.get_shop_info
   *
   * @param {string} shopId - Shopee shop ID
   * @param {string} accessToken - Shop access token
   * @returns {Promise<Object>} Shop information
   */
  async getShopInfo(shopId, accessToken) {
    try {
      console.log(` Fetching Shopee shop info for shop_id: ${shopId}`);

      const apiPath = '/api/v2/shop/get_shop_info';

      // Build signature for Shop API
      // Signature base string: partner_id + api_path + timestamp + access_token + shop_id
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      const url = buildShopeeUrl(this.apiUrl, apiPath, params);

      console.log(' Calling Shopee get_shop_info API');

      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Shopee-API/1.0',
        },
      });

      const data = await response.json();

      console.log(' Shop Info Response:', {
        hasError: !!data.error,
        shopName: data.shop_name || 'N/A',
        region: data.region || 'N/A',
        status: data.status || 'N/A',
      });

      if (data.error) {
        throw new Error(`Shopee API Error: ${data.message || data.error}`);
      }

      // Return shop info sesuai response dari Shopee
      return {
        shop_id: shopId,
        shop_name: data.shop_name || `Shopee Shop ${shopId}`,
        region: data.region || '',
        status: data.status || 'NORMAL',
        is_cb: data.is_cb || false,
        is_sip: data.is_sip || false,
        auth_time: data.auth_time || null,
        expire_time: data.expire_time || null,
        merchant_id: data.merchant_id || null,
        shop_fulfillment_flag: data.shop_fulfillment_flag || '',
        is_main_shop: data.is_main_shop || false,
        is_direct_shop: data.is_direct_shop || false,
        is_mart_shop: data.is_mart_shop || false,
        is_outlet_shop: data.is_outlet_shop || false,
        request_id: data.request_id || '',
      };
    } catch (error) {
      console.error(' Error fetching Shopee shop info:', error.message);
      throw error;
    }
  }
}

module.exports = new ShopService();
