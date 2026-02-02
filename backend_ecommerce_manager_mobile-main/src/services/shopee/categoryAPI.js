// src/services/shopee/categoryAPI.js
const axios = require('axios');
const config = require('../../config/env');
const { buildShopeeParams } = require('../../utils/shopeeSignature');

// In-memory cache for categories (TTL: 1 hour)
const categoryCache = new Map();
const CACHE_TTL = 60 * 60 * 1000; // 1 hour in milliseconds
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds
const REQUEST_TIMEOUT = 30000; // 30 seconds (increased from 15s)

/**
 * Simple in-memory cache implementation
 */
function getCached(key) {
  const cached = categoryCache.get(key);
  if (!cached) return null;
  
  // Check if expired
  if (Date.now() > cached.expiry) {
    categoryCache.delete(key);
    return null;
  }
  
  return cached.data;
}

function setCached(key, data) {
  categoryCache.set(key, {
    data,
    expiry: Date.now() + CACHE_TTL
  });
}

/**
 * Sleep utility for retry delay
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Shopee Category API Service
 * Handles category and attribute-related API calls to Shopee
 * Features: Caching, Retry Logic, Extended Timeout
 */
class ShopeeCategoryAPI {
  constructor() {
    this.baseUrl = config.shopee.apiUrl;
    this.partnerId = config.shopee.partnerId;
    this.partnerKey = config.shopee.partnerKey;
  }

  /**
   * Get category tree with caching and retry logic
   * GET /api/v2/product/get_category
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {string} language - Language code (default: 'en')
   * @param {number} retryCount - Current retry attempt (internal use)
   * @returns {Promise<object>} Category list response
   */
  async getCategories(accessToken, shopId, language = 'en', retryCount = 0) {
    try {
      // Check cache first
      const cacheKey = `categories_${shopId}_${language}`;
      const cached = getCached(cacheKey);
      
      if (cached) {
        console.log('✅ Using cached categories for shop:', shopId);
        return cached;
      }

      console.log(' Shopee getCategories request:', {
        shopId,
        language,
        attempt: retryCount + 1,
        maxRetries: MAX_RETRIES,
      });

      const apiPath = '/api/v2/product/get_category';

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add language parameter
      params.language = language;

      // Build query params
      const queryParams = new URLSearchParams(params);
      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url.substring(0, 150) + '...');

      const response = await axios.get(url, {
        timeout: REQUEST_TIMEOUT,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      // Validate response
      if (!response || !response.data) {
        console.error(' Invalid response from Shopee API');
        throw new Error('No data received from Shopee API');
      }

      console.log(' Shopee getCategories response:', {
        hasError: !!response.data.error,
        hasResponse: !!response.data.response,
        categoryCount: response.data.response?.category_list?.length,
        statusCode: response.status,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        console.error(' Shopee API Error:', {
          error: response.data.error,
          message: response.data.message,
        });
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      // Ensure response object exists
      if (!response.data.response) {
        console.error(' No response object in Shopee API response');
        throw new Error('Invalid response structure from Shopee API');
      }

      // Cache successful response
      setCached(cacheKey, response.data);
      console.log('💾 Cached categories for shop:', shopId);

      return response.data;
      
    } catch (error) {
      // Handle timeout with retry logic
      if ((error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') && retryCount < MAX_RETRIES) {
        console.warn(`⚠️ Timeout on attempt ${retryCount + 1}/${MAX_RETRIES + 1}, retrying in ${RETRY_DELAY}ms...`);
        await sleep(RETRY_DELAY);
        return this.getCategories(accessToken, shopId, language, retryCount + 1);
      }

      console.error(' Shopee getCategories error:', error.message);
      
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get categories from Shopee');
      }
      
      // Provide helpful error message for timeout
      if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
        throw new Error('Request to Shopee API timed out after multiple retries. Please try again later.');
      }
      
      throw error;
    }
  }

  /**
   * Get category attribute tree with retry logic
   * GET /api/v2/product/get_attribute_tree
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number[]} categoryIdList - Array of category IDs (max 20)
   * @param {string} language - Language code (default: 'en')
   * @param {number} retryCount - Current retry attempt (internal use)
   * @returns {Promise<object>} Attribute tree response
   */
  async getCategoryAttributes(accessToken, shopId, categoryIdList, language = 'en', retryCount = 0) {
    try {
      console.log('️ Shopee getCategoryAttributes request:', {
        shopId,
        categoryIds: categoryIdList,
        language,
        attempt: retryCount + 1,
      });

      // Validate category list size
      if (categoryIdList.length > 20) {
        throw new Error('Category list exceeds maximum of 20 categories per request');
      }

      const apiPath = '/api/v2/product/get_attribute_tree';

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

      // Add category_id_list as comma-separated (Shopee API expects this format)
      queryParams.append('category_id_list', categoryIdList.join(','));

      // Add language
      queryParams.append('language', language);

      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url.substring(0, 150) + '...');

      const response = await axios.get(url, {
        timeout: REQUEST_TIMEOUT, // Use same timeout constant
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee getCategoryAttributes response:', {
        hasError: !!response.data.error,
        resultCount: response.data.response?.list?.length,
      });

      //  DEBUG: Log full response structure to understand data format
      console.log(' FULL RESPONSE STRUCTURE:', JSON.stringify(response.data, null, 2));

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
      
    } catch (error) {
      // Handle timeout with retry logic
      if ((error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') && retryCount < MAX_RETRIES) {
        console.warn(`⚠️ Attributes timeout on attempt ${retryCount + 1}/${MAX_RETRIES + 1}, retrying in ${RETRY_DELAY}ms...`);
        await sleep(RETRY_DELAY);
        return this.getCategoryAttributes(accessToken, shopId, categoryIdList, language, retryCount + 1);
      }

      console.error(' Shopee getCategoryAttributes error:', error.message);
      
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get category attributes from Shopee');
      }
      
      // Provide helpful error message for timeout
      if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
        throw new Error('Request to Shopee API timed out after multiple retries. Please try again later.');
      }
      
      throw error;
    }
  }

