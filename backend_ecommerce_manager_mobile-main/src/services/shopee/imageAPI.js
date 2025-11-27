// src/services/shopee/imageAPI.js
const axios = require('axios');
const FormData = require('form-data');
const config = require('../../config/env');
const { buildShopeeParams } = require('../../utils/shopeeSignature');

/**
 * Shopee Image/Media API Service
 * Handles image upload to Shopee
 */
class ShopeeImageAPI {
  constructor() {
    this.baseUrl = config.shopee.apiUrl;
    this.partnerId = config.shopee.partnerId;
    this.partnerKey = config.shopee.partnerKey;
  }

  /**
   * Upload single image to Shopee
   * POST /api/v2/media_space/upload_image
   * @param {string} accessToken - Shop access token (NOT USED, but kept for consistency)
   * @param {Buffer} imageBuffer - Image file buffer
   * @param {string} originalName - Original filename
   * @param {string} scene - Scene: 'normal' (product image) or 'desc' (description)
   * @param {string} ratio - Image ratio: '1:1' or '3:4'
   * @returns {Promise<object>} Upload result with image_id and image_url
   */
  async uploadImage(accessToken, imageBuffer, originalName, scene = 'normal', ratio = '1:1') {
    try {
      console.log(' Shopee uploadImage request:', {
        filename: originalName,
        size: imageBuffer.length,
        scene,
        ratio,
      });

      const apiPath = '/api/v2/media_space/upload_image';

      // Build signature params (NO access_token, NO shop_id for media_space API)
      const timestamp = Math.floor(Date.now() / 1000);
      const crypto = require('crypto');

      // Generate signature for media_space API
      // Format: partner_id + api_path + timestamp + partner_key
      const baseString = `${this.partnerId}${apiPath}${timestamp}`;
      const sign = crypto
        .createHmac('sha256', this.partnerKey)
        .update(baseString)
        .digest('hex');

      console.log(' Media Space Signature Debug:', {
        partnerId: this.partnerId,
        apiPath,
        timestamp,
        baseStringLength: baseString.length,
        signatureLength: sign.length,
      });

      // Build query params
      const queryParams = new URLSearchParams({
        partner_id: this.partnerId.toString(),
        timestamp: timestamp.toString(),
        sign: sign,
      });

      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      // Create form data
      const formData = new FormData();
      formData.append('image', imageBuffer, {
        filename: originalName,
        contentType: 'image/jpeg', // Default to JPEG, adjust if needed
      });

      // Add optional params
      if (scene) formData.append('scene', scene);
      if (ratio) formData.append('ratio', ratio);

      console.log(' Uploading to Shopee Media Space...');

      const response = await axios.post(url, formData, {
        timeout: 30000, // 30 seconds for upload
        headers: {
          ...formData.getHeaders(),
        },
        maxContentLength: Infinity,
        maxBodyLength: Infinity,
      });

      console.log(' Shopee uploadImage response:', {
        hasError: !!response.data.error,
        hasImageId: !!response.data.response?.image_info?.image_id,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      // Return formatted response
      const imageInfo = response.data.response?.image_info;
      if (!imageInfo || !imageInfo.image_id) {
        throw new Error('Invalid response: missing image_id');
      }

      return {
        image_id: imageInfo.image_id,
        image_url: imageInfo.image_url_list?.[0]?.image_url || '',
        success: true,
      };
    } catch (error) {
      console.error(' Shopee uploadImage error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to upload image to Shopee');
      }
      throw error;
    }
  }
}

module.exports = new ShopeeImageAPI();
