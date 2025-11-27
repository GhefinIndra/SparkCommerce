const axios = require("axios");
const config = require("../../config/env");
const { generateApiSignature } = require("../../utils/tiktokSignature");

class CategoryAPI {
  constructor() {
    this.baseURL = config.tiktok.apiUrl;
    this.appKey = config.tiktok.appKey;
    this.appSecret = config.tiktok.appSecret;
  }

  /**
   * Get TikTok Shop Categories Tree
   * @param {Object} params - API parameters
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {string} params.locale - Locale (default: 'id-ID')
   * @param {string} params.category_version - Category version (default: 'v1')
   * @param {string} params.listing_platform - Platform (default: 'TIKTOK_SHOP')
   * @param {string} params.keyword - Filter keyword (optional)
   * @param {boolean} params.include_prohibited_categories - Include prohibited categories (default: false)
   */
  async getCategories(params) {
    try {
      const timestamp = Math.floor(Date.now() / 1000);

      const apiParams = {
        app_key: this.appKey,
        shop_cipher: params.shop_cipher,
        timestamp: timestamp,
        locale: params.locale || "id-ID",
        category_version: params.category_version || "v1",
        listing_platform: params.listing_platform || "TIKTOK_SHOP",
        include_prohibited_categories:
          params.include_prohibited_categories || false,
      };

      // Add optional keyword filter
      if (params.keyword) {
        apiParams.keyword = params.keyword;
      }

      const endpoint = "/product/202309/categories";
      const signature = generateApiSignature(
        endpoint,
        apiParams,
        "",
        this.appSecret,
      );

      console.log(" Calling TikTok Categories API:", {
        endpoint,
        locale: apiParams.locale,
        category_version: apiParams.category_version,
      });

      const response = await axios.get(`${this.baseURL}${endpoint}`, {
        headers: {
          "Content-Type": "application/json",
          "x-tts-access-token": params.access_token,
        },
        params: {
          ...apiParams,
          sign: signature,
        },
        timeout: 15000,
      });

      console.log(" Categories API Response:", {
        code: response.data.code,
        message: response.data.message,
        categories_count: response.data.data?.categories?.length || 0,
      });

      return response.data;
    } catch (error) {
      console.error(" Categories API Error:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });
      throw error;
    }
  }

  /**
   * Get Category Rules - additional requirements for specific category
   * @param {Object} params - API parameters
   * @param {string} params.category_id - Category ID (must be leaf category)
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {string} params.locale - Locale (default: 'id-ID')
   * @param {string} params.category_version - Category version (default: 'v1')
   */
  async getCategoryRules(params) {
    try {
      const timestamp = Math.floor(Date.now() / 1000);

      const apiParams = {
        app_key: this.appKey,
        shop_cipher: params.shop_cipher,
        timestamp: timestamp,
        locale: params.locale || "id-ID",
        category_version: params.category_version || "v1",
      };

      const endpoint = `/product/202309/categories/${params.category_id}/rules`;
      const signature = generateApiSignature(
        endpoint,
        apiParams,
        "",
        this.appSecret,
      );

      console.log(" Calling TikTok Category Rules API:", {
        endpoint,
        category_id: params.category_id,
        locale: apiParams.locale,
      });

      const response = await axios.get(`${this.baseURL}${endpoint}`, {
        headers: {
          "Content-Type": "application/json",
          "x-tts-access-token": params.access_token,
        },
        params: {
          ...apiParams,
          sign: signature,
        },
        timeout: 15000,
      });

      console.log(" Category Rules API Response:", {
        code: response.data.code,
        message: response.data.message,
        has_certifications:
          response.data.data?.product_certifications?.length > 0,
        size_chart_required: response.data.data?.size_chart?.is_required,
        package_dimension_required:
          response.data.data?.package_dimension?.is_required,
      });

      // DEBUG: Log certification details including requirement_conditions
      if (response.data.data?.product_certifications?.length > 0) {
        console.log(" DEBUG - Product Certifications Detail:");
        response.data.data.product_certifications.forEach((cert, index) => {
          console.log(`   [${index}] ${cert.name}:`, {
            id: cert.id,
            is_required: cert.is_required,
            has_requirement_conditions: !!cert.requirement_conditions,
            requirement_conditions_count:
              cert.requirement_conditions?.length || 0,
            requirement_conditions: cert.requirement_conditions || "NONE",
          });
        });
      }

      return response.data;
    } catch (error) {
      console.error(" Category Rules API Error:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        category_id: params.category_id,
      });
      throw error;
    }
  }

  /**
   * Get Category Attributes - mandatory and optional attributes for specific category
   * @param {Object} params - API parameters
   * @param {string} params.category_id - Category ID (must be leaf category)
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {string} params.locale - Locale (default: 'id-ID')
   * @param {string} params.category_version - Category version (default: 'v1')
   */
  async getCategoryAttributes(params) {
    try {
      const timestamp = Math.floor(Date.now() / 1000);

      const apiParams = {
        app_key: this.appKey,
        shop_cipher: params.shop_cipher,
        timestamp: timestamp,
        locale: params.locale || "id-ID",
        category_version: params.category_version || "v1",
      };

      const endpoint = `/product/202309/categories/${params.category_id}/attributes`;
      const signature = generateApiSignature(
        endpoint,
        apiParams,
        "",
        this.appSecret,
      );

      console.log(" Calling TikTok Category Attributes API:", {
        endpoint,
        category_id: params.category_id,
        locale: apiParams.locale,
      });

      const response = await axios.get(`${this.baseURL}${endpoint}`, {
        headers: {
          "Content-Type": "application/json",
          "x-tts-access-token": params.access_token,
        },
        params: {
          ...apiParams,
          sign: signature,
        },
        timeout: 15000,
      });

      console.log(" Category Attributes API Response:", {
        code: response.data.code,
        message: response.data.message,
        attributes_count: response.data.data?.attributes?.length || 0,
        required_attributes:
          response.data.data?.attributes?.filter(
            (attr) => attr.is_requried === true,
          )?.length || 0,
      });

      return response.data;
    } catch (error) {
      console.error(" Category Attributes API Error:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
        category_id: params.category_id,
      });
      throw error;
    }
  }

  /**
   * Get complete category information (categories + rules + attributes)
   * Useful untuk fetch semua data yang dibutuhkan sekaligus
   * @param {Object} params - API parameters
   * @param {string} params.category_id - Category ID (must be leaf category)
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {string} params.locale - Locale (default: 'id-ID')
   * @param {string} params.category_version - Category version (default: 'v1')
   */
  async getCategoryComplete(params) {
    try {
      console.log(" Getting complete category info for:", params.category_id);

      // Call all APIs in parallel untuk performance
      const [rulesResponse, attributesResponse] = await Promise.all([
        this.getCategoryRules(params),
        this.getCategoryAttributes(params),
      ]);

      // Check if both APIs successful
      if (rulesResponse.code !== 0) {
        throw new Error(`Rules API failed: ${rulesResponse.message}`);
      }

      if (attributesResponse.code !== 0) {
        throw new Error(`Attributes API failed: ${attributesResponse.message}`);
      }

      console.log(" Complete category info retrieved successfully");

      return {
        code: 0,
        message: "Success",
        data: {
          category_id: params.category_id,
          rules: rulesResponse.data,
          attributes: attributesResponse.data,
        },
      };
    } catch (error) {
      console.error(" Get Complete Category Error:", {
        message: error.message,
        category_id: params.category_id,
      });
      throw error;
    }
  }
}

module.exports = new CategoryAPI();
