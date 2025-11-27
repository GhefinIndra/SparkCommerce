// src/services/shopee/logisticsAPI.js
const axios = require('axios');
const config = require('../../config/env');
const { buildShopeeParams } = require('../../utils/shopeeSignature');

/**
 * Shopee Logistics API Service
 * Handles logistics-related API calls to Shopee
 */
class ShopeeLogisticsAPI {
  constructor() {
    this.baseUrl = config.shopee.apiUrl;
    this.partnerId = config.shopee.partnerId;
    this.partnerKey = config.shopee.partnerKey;
  }

  /**
   * Get all supported logistic channels
   * GET /api/v2/logistics/get_channel_list
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @returns {Promise<object>} Logistics channel list response
   */
  async getChannelList(accessToken, shopId) {
    try {
      console.log(' Shopee getChannelList request:', {
        shopId,
      });

      const apiPath = '/api/v2/logistics/get_channel_list';

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Build query params
      const queryParams = new URLSearchParams(params);
      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url.substring(0, 150) + '...');

      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee getChannelList response:', {
        hasError: !!response.data.error,
        channelCount: response.data.response?.logistics_channel_list?.length,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getChannelList error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get logistics channels from Shopee');
      }
      throw error;
    }
  }

  /**
   * Get enabled logistics channels for create product
   * Helper method to filter only enabled channels with appropriate settings
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @returns {Promise<Array>} Array of enabled logistics channels
   */
  async getEnabledChannels(accessToken, shopId) {
    try {
      const channelListResponse = await this.getChannelList(accessToken, shopId);
      const allChannels = channelListResponse.response?.logistics_channel_list || [];

      // Filter only enabled channels (enabled = true OR force_enable = true)
      const enabledChannels = allChannels.filter(channel => {
        return channel.enabled === true || channel.force_enable === true;
      });

      console.log(' Filtered enabled channels:', {
        total: allChannels.length,
        enabled: enabledChannels.length,
      });

      return enabledChannels;
    } catch (error) {
      console.error(' Error getting enabled channels:', error.message);
      throw error;
    }
  }

  /**
   * Build logistic_info array for add_item API
   * @param {Array} enabledChannels - Array of enabled logistics channels
   * @param {object} itemData - Item data (weight, dimensions)
   * @returns {Array} Formatted logistic_info array
   */
  buildLogisticInfo(enabledChannels, itemData = {}) {
    try {
      const logisticInfo = [];

      enabledChannels.forEach(channel => {
        const channelInfo = {
          logistic_id: channel.logistics_channel_id,
          enabled: true,
        };

        // Add size_id if fee_type is SIZE_SELECTION
        if (channel.fee_type === 'SIZE_SELECTION' && channel.size_list?.length > 0) {
          // Use first size as default
          channelInfo.size_id = parseInt(channel.size_list[0].size_id) || 0;
        } else {
          channelInfo.size_id = 0; // Default
        }

        // Check if COD is supported and add is_free if applicable
        // For now, we don't auto-enable free shipping
        channelInfo.is_free = false;

        // Note: shipping_fee is only needed when fee_type = CUSTOM_PRICE
        // We skip it for now as most channels are SIZE_INPUT or SIZE_SELECTION

        logisticInfo.push(channelInfo);
      });

      console.log(' Built logistic_info for', logisticInfo.length, 'channels');

      return logisticInfo;
    } catch (error) {
      console.error(' Error building logistic_info:', error.message);
      throw error;
    }
  }
}

module.exports = new ShopeeLogisticsAPI();
