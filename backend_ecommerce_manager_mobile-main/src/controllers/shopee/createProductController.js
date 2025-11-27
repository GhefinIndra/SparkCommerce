// src/controllers/shopee/createProductController.js

const authService = require('../../services/shopee/authService');
const categoryAPI = require('../../services/shopee/categoryAPI');
const logisticsAPI = require('../../services/shopee/logisticsAPI');
const productAPI = require('../../services/shopee/productAPI');

const createProductController = {
  /**
   * Get categories
   * GET /api/shopee/categories
   */
  getCategories: async (req, res) => {
    try {
      const { shop_id } = req.query;
      const { language = 'id' } = req.query; // Default to Indonesian

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      console.log(' Getting Shopee categories for shop:', shop_id);

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Get categories from Shopee API with Indonesian language
      const categoriesResponse = await categoryAPI.getCategories(
        token.access_token,
        shop_id,
        language
      );

      // DEBUG: Log raw response structure
      console.log(' DEBUG - Shopee API Response Structure:', {
        hasResponse: !!categoriesResponse.response,
        hasCategoryList: !!categoriesResponse.response?.category_list,
        categoryListType: Array.isArray(categoriesResponse.response?.category_list) ? 'array' : typeof categoriesResponse.response?.category_list,
        categoryListLength: categoriesResponse.response?.category_list?.length,
        responseKeys: categoriesResponse.response ? Object.keys(categoriesResponse.response) : [],
        hasError: !!categoriesResponse.error,
        errorMessage: categoriesResponse.message,
        fullResponse: JSON.stringify(categoriesResponse, null, 2), // Log full response
      });

      // Check if response is valid
      if (!categoriesResponse.response) {
        console.error(' No response from Shopee API');
        return res.status(500).json({
          success: false,
          message: 'Failed to get categories from Shopee',
          error: categoriesResponse.message || 'No response from Shopee API',
        });
      }

      if (!categoriesResponse.response.category_list) {
        console.error(' No category_list in response');
        return res.status(500).json({
          success: false,
          message: 'Invalid response from Shopee API',
          error: 'category_list not found in response',
        });
      }

      const categoryList = categoriesResponse.response.category_list || [];

      console.log(' Category list extracted:', {
        categoryCount: categoryList.length,
        firstCategory: categoryList[0] ? {
          id: categoryList[0].category_id,
          name: categoryList[0].display_category_name,
          parent: categoryList[0].parent_category_id,
        } : null,
      });

      // Build category tree
      const categoryTree = categoryAPI.buildCategoryTree(categoryList);

      console.log(' Categories retrieved successfully:', {
        total: categoryList.length,
        level1: categoryTree.level1.length,
        level2: categoryTree.level2.length,
        level3: categoryTree.level3.length,
      });

      res.status(200).json({
        success: true,
        message: 'Categories retrieved successfully',
        data: {
          categories: categoryList, // Flat list
          tree: categoryTree, // Organized tree
          total_count: categoryList.length,
        },
      });
    } catch (error) {
      console.error(' Error getting categories:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to get categories',
        error: error.message,
      });
    }
  },

  /**
   * Get category attributes
   * GET /api/shopee/categories/:categoryId/attributes
   */
  getCategoryAttributes: async (req, res) => {
    try {
      const { categoryId } = req.params;
      const { shop_id } = req.query;
      const { language = 'en' } = req.query;

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      if (!categoryId) {
        return res.status(400).json({
          success: false,
          message: 'Category ID is required',
        });
      }

      console.log('️ Getting Shopee category attributes:', {
        shop_id,
        categoryId,
        language,
      });

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Parse category ID to integer
      const categoryIdInt = parseInt(categoryId);
      if (isNaN(categoryIdInt)) {
        return res.status(400).json({
          success: false,
          message: 'Category ID must be a valid integer',
        });
      }

      // Get attributes from Shopee API
      // Use Indonesian language ('id') for Indonesia region
      const attributesResponse = await categoryAPI.getCategoryAttributes(
        token.access_token,
        shop_id,
        [categoryIdInt], // Array of category IDs
        'id' // Indonesian language
      );

      const resultList = attributesResponse.response?.list || [];
      const categoryAttributes = resultList.length > 0 ? resultList[0] : null;

      if (!categoryAttributes) {
        return res.status(404).json({
          success: false,
          message: 'No attributes found for this category',
        });
      }

      const attributeTree = categoryAttributes.attribute_tree || [];

      // Transform Shopee attribute structure to match TikTok format for frontend compatibility
      const transformedAttributes = attributeTree.map(attr => {
        // Map Shopee input_type to TikTok-like type string
        const inputTypeMap = {
          1: 'DROP_DOWN', // Single selection dropdown
          2: 'COMBO_BOX', // Dropdown with custom input support
          3: 'TEXT', // Text input
          4: 'MULTIPLE_SELECT', // Multiple selection
          5: 'MULTIPLE_SELECT', // Multiple selection dropdown
        };

        // Get attribute name (prefer Indonesian from multi_lang, fallback to English)
        const attrName = attr.multi_lang?.find(ml => ml.language === 'id')?.value
          || attr.multi_lang?.find(ml => ml.language === 'en')?.value
          || attr.name;

        // Transform attribute values
        const transformedValues = (attr.attribute_value_list || []).map(val => ({
          id: val.value_id?.toString() || '',
          name: val.multi_lang?.find(ml => ml.language === 'id')?.value
            || val.multi_lang?.find(ml => ml.language === 'en')?.value
            || val.name,
          value_unit: val.value_unit, // For attributes like Weight (g, kg)
        }));

        return {
          id: attr.attribute_id?.toString() || '',
          name: attrName,
          type: inputTypeMap[attr.attribute_info?.input_type] || 'TEXT',
          is_required: attr.mandatory || false,
          is_customizable: attr.attribute_info?.input_type === 2, // Combo box allows custom input
          is_multiple_selection: [4, 5].includes(attr.attribute_info?.input_type),
          values: transformedValues,
          input_type: attr.attribute_info?.input_type, // Keep original for reference
          input_validation_type: attr.attribute_info?.input_validation_type,
          format_type: attr.attribute_info?.format_type,
          attribute_unit_list: attr.attribute_info?.attribute_unit_list, // For combo box units
          date_format_type: attr.attribute_info?.date_format_type, // For date inputs
          max_value_count: attr.attribute_info?.max_value_count, // For multiple selection
        };
      });

      console.log(' Category attributes retrieved successfully:', {
        categoryId: categoryAttributes.category_id,
        attributeCount: transformedAttributes.length,
        mandatoryCount: transformedAttributes.filter(attr => attr.is_required).length,
      });

      res.status(200).json({
        success: true,
        message: 'Category attributes retrieved successfully',
        data: {
          category_id: categoryAttributes.category_id,
          attributes: transformedAttributes,
          total_count: transformedAttributes.length,
          mandatory_count: transformedAttributes.filter(attr => attr.is_required).length,
        },
      });
    } catch (error) {
      console.error(' Error getting category attributes:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to get category attributes',
        error: error.message,
      });
    }
  },

  /**
   * Get logistics channels
   * GET /api/shopee/logistics/channels
   */
  getLogisticsChannels: async (req, res) => {
    try {
      const { shop_id } = req.query;

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      console.log(' Getting Shopee logistics channels for shop:', shop_id);

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Get logistics channels
      const channelsResponse = await logisticsAPI.getChannelList(
        token.access_token,
        shop_id
      );

      const allChannels = channelsResponse.response?.logistics_channel_list || [];

      // Get enabled channels only
      const enabledChannels = await logisticsAPI.getEnabledChannels(
        token.access_token,
        shop_id
      );

      console.log(' Logistics channels retrieved successfully:', {
        total: allChannels.length,
        enabled: enabledChannels.length,
      });

      res.status(200).json({
        success: true,
        message: 'Logistics channels retrieved successfully',
        data: {
          all_channels: allChannels,
          enabled_channels: enabledChannels,
          total_count: allChannels.length,
          enabled_count: enabledChannels.length,
        },
      });
    } catch (error) {
      console.error(' Error getting logistics channels:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to get logistics channels',
        error: error.message,
      });
    }
  },

  /**
   * Create product
   * POST /api/shopee/shops/:shopId/products
   */
  createProduct: async (req, res) => {
    try {
      const { shopId } = req.params;
      const productData = req.body;

      console.log(' Creating Shopee product for shop:', shopId);
      console.log(' Product data keys:', Object.keys(productData));

      if (!shopId) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Validate required fields
      if (!productData.item_name || productData.item_name.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Item name is required',
        });
      }

      if (!productData.category_id) {
        return res.status(400).json({
          success: false,
          message: 'Category ID is required',
        });
      }

      if (!productData.description || productData.description.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Description is required',
        });
      }

      if (!productData.original_price || productData.original_price <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Original price is required and must be greater than 0',
        });
      }

      if (!productData.weight || productData.weight <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Weight is required and must be greater than 0',
        });
      }

      if (!productData.image || !productData.image.image_id_list || productData.image.image_id_list.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'At least one product image is required',
        });
      }

      // Get enabled logistics channels if not provided
      if (!productData.logistic_info || productData.logistic_info.length === 0) {
        console.log(' No logistic_info provided, fetching enabled channels...');

        const enabledChannels = await logisticsAPI.getEnabledChannels(
          token.access_token,
          shopId
        );

        if (enabledChannels.length === 0) {
          return res.status(400).json({
            success: false,
            message: 'No enabled logistics channels found. Please enable at least one logistics channel in your Shopee seller settings.',
          });
        }

        // Build logistic_info array
        productData.logistic_info = logisticsAPI.buildLogisticInfo(enabledChannels, productData);

        console.log(' Auto-populated logistic_info with', productData.logistic_info.length, 'channels');
      }

      // Set default stock if not provided
      if (!productData.seller_stock || productData.seller_stock.length === 0) {
        // Default stock to location_id = "" (default warehouse)
        const stock = parseInt(productData.stock) || 0;
        productData.seller_stock = [
          {
            location_id: '', // Empty string for default location
            stock: stock,
          },
        ];
        console.log(' Set default seller_stock:', productData.seller_stock);
      }

      // Set default item_status if not provided
      if (!productData.item_status) {
        productData.item_status = 'NORMAL'; // Default to NORMAL (active)
      }

      // Create product via Shopee API
      console.log(' Calling Shopee add_item API...');
      const result = await productAPI.createItem(
        token.access_token,
        shopId,
        productData
      );

      console.log(' Product created successfully:', {
        itemId: result.response?.item_id,
        itemStatus: result.response?.item_status,
      });

      res.status(200).json({
        success: true,
        message: 'Product created successfully',
        data: {
          item_id: result.response?.item_id,
          item_name: result.response?.item_name,
          item_status: result.response?.item_status,
          price_info: result.response?.price_info,
          images: result.response?.images,
          category_id: result.response?.category_id,
          logistic_info: result.response?.logistic_info,
          seller_stock: result.response?.seller_stock,
          // Add SKU mapping for auto-linking
          sku_mapping: {
            item_id: result.response?.item_id,
            marketplace: 'SHOPEE',
            seller_sku: productData.item_sku || '',
            stock: productData.seller_stock?.[0]?.stock || 0,
          },
        },
        warning: result.warning || null,
      });
    } catch (error) {
      console.error(' Error creating product:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to create product',
        error: error.message,
      });
    }
  },

  /**
   * Get brand list for category
   * GET /api/shopee/categories/:categoryId/brands
   */
  getBrandList: async (req, res) => {
    try {
      const { categoryId } = req.params;
      const { shop_id } = req.query;
      const { offset = 0, page_size = 100, status = 1, language = 'id' } = req.query; // Default to Indonesian

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      if (!categoryId) {
        return res.status(400).json({
          success: false,
          message: 'Category ID is required',
        });
      }

      console.log('️ Getting Shopee brand list:', {
        shop_id,
        categoryId,
        offset,
        page_size,
        status,
      });

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Parse category ID to integer
      const categoryIdInt = parseInt(categoryId);
      if (isNaN(categoryIdInt)) {
        return res.status(400).json({
          success: false,
          message: 'Category ID must be a valid integer',
        });
      }

      // Get brand list from Shopee API
      const brandListResponse = await categoryAPI.getBrandList(
        token.access_token,
        shop_id,
        categoryIdInt,
        parseInt(offset),
        parseInt(page_size),
        parseInt(status),
        language
      );

      const brandList = brandListResponse.response?.brand_list || [];
      const hasNextPage = brandListResponse.response?.has_next_page || false;
      const nextOffset = brandListResponse.response?.next_offset || 0;
      const isMandatory = brandListResponse.response?.is_mandatory || false;
      const inputType = brandListResponse.response?.input_type || 'DROP_DOWN';

      console.log(' Brand list retrieved successfully:', {
        brandCount: brandList.length,
        hasNextPage,
        isMandatory,
        inputType,
      });

      res.status(200).json({
        success: true,
        message: 'Brand list retrieved successfully',
        data: {
          brands: brandList,
          total_count: brandList.length,
          has_next_page: hasNextPage,
          next_offset: nextOffset,
          is_mandatory: isMandatory,
          input_type: inputType,
        },
      });
    } catch (error) {
      console.error(' Error getting brand list:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to get brand list',
        error: error.message,
      });
    }
  },

  /**
   * Register a new brand
   * POST /api/shopee/brands
   */
  registerBrand: async (req, res) => {
    try {
      const { shop_id } = req.body;
      const brandData = req.body;

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      console.log(' Registering new Shopee brand:', {
        shop_id,
        brandName: brandData.original_brand_name,
      });

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Validate required fields
      if (!brandData.original_brand_name || brandData.original_brand_name.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Brand name is required',
        });
      }

      if (!brandData.category_list || brandData.category_list.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'At least one category is required',
        });
      }

      if (!brandData.brand_region || brandData.brand_region.trim().length === 0) {
        return res.status(400).json({
          success: false,
          message: 'Brand region is required',
        });
      }

      if (!brandData.product_image || !brandData.product_image.image_id_list || brandData.product_image.image_id_list.length === 0) {
        return res.status(400).json({
          success: false,
          message: 'At least one product image is required',
        });
      }

      // Remove shop_id from brandData (not part of API request)
      const { shop_id: _, ...brandPayload } = brandData;

      // Register brand via Shopee API
      const result = await categoryAPI.registerBrand(
        token.access_token,
        shop_id,
        brandPayload
      );

      console.log(' Brand registered successfully:', {
        brandId: result.response?.brand_id,
        brandName: result.response?.original_brand_name,
      });

      res.status(200).json({
        success: true,
        message: 'Brand registered successfully',
        data: {
          brand_id: result.response?.brand_id,
          original_brand_name: result.response?.original_brand_name,
        },
        warning: result.warning || null,
      });
    } catch (error) {
      console.error(' Error registering brand:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to register brand',
        error: error.message,
      });
    }
  },

  /**
   * Get item limits and validation rules
   * GET /api/shopee/item-limits
   */
  getItemLimits: async (req, res) => {
    try {
      const { shop_id, category_id } = req.query;

      if (!shop_id) {
        return res.status(400).json({
          success: false,
          message: 'Shop ID is required',
        });
      }

      console.log(' Getting Shopee item limits:', {
        shop_id,
        category_id,
      });

      // Get valid token
      let token;
      try {
        token = await authService.getValidToken(shop_id);
      } catch (error) {
        console.error(' Failed to get valid token:', error.message);
        return res.status(401).json({
          success: false,
          message: 'Token expired. Please re-authenticate your Shopee shop.',
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: 'Invalid platform: This endpoint is for Shopee shops only',
        });
      }

      // Parse category ID if provided
      const categoryIdInt = category_id ? parseInt(category_id) : null;
      if (category_id && isNaN(categoryIdInt)) {
        return res.status(400).json({
          success: false,
          message: 'Category ID must be a valid integer',
        });
      }

      // Get item limits from Shopee API
      const limitsResponse = await categoryAPI.getItemLimit(
        token.access_token,
        shop_id,
        categoryIdInt
      );

      const limits = limitsResponse.response || {};

      console.log(' Item limits retrieved successfully:', {
        hasLimits: Object.keys(limits).length > 0,
      });

      res.status(200).json({
        success: true,
        message: 'Item limits retrieved successfully',
        data: limits,
      });
    } catch (error) {
      console.error(' Error getting item limits:', error);

      res.status(500).json({
        success: false,
        message: 'Failed to get item limits',
        error: error.message,
      });
    }
  },
};

module.exports = createProductController;
