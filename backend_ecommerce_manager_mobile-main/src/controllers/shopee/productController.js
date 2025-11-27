// src/controllers/shopee/productController.js
const Token = require("../../models/Token");
const productApi = require("../../services/shopee/productAPI");
const authService = require("../../services/shopee/authService");

class ShopeeProductController {
  /**
   * Get products for specific Shopee shop
   * GET /api/shopee/shops/:shopId/products
   */
  async getProducts(req, res) {
    const { shopId } = req.params; // Declare outside try for access in catch

    try {
      const {
        offset = 0,
        page_size = 20,
        item_status = 'NORMAL' // Can be comma-separated: "NORMAL,UNLIST"
      } = req.query;

      console.log(`️ Getting Shopee products for shop: ${shopId}`);
      console.log('Query params:', { offset, page_size, item_status });

      // Get token from database (with auto-refresh if expired)
      let token; // Declare here for access in outer catch block
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);

        if (error.message.includes("Re-authentication required")) {
          return res.status(401).json({
            success: false,
            message: "Token expired and refresh failed. Please re-authenticate your Shopee shop.",
            code: "TOKEN_EXPIRED_REAUTH_REQUIRED",
          });
        }

        return res.status(404).json({
          success: false,
          message: error.message || "Shop not found or token invalid",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      console.log(" Using Shopee access token for shop:", shopId);
      console.log(" Token details:", {
        platform: token.platform,
        shop_id: token.shop_id,
        access_token_length: token.access_token?.length,
        access_token_sample: token.access_token?.substring(0, 20) + '...',
        access_token_type: typeof token.access_token,
        refresh_token_exists: !!token.refresh_token,
        expire_at: token.expire_at,
        is_expired: new Date() > new Date(token.expire_at),
      });

      // Parse item_status (support comma-separated values)
      const statusArray = item_status.split(',').map(s => s.trim().toUpperCase());

      // Validate page_size (max 50 for efficiency with batch API call)
      const validPageSize = Math.min(parseInt(page_size), 50);

      // Call Shopee API (combined: get_item_list + get_item_base_info)
      const productsResponse = await productApi.getProducts(
        token.access_token,
        shopId,
        parseInt(offset),
        validPageSize,
        statusArray
      );

      if (productsResponse.error) {
        throw new Error(productsResponse.message || "Failed to fetch products from Shopee");
      }

      // Format products for mobile display (similar to TikTok format)
      const formattedProducts = (productsResponse.response?.products || []).map(
        (product) => {
          // Get price (handle case where product has models vs no models)
          let price = "0";
          let currency = "IDR";

          if (product.price_info && product.price_info.length > 0) {
            price = product.price_info[0].current_price?.toString() || "0";
            currency = product.price_info[0].currency || "IDR";
          }

          // Get stock (new stock_info_v2 format)
          let stock = 0;
          if (product.stock_info_v2?.summary_info?.total_available_stock !== undefined) {
            stock = product.stock_info_v2.summary_info.total_available_stock;
          }

          // Get main image
          let mainImage = "";
          if (product.image?.image_url_list && product.image.image_url_list.length > 0) {
            mainImage = product.image.image_url_list[0];
          }

          // Format timestamps
          const createdAt = product.create_time
            ? new Date(product.create_time * 1000).toLocaleDateString("id-ID")
            : "";
          const updatedAt = product.update_time
            ? new Date(product.update_time * 1000).toLocaleDateString("id-ID")
            : "";

          return {
            id: product.item_id.toString(),
            title: product.item_name || "Untitled Product",
            description: product.description || "",
            status: product.item_status || "UNKNOWN",
            mainImage,
            price,
            currency,
            stock,
            skuCount: product.has_model ? 1 : 0, // Will be updated when we implement model API
            createdAt,
            updatedAt,
          };
        }
      );

      // Return formatted response (similar to TikTok response structure)
      res.status(200).json({
        success: true,
        message: "Products retrieved successfully",
        data: {
          products: formattedProducts,
          totalCount: productsResponse.response?.total_count || 0,
          hasNextPage: productsResponse.response?.has_next_page || false,
          nextOffset: productsResponse.response?.next_offset || parseInt(offset) + validPageSize,
          shop: {
            id: shopId,
            name: token.shop_name || `Shop ${shopId}`,
            platform: "Shopee",
          },
        },
      });
    } catch (error) {
      console.error(
        ` Error getting Shopee products for ${req.params.shopId}:`,
        error
      );

      // Check if it's a Shopee API server error (sandbox instability)
      const isShopeeServerError = error.message.includes('error_server') ||
                                   error.message.includes('error_system') ||
                                   error.message.includes('Internal error');

      if (isShopeeServerError) {
        // Return empty list instead of error for better UX
        console.warn('️ Shopee sandbox unstable, returning empty list');
        return res.status(200).json({
          success: true,
          message: "Shopee API temporarily unavailable. Please try again later.",
          data: {
            products: [],
            totalCount: 0,
            hasNextPage: false,
            nextOffset: 0,
            shop: {
              id: shopId,
              name: token.shop_name || `Shop ${shopId}`,
              platform: "Shopee",
            },
          },
          warning: "Shopee sandbox environment is experiencing issues. This is normal for sandbox.",
        });
      }

      res.status(500).json({
        success: false,
        message: "Failed to retrieve products",
        error: error.message,
      });
    }
  }

  /**
   * Get product detail
   * GET /api/shopee/shops/:shopId/products/:productId
   */
  async getProductDetail(req, res) {
    const { shopId, productId } = req.params;

    try {
      console.log(` Getting Shopee product detail for shop: ${shopId}, product: ${productId}`);

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);

        if (error.message.includes("Re-authentication required")) {
          return res.status(401).json({
            success: false,
            message: "Token expired and refresh failed. Please re-authenticate your Shopee shop.",
            code: "TOKEN_EXPIRED_REAUTH_REQUIRED",
          });
        }

        return res.status(404).json({
          success: false,
          message: error.message || "Shop not found or token invalid",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      console.log(" Using Shopee access token for product detail");

      // Call Shopee API (get_item_base_info + get_model_list if needed)
      const productResponse = await productApi.getProductDetail(
        token.access_token,
        shopId,
        parseInt(productId)
      );

      if (productResponse.error) {
        throw new Error(productResponse.message || "Failed to fetch product detail from Shopee");
      }

      const product = productResponse.response;

      console.log(' Product data:', {
        item_id: product.item_id,
        item_name: product.item_name,
        description: product.description || '(empty)',
        has_model: product.has_model,
        model_count: product.models?.length || 0,
      });

      // Format product detail untuk mobile (similar to TikTok format)
      const formattedProduct = {
        id: product.item_id?.toString() || productId,
        title: product.item_name || "Untitled Product",
        description: product.description || "",
        status: product.item_status || "UNKNOWN",

        //  Main Images
        main_images: (product.image?.image_url_list || []).map((url, index) => ({
          url: url,
          thumb: url, // Shopee doesn't provide separate thumb, use same URL
          uri: product.image?.image_id_list?.[index] || '',
          width: 0,
          height: 0,
        })),

        //  Category (simplified - Shopee returns category_id, not full chain)
        category_chains: product.category_id ? [{
          id: product.category_id.toString(),
          parent_id: null,
          local_name: `Category ${product.category_id}`,
          is_leaf: true,
        }] : [],

        //  Brand
        brand: product.brand ? {
          id: product.brand.brand_id?.toString() || '',
          name: product.brand.original_brand_name || '',
        } : null,

        //  Package Info
        package_dimensions: product.dimension ? {
          length: product.dimension.package_length?.toString() || '0',
          width: product.dimension.package_width?.toString() || '0',
          height: product.dimension.package_height?.toString() || '0',
          unit: 'CENTIMETER',
        } : null,

        package_weight: product.weight ? {
          value: product.weight,
          unit: 'KILOGRAM',
        } : null,

        //  SKUs (handle both has_model and no model cases)
        skus: product.has_model && product.models ?
          // Product has variants/models
          product.models.map((model) => ({
            id: model.model_id?.toString() || '',
            seller_sku: model.model_sku || '',
            price: {
              amount: model.price_info?.[0]?.current_price?.toString() || '0',
              currency: model.price_info?.[0]?.currency || 'IDR',
              salePrice: model.price_info?.[0]?.current_price?.toString() || '0',
            },
            stock: model.stock_info_v2?.summary_info?.total_available_stock || 0,
            warehouse_id: model.stock_info_v2?.seller_stock?.[0]?.location_id || '',
            attributes: (model.tier_index || []).map((tierIdx, idx) => {
              const variation = product.tier_variation?.[idx];
              const option = variation?.option_list?.[tierIdx];
              return {
                id: variation?.name || `attr_${idx}`,
                name: variation?.name || '',
                value_id: tierIdx.toString(),
                value_name: option?.option || '',
              };
            }),
          }))
          :
          // Product has no variants (single SKU)
          [{
            id: product.item_id?.toString() || productId,
            seller_sku: product.item_sku || '',
            price: {
              amount: product.price_info?.[0]?.current_price?.toString() || '0',
              currency: product.price_info?.[0]?.currency || 'IDR',
              salePrice: product.price_info?.[0]?.current_price?.toString() || '0',
            },
            stock: product.stock_info_v2?.summary_info?.total_available_stock || 0,
            warehouse_id: product.stock_info_v2?.seller_stock?.[0]?.location_id || '',
            attributes: [],
          }],

        //  Boolean Flags
        is_cod_allowed: product.condition === 'NEW', // Shopee uses 'condition' not is_cod_allowed
        is_not_for_sale: false,
        is_pre_owned: product.condition === 'USED',
        is_replicated: false,
        has_draft: false,

        //  Additional Fields
        minimum_order_quantity: 1,
        external_product_id: product.item_id?.toString() || productId,
        product_types: [],
        shipping_insurance_requirement: null,
        product_status: product.item_status,

        //  Product Attributes (dari attribute_list di Shopee)
        product_attributes: (product.attribute_list || []).map((attr) => ({
          id: attr.attribute_id?.toString() || '',
          name: attr.original_attribute_name || '',
          values: (attr.attribute_value_list || []).map((val) => ({
            id: val.value_id?.toString() || '',
            name: val.original_value_name || '',
          })),
        })),

        //  Timestamps
        create_time: product.create_time,
        update_time: product.update_time,
        createdAt: product.create_time
          ? new Date(product.create_time * 1000).toISOString()
          : "",
        updatedAt: product.update_time
          ? new Date(product.update_time * 1000).toISOString()
          : "",
      };

      console.log(' Formatted product detail:', {
        id: formattedProduct.id,
        title: formattedProduct.title,
        images_count: formattedProduct.main_images.length,
        skus_count: formattedProduct.skus.length,
      });

      res.status(200).json({
        success: true,
        message: "Product detail retrieved successfully",
        data: formattedProduct,
      });
    } catch (error) {
      console.error(" Error getting Shopee product detail:", error);

      // Check if it's a Shopee API server error (sandbox instability)
      const isShopeeServerError = error.message.includes('error_server') ||
                                   error.message.includes('error_system') ||
                                   error.message.includes('Internal error');

      if (isShopeeServerError) {
        return res.status(503).json({
          success: false,
          message: "Shopee API temporarily unavailable. Please try again later.",
          error: error.message,
          warning: "Shopee sandbox environment is experiencing issues.",
        });
      }

      res.status(500).json({
        success: false,
        message: "Failed to retrieve product detail",
        error: error.message,
      });
    }
  }

  /**
   * Update product price
   * PUT /api/shopee/shops/:shopId/products/:productId/price
   */
  async updatePrice(req, res) {
    const { shopId, productId } = req.params;
    const { skus } = req.body; // Array of {id, price: {amount}}

    try {
      console.log(` Updating Shopee product price for shop: ${shopId}, product: ${productId}`);
      console.log(' SKUs to update:', JSON.stringify(skus, null, 2));

      // Validate request
      if (!skus || !Array.isArray(skus) || skus.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Invalid request: skus array is required",
        });
      }

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      // Transform frontend SKU format to Shopee API format
      const priceList = skus.map(sku => {
        // For products without variants, sku.id equals productId, so model_id should be 0
        // For products with variants, sku.id is the actual model_id
        const modelId = sku.id === productId ? 0 : parseInt(sku.id);

        return {
          model_id: modelId,
          original_price: parseFloat(sku.price.amount),
        };
      });

      console.log(' Shopee price_list:', JSON.stringify(priceList, null, 2));

      // Call Shopee API
      const updateResponse = await productApi.updatePrice(
        token.access_token,
        shopId,
        parseInt(productId),
        priceList
      );

      // Check for partial failures
      const successList = updateResponse.response?.success_list || [];
      const failureList = updateResponse.response?.failure_list || [];

      console.log(` Update price result: ${successList.length} success, ${failureList.length} failed`);

      if (failureList.length > 0) {
        console.warn('️ Some SKUs failed to update:', failureList);

        // Return partial success with details
        return res.status(200).json({
          success: true,
          message: `Price updated for ${successList.length} SKU(s). ${failureList.length} SKU(s) failed.`,
          data: {
            success_count: successList.length,
            failure_count: failureList.length,
            failures: failureList.map(f => ({
              model_id: f.model_id,
              reason: f.failed_reason,
            })),
          },
          warning: failureList.length > 0 ? "Some items failed to update" : null,
        });
      }

      res.status(200).json({
        success: true,
        message: "Price updated successfully",
        data: {
          success_count: successList.length,
          updated_skus: successList,
        },
      });
    } catch (error) {
      console.error(" Error updating Shopee product price:", error);

      res.status(500).json({
        success: false,
        message: "Failed to update product price",
        error: error.message,
      });
    }
  }