  /**
   * Build category tree from flat list
   * Helper method to organize categories into hierarchical structure
   * @param {Array} categoryList - Flat list of categories from API
   * @returns {object} Organized category tree
   */
  buildCategoryTree(categoryList) {
    try {
      console.log(' Building category tree from', categoryList.length, 'categories');

      // Create a map for quick lookup
      const categoryMap = new Map();
      categoryList.forEach(cat => {
        categoryMap.set(cat.category_id, {
          id: cat.category_id,
          parent_id: cat.parent_category_id,
          name: cat.display_category_name || cat.original_category_name,
          has_children: cat.has_children,
          children: [],
        });
      });

      // Build tree structure recursively
      const rootCategories = [];
      const levelCounts = {};

      categoryList.forEach(cat => {
        const node = categoryMap.get(cat.category_id);

        if (cat.parent_category_id === 0) {
          // Root level category
          rootCategories.push(node);
        } else {
          // Child category - attach to parent
          const parent = categoryMap.get(cat.parent_category_id);
          if (parent) {
            parent.children.push(node);
          }
        }
      });

      // Calculate depth and count categories by level
      const calculateDepth = (node, level = 1) => {
        if (!levelCounts[level]) levelCounts[level] = 0;
        levelCounts[level]++;

        if (node.children && node.children.length > 0) {
          node.children.forEach(child => calculateDepth(child, level + 1));
        }
      };

      rootCategories.forEach(root => calculateDepth(root));

      const maxDepth = Math.max(...Object.keys(levelCounts).map(Number));

      console.log(' Category tree built (dynamic depth):', {
        totalCategories: categoryList.length,
        maxDepth,
        levelCounts,
      });

      // For backward compatibility, extract flat lists by level
      const flattenByLevel = (nodes, targetLevel, currentLevel = 1) => {
        let result = [];
        nodes.forEach(node => {
          if (currentLevel === targetLevel) {
            result.push(node);
          }
          if (node.children && node.children.length > 0) {
            result = result.concat(flattenByLevel(node.children, targetLevel, currentLevel + 1));
          }
        });
        return result;
      };

      return {
        tree: rootCategories, // Full tree structure
        level1: rootCategories, // Root categories
        level2: flattenByLevel(rootCategories, 2),
        level3: flattenByLevel(rootCategories, 3),
        level4: flattenByLevel(rootCategories, 4),
        level5: flattenByLevel(rootCategories, 5),
        maxDepth,
        levelCounts,
        flat: categoryList,
      };
    } catch (error) {
      console.error(' Error building category tree:', error.message);
      throw error;
    }
  }

