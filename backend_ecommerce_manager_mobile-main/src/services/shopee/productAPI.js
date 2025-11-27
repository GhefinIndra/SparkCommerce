// src/services/shopee/productAPI.js
const axios = require('axios');
const config = require('../../config/env');
const { buildShopeeParams, buildShopeeUrl } = require('../../utils/shopeeSignature');

/**
 * Shopee Product API Service
 * Handles all product-related API calls to Shopee
 */
class ShopeeProductAPI {
  constructor() {
    this.baseUrl = config.shopee.apiUrl;
    this.partnerId = config.shopee.partnerId;
    this.partnerKey = config.shopee.partnerKey;
  }

  /**
   * Get list of item IDs from Shopee (with retry mechanism)
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} offset - Starting entry (default: 0)
   * @param {number} pageSize - Page size (max: 100)
   * @param {string[]} itemStatus - Array of status filters (e.g., ['NORMAL'])
   * @param {number} updateTimeFrom - Optional: Filter by update time from
   * @param {number} updateTimeTo - Optional: Filter by update time to
   * @param {number} retryCount - Current retry attempt (internal use)
   * @returns {Promise<object>} Item list response
   */
  async getItemList(
    accessToken,
    shopId,
    offset = 0,
    pageSize = 20,
    itemStatus = ['NORMAL'],
    updateTimeFrom = null,
    updateTimeTo = null,
    retryCount = 0
  ) {
    const maxRetries = 2; // Total 3 attempts (initial + 2 retries)

    try {
      const apiPath = '/api/v2/product/get_item_list';

      console.log(' Shopee getItemList request:', {
        shopId,
        offset,
        pageSize,
        itemStatus,
      });

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Add additional query params
      params.offset = offset;
      params.page_size = pageSize;

      // Add item_status as multiple query params
      // Shopee expects: item_status=NORMAL&item_status=BANNED
      const queryParams = new URLSearchParams();
      Object.keys(params).forEach(key => {
        queryParams.append(key, params[key]);
      });

      itemStatus.forEach(status => {
        queryParams.append('item_status', status);
      });

      // Add optional time filters
      if (updateTimeFrom) {
        queryParams.append('update_time_from', updateTimeFrom);
      }
      if (updateTimeTo) {
        queryParams.append('update_time_to', updateTimeTo);
      }

      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url);

      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee getItemList response:', {
        hasError: !!response.data.error,
        totalCount: response.data.response?.total_count,
        itemCount: response.data.response?.item?.length,
        hasNextPage: response.data.response?.has_next_page,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        const errorCode = response.data.error;
        const errorMessage = response.data.message;

        // Check if error is retryable (server errors)
        const isRetryableError = errorCode.includes('error_server') ||
                                 errorCode.includes('error_system') ||
                                 errorCode.includes('error_inner');

        if (isRetryableError && retryCount < maxRetries) {
          const waitTime = Math.pow(2, retryCount) * 1000; // Exponential backoff: 1s, 2s, 4s
          console.warn(`️ Shopee API error (attempt ${retryCount + 1}/${maxRetries + 1}): ${errorCode}`);
          console.log(` Retrying in ${waitTime}ms...`);

          await new Promise(resolve => setTimeout(resolve, waitTime));

          // Retry the request
          return this.getItemList(
            accessToken,
            shopId,
            offset,
            pageSize,
            itemStatus,
            updateTimeFrom,
            updateTimeTo,
            retryCount + 1
          );
        }

        throw new Error(`Shopee API Error: ${errorCode} - ${errorMessage}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getItemList error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get item list from Shopee');
      }
      throw error;
    }
  }

  /**
   * Get detailed item info by item_id list
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number[]} itemIdList - Array of item IDs (max: 50)
   * @returns {Promise<object>} Item base info response
   */
  async getItemBaseInfo(accessToken, shopId, itemIdList) {
    try {
      const apiPath = '/api/v2/product/get_item_base_info';

      console.log(' Shopee getItemBaseInfo request:', {
        shopId,
        itemCount: itemIdList.length,
        itemIds: itemIdList,
      });

      // Validate item list size
      if (itemIdList.length > 50) {
        throw new Error('Item list exceeds maximum of 50 items per request');
      }

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Build query params
      const queryParams = new URLSearchParams();
      Object.keys(params).forEach(key => {
        queryParams.append(key, params[key]);
      });

      // Add item_id_list as comma-separated string (Shopee API expects this format)
      // Example: item_id_list=844107754,844107755,844107756
      queryParams.append('item_id_list', itemIdList.join(','));

      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url.substring(0, 150) + '...');

      const response = await axios.get(url, {
        timeout: 20000, // Longer timeout for batch request
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee getItemBaseInfo response:', {
        hasError: !!response.data.error,
        itemCount: response.data.response?.item_list?.length,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getItemBaseInfo error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get item base info from Shopee');
      }
      throw error;
    }
  }

  /**
   * Get model/variant list for a product
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @returns {Promise<object>} Model list response
   */
  async getModelList(accessToken, shopId, itemId) {
    try {
      const apiPath = '/api/v2/product/get_model_list';

      console.log(' Shopee getModelList request:', {
        shopId,
        itemId,
      });

      // Build signature params
      const params = buildShopeeParams(
        this.partnerId,
        apiPath,
        this.partnerKey,
        accessToken,
        shopId
      );

      // Build query params
      const queryParams = new URLSearchParams();
      Object.keys(params).forEach(key => {
        queryParams.append(key, params[key]);
      });

      queryParams.append('item_id', itemId);

      const url = `${this.baseUrl}${apiPath}?${queryParams.toString()}`;

      console.log(' Request URL:', url.substring(0, 150) + '...');

      const response = await axios.get(url, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee getModelList response:', {
        hasError: !!response.data.error,
        modelCount: response.data.response?.model?.length,
        variationCount: response.data.response?.tier_variation?.length,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee getModelList error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to get model list from Shopee');
      }
      throw error;
    }
  }

  /**
   * Get single product detail with models (if has_model = true)
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @returns {Promise<object>} Product detail with models
   */
  async getProductDetail(accessToken, shopId, itemId) {
    try {
      console.log(' Shopee getProductDetail (combined) request:', {
        shopId,
        itemId,
      });

      // Step 1: Get item base info
      const itemBaseInfoResponse = await this.getItemBaseInfo(
        accessToken,
        shopId,
        [itemId] // Single item as array
      );

      const itemList = itemBaseInfoResponse.response?.item_list || [];

      if (itemList.length === 0) {
        throw new Error('Product not found');
      }

      const product = itemList[0];

      // Step 2: Check if product has models/variants
      if (product.has_model) {
        console.log(' Product has models, fetching model list...');

        // Get model list
        const modelListResponse = await this.getModelList(
          accessToken,
          shopId,
          itemId
        );

        // Combine product base info with model list
        return {
          error: '',
          message: '',
          response: {
            ...product,
            models: modelListResponse.response?.model || [],
            tier_variation: modelListResponse.response?.tier_variation || [],
          },
        };
      } else {
        console.log(' Product has no models (single SKU)');

        // Return product without models
        return {
          error: '',
          message: '',
          response: product,
        };
      }
    } catch (error) {
      console.error(' Shopee getProductDetail (combined) error:', error.message);
      throw error;
    }
  }

  /**
   * Get products with full details (combines get_item_list + get_item_base_info)
   * This is the main method used by controller for product list
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} offset - Starting entry
   * @param {number} pageSize - Page size (max: 50 for efficiency)
   * @param {string[]} itemStatus - Status filter
   * @returns {Promise<object>} Combined response with full product details
   */
  async getProducts(
    accessToken,
    shopId,
    offset = 0,
    pageSize = 20,
    itemStatus = ['NORMAL']
  ) {
    try {
      console.log(' Shopee getProducts (combined) request:', {
        shopId,
        offset,
        pageSize,
        itemStatus,
      });

      // Step 1: Get item list (only item_id and status)
      const itemListResponse = await this.getItemList(
        accessToken,
        shopId,
        offset,
        pageSize,
        itemStatus
      );

      const items = itemListResponse.response?.item || [];

      if (items.length === 0) {
        console.log('️ No items found');
        return {
          error: '',
          message: '',
          response: {
            products: [],
            total_count: itemListResponse.response?.total_count || 0,
            has_next_page: false,
            next_offset: offset,
          },
        };
      }

      // Step 2: Extract item IDs
      const itemIds = items.map(item => item.item_id);

      console.log(` Found ${itemIds.length} items, fetching details...`);

      // Step 3: Get detailed info for all items (batch request)
      const itemBaseInfoResponse = await this.getItemBaseInfo(
        accessToken,
        shopId,
        itemIds
      );

      const itemDetails = itemBaseInfoResponse.response?.item_list || [];

      console.log(` Retrieved ${itemDetails.length} item details`);

      // Step 4: Combine data (merge status from list with details from base_info)
      const productsWithDetails = itemDetails.map(detail => {
        const listItem = items.find(item => item.item_id === detail.item_id);
        return {
          ...detail,
          update_time: listItem?.update_time || detail.update_time,
          tag: listItem?.tag || {},
        };
      });

      // Return combined response
      return {
        error: '',
        message: '',
        response: {
          products: productsWithDetails,
          total_count: itemListResponse.response?.total_count || 0,
          has_next_page: itemListResponse.response?.has_next_page || false,
          next_offset: itemListResponse.response?.next_offset || offset + pageSize,
        },
      };
    } catch (error) {
      console.error(' Shopee getProducts (combined) error:', error.message);
      throw error;
    }
  }

  /**
   * Update product price
   * POST /api/v2/product/update_price
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @param {Array} priceList - Array of {model_id, original_price}
   * @returns {Promise<object>} Update result with success/failure lists
   */
  async updatePrice(accessToken, shopId, itemId, priceList) {
    try {
      console.log(' Shopee updatePrice request:', {
        shopId,
        itemId,
        priceCount: priceList.length,
      });

      const apiPath = '/api/v2/product/update_price';

      // Build signature params using utility function
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
      const requestBody = {
        item_id: itemId,
        price_list: priceList.map(price => ({
          model_id: price.model_id || 0, // 0 for products without variants
          original_price: parseFloat(price.original_price),
        })),
      };

      console.log(' Update price request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee updatePrice response:', {
        hasError: !!response.data.error,
        successCount: response.data.response?.success_list?.length || 0,
        failureCount: response.data.response?.failure_list?.length || 0,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee updatePrice error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to update price on Shopee');
      }
      throw error;
    }
  }

  /**
   * Update product stock
   * POST /api/v2/product/update_stock
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @param {Array} stockList - Array of {model_id, seller_stock: [{location_id, stock}]}
   * @returns {Promise<object>} Update result with success/failure lists
   */
  async updateStock(accessToken, shopId, itemId, stockList) {
    try {
      console.log(' Shopee updateStock request:', {
        shopId,
        itemId,
        stockCount: stockList.length,
      });

      const apiPath = '/api/v2/product/update_stock';

      // Build signature params using utility function
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
      const requestBody = {
        item_id: itemId,
        stock_list: stockList.map(stock => ({
          model_id: stock.model_id || 0, // 0 for products without variants
          seller_stock: stock.seller_stock.map(loc => ({
            location_id: loc.location_id || '', // Empty string if no warehouse
            stock: parseInt(loc.stock),
          })),
        })),
      };

      console.log(' Update stock request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee updateStock response:', {
        hasError: !!response.data.error,
        successCount: response.data.response?.success_list?.length || 0,
        failureCount: response.data.response?.failure_list?.length || 0,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee updateStock error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to update stock on Shopee');
      }
      throw error;
    }
  }

  /**
   * Update product item (info, images, etc)
   * POST /api/v2/product/update_item
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @param {object} updateData - Update data (item_name, description, image, etc)
   * @returns {Promise<object>} Update result
   */
  async updateItem(accessToken, shopId, itemId, updateData) {
    try {
      console.log('️ Shopee updateItem request:', {
        shopId,
        itemId,
        updateFields: Object.keys(updateData),
      });

      const apiPath = '/api/v2/product/update_item';

      // Build signature params using utility function
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

      // Request body - merge item_id with updateData
      const requestBody = {
        item_id: itemId,
        ...updateData,
      };

      console.log(' Update item request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee updateItem response:', {
        hasError: !!response.data.error,
        itemId: response.data.response?.item_id,
        itemName: response.data.response?.item_name,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee updateItem error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to update item on Shopee');
      }
      throw error;
    }
  }

  /**
   * Delete product item
   * POST /api/v2/product/delete_item
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @returns {Promise<object>} Delete result
   */
  async deleteItem(accessToken, shopId, itemId) {
    try {
      console.log('️ Shopee deleteItem request:', {
        shopId,
        itemId,
      });

      const apiPath = '/api/v2/product/delete_item';

      // Build signature params using utility function
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
      const requestBody = {
        item_id: itemId,
      };

      console.log(' Delete item request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee deleteItem response:', {
        hasError: !!response.data.error,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee deleteItem error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to delete item on Shopee');
      }
      throw error;
    }
  }

  /**
   * Unlist/List product item (deactivate/activate)
   * POST /api/v2/product/unlist_item
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {number} itemId - Item ID
   * @param {boolean} unlist - true = unlist (deactivate), false = list (activate)
   * @returns {Promise<object>} Unlist result with success/failure lists
   */
  async unlistItem(accessToken, shopId, itemId, unlist = true) {
    try {
      console.log(' Shopee unlistItem request:', {
        shopId,
        itemId,
        unlist,
      });

      const apiPath = '/api/v2/product/unlist_item';

      // Build signature params using utility function
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

      // Request body - item_list supports batch (1-50 items)
      const requestBody = {
        item_list: [{
          item_id: itemId,
          unlist: unlist,
        }],
      };

      console.log(' Unlist item request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee unlistItem response:', {
        hasError: !!response.data.error,
        successCount: response.data.response?.success_list?.length || 0,
        failureCount: response.data.response?.failure_list?.length || 0,
      });

      // Check for Shopee API errors
      if (response.data.error) {
        throw new Error(`Shopee API Error: ${response.data.error} - ${response.data.message}`);
      }

      return response.data;
    } catch (error) {
      console.error(' Shopee unlistItem error:', error.message);
      if (error.response) {
        console.error('Response data:', error.response.data);
        throw new Error(error.response.data.message || 'Failed to unlist item on Shopee');
      }
      throw error;
    }
  }

  /**
   * Create new item/product
   * POST /api/v2/product/add_item
   * @param {string} accessToken - Shop access token
   * @param {string} shopId - Shop ID
   * @param {object} itemData - Item data for creation
   * @returns {Promise<object>} Create item result
   */
  async createItem(accessToken, shopId, itemData) {
    try {
      console.log(' Shopee createItem request:', {
        shopId,
        itemName: itemData.item_name,
        categoryId: itemData.category_id,
        price: itemData.original_price,
      });

      const apiPath = '/api/v2/product/add_item';

      // Build signature params using utility function
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
      const requestBody = itemData;

      console.log(' Create item request body keys:', Object.keys(requestBody));
      console.log(' Full request body:', JSON.stringify(requestBody, null, 2));

      const response = await axios.post(url, requestBody, {
        timeout: 30000, // 30 seconds for create product
        headers: {
          'Content-Type': 'application/json',
        },
      });

      console.log(' Shopee createItem response:', {
        hasError: !!response.data.error,
        hasWarning: !!response.data.warning,
        itemId: response.data.response?.item_id,
        itemStatus: response.data.response?.item_status,
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
      console.error(' Shopee createItem error:', error.message);
      if (error.response) {
        console.error('Response data:', JSON.stringify(error.response.data, null, 2));
        throw new Error(error.response.data.message || 'Failed to create item on Shopee');
      }
      throw error;
    }
  }
}

module.exports = new ShopeeProductAPI();