  /**
   * Update product stock
   * PUT /api/shopee/shops/:shopId/products/:productId/stock
   */
  async updateStock(req, res) {
    const { shopId, productId } = req.params;
    const { skus } = req.body; // Array of {id, warehouse_id, available_stock or quantity}

    try {
      console.log(` Updating Shopee product stock for shop: ${shopId}, product: ${productId}`);
      console.log(' SKUs to update:', JSON.stringify(skus, null, 2));

      // Validate request
      if (!skus || !Array.isArray(skus) || skus.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Invalid request: skus array is required",
        });
      }

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      // Transform frontend SKU format to Shopee API format
      const stockList = skus.map(sku => {
        const stock = sku.available_stock || sku.quantity || sku.stock || 0;
        const locationId = sku.warehouse_id || ''; // Use warehouse_id from frontend or empty string

        // For products without variants, sku.id equals productId, so model_id should be 0
        // For products with variants, sku.id is the actual model_id
        const modelId = sku.id === productId ? 0 : parseInt(sku.id);

        return {
          model_id: modelId,
          seller_stock: [{
            location_id: locationId,
            stock: parseInt(stock),
          }],
        };
      });

      console.log(' Shopee stock_list:', JSON.stringify(stockList, null, 2));

      // Call Shopee API
      const updateResponse = await productApi.updateStock(
        token.access_token,
        shopId,
        parseInt(productId),
        stockList
      );

