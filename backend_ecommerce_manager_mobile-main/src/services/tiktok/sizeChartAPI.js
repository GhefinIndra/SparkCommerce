const axios = require("axios");
const config = require("../../config/env");
const { generateApiSignature } = require("../../utils/tiktokSignature");

class SizeChartAPI {
  constructor() {
    this.baseURL = config.tiktok.apiUrl;
    this.appKey = config.tiktok.appKey;
    this.appSecret = config.tiktok.appSecret;
  }

  /**
   * Search Size Charts - Get size chart templates for a seller
   * @param {Object} params - API parameters
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {number} params.page_size - Results per page (1-100, default: 20)
   * @param {string} params.page_token - Page token for pagination (optional)
   * @param {Array<string>} params.locales - Locale codes (optional, default: shop locale)
   * @param {Array<string>} params.ids - Filter by template IDs (optional, max 50)
   * @param {string} params.keyword - Filter by name/keyword (optional)
   */
  async searchSizeCharts(params) {
    try {
      const timestamp = Math.floor(Date.now() / 1000);

      const apiParams = {
        app_key: this.appKey,
        timestamp: timestamp,
        page_size: params.page_size || 20,
      };

      // Add optional parameters
      if (params.page_token) {
        apiParams.page_token = params.page_token;
      }

      if (params.locales && params.locales.length > 0) {
        apiParams.locales = params.locales;
      }

      // Prepare request body
      const requestBody = {};

      if (params.ids && params.ids.length > 0) {
        requestBody.ids = params.ids.slice(0, 50); // Max 50 IDs
      }

      if (params.keyword) {
        requestBody.keyword = params.keyword;
      }

      const endpoint = "/product/202407/sizecharts/search";
      const signature = generateApiSignature(
        endpoint,
        apiParams,
        JSON.stringify(requestBody),
        this.appSecret,
      );

      console.log(" Calling TikTok Size Charts Search API:", {
        endpoint,
        page_size: apiParams.page_size,
        has_keyword: !!params.keyword,
        has_ids: !!(params.ids && params.ids.length > 0),
      });

      const response = await axios.post(
        `${this.baseURL}${endpoint}`,
        requestBody,
        {
          headers: {
            "Content-Type": "application/json",
            "x-tts-access-token": params.access_token,
          },
          params: {
            ...apiParams,
            sign: signature,
          },
          timeout: 15000,
        },
      );

      console.log(" Size Charts Search API Response:", {
        code: response.data.code,
        message: response.data.message,
        size_charts_count: response.data.data?.size_chart?.length || 0,
        total_count: response.data.data?.total_count || 0,
        has_next_page: !!response.data.data?.next_page_token,
      });

      return response.data;
    } catch (error) {
      console.error(" Size Charts Search API Error:", {
        message: error.message,
        response: error.response?.data,
        status: error.response?.status,
      });
      throw error;
    }
  }

  /**
   * Get size charts with simplified parameters for frontend
   * @param {Object} params - Simplified parameters
   * @param {string} params.access_token - Shop access token
   * @param {string} params.shop_cipher - Shop cipher
   * @param {string} params.keyword - Search keyword (optional)
   * @param {number} params.limit - Max results (default: 50)
   */
  async getSizeChartTemplates(params) {
    try {
      console.log(
        " Getting size chart templates with keyword:",
        params.keyword || "none",
      );

      const searchParams = {
        access_token: params.access_token,
        shop_cipher: params.shop_cipher,
        page_size: Math.min(params.limit || 50, 100), // Max 100 per API docs
        locales: ["id-ID", "en-US"], // Support both locales
      };

      // Add keyword if provided
      if (params.keyword && params.keyword.trim()) {
        searchParams.keyword = params.keyword.trim();
      }

      const response = await this.searchSizeCharts(searchParams);

      if (response.code === 0) {
        const templates = response.data?.size_chart || [];

        // Process templates for frontend consumption
        const processedTemplates = templates.map((template) => {
          // Get the best image (prefer id-ID, fallback to en-US, then first available)
          let bestImage = null;
          if (template.images && template.images.length > 0) {
            bestImage =
              template.images.find((img) => img.locale === "id-ID") ||
              template.images.find((img) => img.locale === "en-US") ||
              template.images[0];
          }

          return {
            id: template.template_id,
            name: template.template_name,
            image: bestImage
              ? {
                  uri: bestImage.uri,
                  url: bestImage.url,
                  locale: bestImage.locale,
                }
              : null,
          };
        });

        console.log(" Processed size chart templates:", {
          total: processedTemplates.length,
          with_images: processedTemplates.filter((t) => t.image).length,
        });

        return {
          code: 0,
          message: "Success",
          data: {
            templates: processedTemplates,
            total_count: response.data.total_count || processedTemplates.length,
            next_page_token: response.data.next_page_token || null,
          },
        };
      } else {
        throw new Error(
          response.message || "Failed to get size chart templates",
        );
      }
    } catch (error) {
      console.error(" Error getting size chart templates:", error.message);
      throw error;
    }
  }

  /**
   * Validate if size chart is required for a category
   * This is a helper method that works with category rules
   * @param {Object} categoryRules - Category rules from getCategoryRules API
   * @returns {Object} Size chart validation info
   */
  validateSizeChartRequirement(categoryRules) {
    const sizeChartRule = categoryRules?.size_chart;

    return {
      is_supported: sizeChartRule?.is_supported || false,
      is_required: sizeChartRule?.is_required || false,
      message: sizeChartRule?.is_required
        ? "Size chart wajib untuk kategori ini"
        : sizeChartRule?.is_supported
          ? "Size chart opsional untuk kategori ini"
          : "Size chart tidak didukung untuk kategori ini",
    };
  }
}

module.exports = new SizeChartAPI();