  /**
   * Get brand list for category
   * GET /api/v2/product/get_brand_list
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} categoryId - Category ID
   * @param {number} offset - Offset for pagination (default: 0)
   * @param {number} pageSize - Page size (default: 100, max: 100)
   * @param {number} status - Brand status (1: normal, 2: pending)
   * @param {string} language - Language code (default: 'en')
   * @returns {Promise<object>} Brand list response
   */
  async getBrandList(accessToken, shopId, categoryId, offset = 0, pageSize = 100, status = 1, language = 'en') {
    try {
      console.log('️ Shopee getBrandList request:', {
        shopId,
        categoryId,
        offset,
        pageSize,
        status,
      });

      const apiPath = '/api/v2/product/get_brand_list';

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add query parameters
      params.offset = offset;
      params.page_size = pageSize;
      params.category_id = categoryId;
      params.status = status;
      params.language = language;

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

      console.log(' Shopee getBrandList response:', {
        hasError: !!response.data.error,
        brandCount: response.data.response?.brand_list?.length,
        hasNextPage: response.data.response?.has_next_page,
        isMandatory: response.data.response?.is_mandatory,
        inputType: response.data.response?.input_type,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getBrandList error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get brand list from Shopee');
      }
      throw error;
    }
  }

  /**
   * Register a new brand
   * POST /api/v2/product/register_brand
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {object} brandData - Brand registration data
   * @returns {Promise<object>} Register brand response
   */
  async registerBrand(accessToken, shopId, brandData) {
    try {
      console.log(' Shopee registerBrand request:', {
        shopId,
        brandName: brandData.original_brand_name,
        categoryCount: brandData.category_list?.length,
      });

      const apiPath = '/api/v2/product/register_brand';

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

      // Request body
      const requestBody = brandData;

      console.log(' Register brand request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 20000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee registerBrand response:', {
        hasError: !!response.data.error,
        hasWarning: !!response.data.warning,
        brandId: response.data.response?.brand_id,
        brandName: response.data.response?.original_brand_name,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      // Log warnings if any
      if (response.data.warning) {
        console.warn('️ Shopee API Warning:', response.data.warning);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee registerBrand error:', error.message);
      if (error.response) {
        console.error('Response data:', JSON.stringify(error.response.data, null, 2));
        throw new Error(error.response.data.message || 'Failed to register brand on Shopee');
      }
      throw error;
    }
  }

  /**
   * Get item limits and validation rules
   * GET /api/v2/product/get_item_limit
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} categoryId - Category ID (optional)
   * @returns {Promise<object>} Item limit response
   */
  async getItemLimit(accessToken, shopId, categoryId = null) {
    try {
      console.log(' Shopee getItemLimit request:', {
        shopId,
        categoryId,
      });

      const apiPath = '/api/v2/product/get_item_limit';

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add category_id if provided
      if (categoryId !== null) {
        params.category_id = categoryId;
      }

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

      console.log(' Shopee getItemLimit response:', {
        status: response.status,
        hasError: !!response.data?.error,
        hasLimits: !!response.data?.response,
        hasData: !!response.data,
      });

      // Check for Shopee API errors
      if (response.data?.error) {
        console.error(' Shopee API returned error:', {
          error: response.data.error,
          message: response.data.message,
        });
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getItemLimit error:', {
        message: error.message,
        status: error.response?.status,
        statusText: error.response?.statusText,
        hasResponseData: !!error.response?.data,
        responseData: error.response?.data,
      });

      if (error.response) {
        const errorMsg = error.response.data?.message || error.response.data?.error || 'Failed to get item limit from Shopee';
        throw new Error(errorMsg);
      }
      throw error;
    }
  }
}

module.exports = new ShopeeCategoryAPI();