      // Check for partial failures
      const successList = updateResponse.response?.success_list || [];
      const failureList = updateResponse.response?.failure_list || [];

      console.log(` Update stock result: ${successList.length} success, ${failureList.length} failed`);

      if (failureList.length > 0) {
        console.warn('️ Some SKUs failed to update:', failureList);

        // Return partial success with details
        return res.status(200).json({
          success: true,
          message: `Stock updated for ${successList.length} SKU(s). ${failureList.length} SKU(s) failed.`,
          data: {
            success_count: successList.length,
            failure_count: failureList.length,
            failures: failureList.map(f => ({
              model_id: f.model_id,
              reason: f.failed_reason,
            })),
          },
          warning: failureList.length > 0 ? "Some items failed to update" : null,
        });
      }

      res.status(200).json({
        success: true,
        message: "Stock updated successfully",
        data: {
          success_count: successList.length,
          updated_skus: successList,
        },
      });
    } catch (error) {
      console.error(" Error updating Shopee product stock:", error);

      res.status(500).json({
        success: false,
        message: "Failed to update product stock",
        error: error.message,
      });
    }
  }

  /**
   * Update product info (title, description)
   * PUT /api/shopee/shops/:shopId/products/:productId/info
   */
  async updateInfo(req, res) {
    const { shopId, productId } = req.params;
    const { title, description } = req.body;

    try {
      console.log(`️ Updating Shopee product info for shop: ${shopId}, product: ${productId}`);
      console.log(' Update data:', { title, description });

      // Validate request
      if (!title && !description) {
        return res.status(400).json({
          success: false,
          message: "At least one field (title or description) is required",
        });
      }

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      // Build update data
      const updateData = {};
      if (title) updateData.item_name = title;
      if (description) {
        updateData.description = description;
        // IMPORTANT: Set description_type to "normal" when updating description
        // This tells Shopee to use simple text description (not extended description with images)
        updateData.description_type = "normal";
      }

      console.log(' Shopee update data:', JSON.stringify(updateData, null, 2));

      // Call Shopee API
      const updateResponse = await productApi.updateItem(
        token.access_token,
        shopId,
        parseInt(productId),
        updateData
      );

      console.log(' Update info successful');

      res.status(200).json({
        success: true,
        message: "Product info updated successfully",
        data: {
          item_id: updateResponse.response?.item_id,
          item_name: updateResponse.response?.item_name,
          description: updateResponse.response?.description,
        },
      });
    } catch (error) {
      console.error(" Error updating Shopee product info:", error);

      res.status(500).json({
        success: false,
        message: "Failed to update product info",
        error: error.message,
      });
    }
  }

  /**
   * Update product images
   * PUT /api/shopee/shops/:shopId/products/:productId/images
   */
  async updateImages(req, res) {
    const { shopId, productId } = req.params;
    const { image_ids } = req.body; // Array of image IDs

    try {
      console.log(`️ Updating Shopee product images for shop: ${shopId}, product: ${productId}`);
      console.log(' Image IDs:', image_ids);

      // Validate request
      if (!image_ids || !Array.isArray(image_ids) || image_ids.length === 0) {
        return res.status(400).json({
          success: false,
          message: "image_ids array is required and must not be empty",
        });
      }

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      // Build update data for images
      const updateData = {
        image: {
          image_id_list: image_ids,
        },
      };

      console.log(' Shopee update images data:', JSON.stringify(updateData, null, 2));

      // Call Shopee API
      const updateResponse = await productApi.updateItem(
        token.access_token,
        shopId,
        parseInt(productId),
        updateData
      );

      console.log(' Update images successful');

      res.status(200).json({
        success: true,
        message: "Product images updated successfully",
        data: {
          item_id: updateResponse.response?.item_id,
          images: updateResponse.response?.images,
        },
      });
    } catch (error) {
      console.error(" Error updating Shopee product images:", error);

      res.status(500).json({
        success: false,
        message: "Failed to update product images",
        error: error.message,
      });
    }
  }

  /**
   * Delete product (permanent deletion)
   * DELETE /api/shopee/shops/:shopId/products/:productId
   */
  async deleteProduct(req, res) {
    const { shopId, productId } = req.params;

    try {
      console.log(`️ Deleting Shopee product for shop: ${shopId}, product: ${productId}`);

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      console.log(" Using Shopee access token for product deletion");

      // Call Shopee API to delete item
      const deleteResponse = await productApi.deleteItem(
        token.access_token,
        shopId,
        parseInt(productId)
      );

      // Check for API errors
      if (deleteResponse.error) {
        throw new Error(`Shopee API Error: ${deleteResponse.error} - ${deleteResponse.message}`);
      }

      console.log(' Product deleted successfully');

      res.status(200).json({
        success: true,
        message: "Product deleted successfully",
        data: {
          item_id: productId,
          deleted: true,
        },
      });
    } catch (error) {
      console.error(" Error deleting Shopee product:", error);

      // Check if product is already deleted or not found
      if (error.message.includes('error_item_not_exist') ||
          error.message.includes('not found') ||
          error.message.includes('error_param')) {
        return res.status(404).json({
          success: false,
          message: "Product not found or invalid item ID",
          error: error.message,
        });
      }

      res.status(500).json({
        success: false,
        message: "Failed to delete product",
        error: error.message,
      });
    }
  }

  /**
   * Unlist/List product (deactivate/activate)
   * PUT /api/shopee/shops/:shopId/products/:productId/unlist
   * Body: { unlist: true } to deactivate, { unlist: false } to activate
   */
  async unlistProduct(req, res) {
    const { shopId, productId } = req.params;
    const { unlist = true } = req.body; // Default to unlist (deactivate)

    try {
      console.log(` ${unlist ? 'Unlisting' : 'Listing'} Shopee product for shop: ${shopId}, product: ${productId}`);

      // Get token from database (with auto-refresh if expired)
      let token;
      try {
        token = await authService.getValidToken(shopId);
      } catch (error) {
        console.error(" Failed to get valid token:", error.message);
        return res.status(401).json({
          success: false,
          message: "Token expired. Please re-authenticate your Shopee shop.",
        });
      }

      // Verify this is a Shopee token
      if (!token.platform || token.platform !== 'shopee') {
        return res.status(400).json({
          success: false,
          message: "Invalid platform: This endpoint is for Shopee shops only",
        });
      }

      console.log(` Using Shopee access token for product ${unlist ? 'unlist' : 'list'}`);

      // Call Shopee API to unlist/list item
      const unlistResponse = await productApi.unlistItem(
        token.access_token,
        shopId,
        parseInt(productId),
        unlist
      );

      // Check for API errors
      if (unlistResponse.error) {
        throw new Error(`Shopee API Error: ${unlistResponse.error} - ${unlistResponse.message}`);
      }

      // Check for partial failures
      const successList = unlistResponse.response?.success_list || [];
      const failureList = unlistResponse.response?.failure_list || [];

      console.log(` Unlist result: ${successList.length} success, ${failureList.length} failed`);

      if (failureList.length > 0) {
        console.warn('️ Product failed to unlist:', failureList);

        const failureReason = failureList[0]?.failed_reason || 'Unknown reason';

        return res.status(400).json({
          success: false,
          message: `Failed to ${unlist ? 'unlist' : 'list'} product: ${failureReason}`,
          data: {
            item_id: productId,
            reason: failureReason,
          },
        });
      }

      res.status(200).json({
        success: true,
        message: `Product ${unlist ? 'unlisted' : 'listed'} successfully`,
        data: {
          item_id: productId,
          unlisted: unlist,
          status: unlist ? 'UNLISTED' : 'NORMAL',
        },
      });
    } catch (error) {
      console.error(` Error ${req.body.unlist ? 'unlisting' : 'listing'} Shopee product:`, error);

      res.status(500).json({
        success: false,
        message: `Failed to ${req.body.unlist ? 'unlist' : 'list'} product`,
        error: error.message,
      });
    }
  }
}

module.exports = new ShopeeProductController();
