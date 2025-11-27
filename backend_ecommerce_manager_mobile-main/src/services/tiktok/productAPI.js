// src/services/productAPI.js
const axios = require("axios");
const {
  buildSignedQuery,
  buildApiUrl,
  generateApiSignature,
} = require("../../utils/tiktokSignature");
const config = require("../../config/env");

class ProductApiService {
  constructor() {
    this.baseUrl = "https://open-api.tiktokglobalshop.com";
    this.appKey = process.env.TIKTOK_APP_KEY;
    this.appSecret = process.env.TIKTOK_APP_SECRET;

    if (!this.appKey || !this.appSecret) {
      console.error(" TIKTOK_APP_KEY or TIKTOK_APP_SECRET not configured");
    }
  }

  // Get headers for API request
  getHeaders(accessToken) {
    return {
      "Content-Type": "application/json",
      Accept: "application/json",
      "x-tts-access-token": accessToken,
      "Cache-Control": "no-cache",
      "User-Agent": "TikTokShop-Mobile-API/1.0",
    };
  }

  // Helper method to make API calls
  async makeApiCall(method, path, accessToken, body = "") {
    try {
      const timestamp = Math.floor(Date.now() / 1000);

      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
      };

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      console.log(` Making ${method} request to:`, path);
      console.log(" Mobile API - Request params:", {
        ...signedParams,
        sign: "[HIDDEN]",
      });

      const config = {
        method: method.toLowerCase(),
        url,
        headers: this.getHeaders(accessToken),
        timeout: 30000, // 30 seconds timeout
      };

      if (body && (method === "POST" || method === "PUT")) {
        config.data = JSON.parse(body);
      }

      if (method === "DELETE" && body) {
        config.data = JSON.parse(body);
      }

      const response = await axios(config);

      console.log(
        ` Mobile API - ${method} ${path} - Status:`,
        response.status,
      );
      console.log(" Response code:", response.data?.code);

      return response.data;
    } catch (error) {
      console.error(` Mobile API Error for ${method} ${path}:`, {
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to ${method.toLowerCase()} ${path}: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Get seller/shop information
  async getSellerInfo(accessToken) {
    const path = "/seller/202309/shops";
    const result = await this.makeApiCall("GET", path, accessToken);
    console.log(" MOBILE - SELLER INFO:", JSON.stringify(result, null, 2));
    return result;
  }

  // Get all products from a shop - MOBILE VERSION
  async getProducts(accessToken, shopCipher, pageSize = 20, pageToken = "") {
    const path = "/product/202502/products/search";

    try {
      const timestamp = Math.floor(Date.now() / 1000);

      // Parameter untuk query string
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
        page_size: pageSize,
      };

      if (pageToken) {
        baseParams.page_token = pageToken;
      }

      // Body untuk API v202502
      const requestBody = JSON.stringify({
        status: "ALL", // "ALL", "ACTIVE", "INACTIVE"
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        requestBody,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      console.log(` Mobile - Making POST request to:`, path);
      console.log(" Mobile - Request params:", {
        ...signedParams,
        sign: "[HIDDEN]",
      });
      console.log(" Mobile - Request body:", requestBody);
      console.log(" Mobile - Using shop_cipher:", shopCipher);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(requestBody),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(` Mobile - POST ${path} - Status:`, response.status);
      console.log(" Mobile - Response code:", response.data?.code);

      return response.data;
    } catch (error) {
      console.error(` Mobile API Error for POST products search:`, {
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        message: error.message,
        path: path,
      });

      throw new Error(
        `Failed to get products: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Get single product details - MOBILE VERSION
  async getProduct(accessToken, productId, shopCipher) {
    try {
      const path = `/product/202309/products/${productId}`;

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
        return_under_review_version: false,
        return_draft_version: false,
      };

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        "",
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      console.log(` Mobile - Making GET request to:`, path);
      console.log(" Mobile - Product ID:", productId);
      console.log(" Mobile - Using shop_cipher:", shopCipher);

      const config = {
        method: "get",
        url,
        headers: this.getHeaders(accessToken),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Get product success:", response.status);
      console.log(" Mobile - Response code:", response.data?.code);

      return response.data;
    } catch (error) {
      console.error(" Mobile - Get product error:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to get product: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Edit product - MOBILE VERSION menggunakan PARTIAL EDIT API
  async editProduct(accessToken, productId, updateData, shopCipher) {
    try {
      const path = `/product/202309/products/${productId}/partial_edit`;

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      // Validasi field yang diizinkan
      const allowedFields = [
        "title",
        "description",
        "brand_id",
        "is_cod_allowed",
        "external_product_id",
        "main_images",
        "skus",
        "package_weight",
        "package_dimensions",
      ];
      const hasValidField = Object.keys(updateData).some((key) =>
        allowedFields.includes(key),
      );

      if (!hasValidField) {
        throw new Error(
          `No valid fields to update. Allowed fields: ${allowedFields.join(", ")}`,
        );
      }

      // Bersihkan data update
      const cleanUpdateData = {};

      // Field individual
      const individualFields = [
        "title",
        "description",
        "brand_id",
        "is_cod_allowed",
        "external_product_id",
      ];
      individualFields.forEach((field) => {
        if (updateData[field] !== undefined && updateData[field] !== null) {
          cleanUpdateData[field] = updateData[field];
        }
      });

      // Field object/array
      const objectFields = [
        "main_images",
        "skus",
        "package_weight",
        "package_dimensions",
      ];
      objectFields.forEach((field) => {
        if (updateData[field] !== undefined && updateData[field] !== null) {
          cleanUpdateData[field] = updateData[field];
        }
      });

      // Save mode default
      cleanUpdateData.save_mode = updateData.save_mode || "LISTING";

      const body = JSON.stringify(cleanUpdateData);

      console.log(" Mobile - Edit product request:", {
        path,
        productId,
        shopCipher,
        fieldsToUpdate: Object.keys(cleanUpdateData),
        saveMode: cleanUpdateData.save_mode,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: cleanUpdateData,
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Edit product success:", response.status);
      console.log(" Mobile - Response:", response.data);

      return response.data;
    } catch (error) {
      console.error(" Mobile - Edit product error:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to edit product: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Update product price - MOBILE VERSION
  async updatePrice(accessToken, productId, priceData, shopCipher) {
    try {
      const path = `/product/202309/products/${productId}/prices/update`;

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      // Validasi price data
      for (const sku of priceData) {
        if (!sku.id) {
          throw new Error(`SKU id is required`);
        }
        if (!sku.price || !sku.price.amount) {
          throw new Error(`Price amount is required for SKU ${sku.id}`);
        }
        if (!sku.price.currency) {
          throw new Error(`Price currency is required for SKU ${sku.id}`);
        }
      }

      const body = JSON.stringify({
        skus: priceData.map((sku) => ({
          id: sku.id,
          price: {
            amount: sku.price.amount,
            currency: sku.price.currency,
            sale_price: sku.price.sale_price || sku.price.amount,
          },
          list_price: sku.list_price
            ? {
                amount: sku.list_price.amount,
                currency: sku.list_price.currency,
              }
            : undefined,
        })),
      });

      console.log(" Mobile - Price update request:", { path, productId });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Price update success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Price update error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to update price: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Update product inventory/stock - MOBILE VERSION
  async updateInventory(accessToken, productId, inventoryData, shopCipher) {
    try {
      const path = `/product/202309/products/${productId}/inventory/update`;

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      // Validasi inventory data
      for (const sku of inventoryData) {
        if (!sku.warehouse_id) {
          throw new Error(`warehouse_id is required for SKU ${sku.id}`);
        }
        if (!sku.id) {
          throw new Error(`SKU id is required`);
        }
      }

      const body = JSON.stringify({
        skus: inventoryData.map((sku) => ({
          id: sku.id,
          inventory: [
            {
              warehouse_id: sku.warehouse_id,
              quantity: parseInt(sku.available_stock || sku.quantity),
            },
          ],
        })),
      });

      console.log(" Mobile - Inventory update request:", { path, productId });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Inventory update success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Inventory update error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to update inventory: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Delete product - MOBILE VERSION
  async deleteProduct(accessToken, productId, shopCipher) {
    try {
      const path = "/product/202309/products";

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        product_ids: [productId],
      });

      console.log(" Mobile - Delete product request:", {
        path,
        productId,
        shopCipher,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "delete",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Delete product success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Delete product error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to delete product: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  async updateProductImages(accessToken, productId, images, shopCipher) {
    try {
      const path = `/product/202309/products/${productId}/partial_edit`;

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      // Format images sesuai TikTok Shop API
      const formattedImages = images.map((img) => ({
        uri: img.uri,
        url: img.url || img.uri, // Fallback ke uri jika url tidak ada
      }));

      const updateData = {
        main_images: formattedImages,
        save_mode: "LISTING",
      };

      const body = JSON.stringify(updateData);

      console.log(" Mobile - Update images request:", {
        path,
        productId,
        imageCount: formattedImages.length,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: updateData,
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Update images success:", response.status);
      console.log(" Mobile - Response:", response.data);

      return response.data;
    } catch (error) {
      console.error(" Mobile - Update images error:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to update images: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  // Get orders - MOBILE VERSION (bonus method)
  async getOrders(accessToken, params = {}) {
    const path = "/order/202309/orders/search";
    const defaultParams = {
      page_size: 20,
      sort_type: 1, // Sort by create time
      ...params,
    };
    const body = JSON.stringify(defaultParams);

    console.log(" Mobile - Getting orders");
    return await this.makeApiCall("POST", path, accessToken, body);
  }

  async createProduct(accessToken, productData, shopCipher) {
    try {
      const path = "/product/202309/products";

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify(productData);

      console.log(" Mobile - Create product request:", {
        path,
        shopCipher,
        productTitle: productData.title,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: body,
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Create product success:", response.status);
      console.log(" Mobile - Response:", response.data);

      return response.data;
    } catch (error) {
      console.error(" Mobile - Create product error:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to create product: ${error.response?.data?.message || error.message}`,
      );
    }
  }


  async activateProduct(accessToken, productIds, shopCipher) {
    try {
      const path = "/product/202309/products/activate";

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        product_ids: Array.isArray(productIds) ? productIds : [productIds],
        listing_platforms: ["TIKTOK_SHOP"],
      });

      console.log(" Mobile - Activate product request:", {
        path,
        productIds,
        shopCipher,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Activate product success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Activate product error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to activate product: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  async deactivateProduct(accessToken, productIds, shopCipher) {
    try {
      const path = "/product/202309/products/deactivate";

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        product_ids: Array.isArray(productIds) ? productIds : [productIds],
        listing_platforms: ["TIKTOK_SHOP"],
      });

      console.log(" Mobile - Deactivate product request:", {
        path,
        productIds,
        shopCipher,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Deactivate product success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Deactivate product error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to deactivate product: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  async recoverProduct(accessToken, productIds, shopCipher) {
    try {
      const path = "/product/202309/products/recover";

      const timestamp = Math.floor(Date.now() / 1000);
      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        product_ids: Array.isArray(productIds) ? productIds : [productIds],
      });

      console.log(" Mobile - Recover product request:", {
        path,
        productIds,
        shopCipher,
      });

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        body,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "post",
        url,
        headers: this.getHeaders(accessToken),
        data: JSON.parse(body),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Mobile - Recover product success:", response.status);
      return response.data;
    } catch (error) {
      console.error(
        " Mobile - Recover product error:",
        error.response?.data || error.message,
      );
      throw new Error(
        `Failed to recover product: ${error.response?.data?.message || error.message}`,
      );
    }
  }
}

module.exports = new ProductApiService();
