// src/services/warehouseAPI.js
const axios = require("axios");
const { buildSignedQuery, buildApiUrl } = require("../../utils/tiktokSignature");

class WarehouseApiService {
  constructor() {
    this.baseUrl = "https://open-api.tiktokglobalshop.com";
    this.appKey = process.env.TIKTOK_APP_KEY;
    this.appSecret = process.env.TIKTOK_APP_SECRET;

    if (!this.appKey || !this.appSecret) {
      console.error(" TIKTOK_APP_KEY or TIKTOK_APP_SECRET not configured");
    }
  }

  // Get headers for API requests (consistent with productAPI.js)
  getHeaders(accessToken) {
    return {
      "Content-Type": "application/json",
      "x-tts-access-token": accessToken,
    };
  }

  /**
   * Get Warehouse List
   * Endpoint: GET /logistics/202309/warehouses
   * Scope: seller.logistics
   */
  async getWarehouses(accessToken, shopCipher) {
    try {
      const path = "/logistics/202309/warehouses";
      const timestamp = Math.floor(Date.now() / 1000);

      const baseParams = {
        app_key: this.appKey,
        timestamp: timestamp.toString(),
        shop_cipher: shopCipher,
      };

      console.log(" Fetching warehouses for shop:", shopCipher);

      const signedParams = buildSignedQuery(
        path,
        baseParams,
        null,
        this.appSecret,
      );
      const url = buildApiUrl(this.baseUrl, path, signedParams);

      const config = {
        method: "get",
        url,
        headers: this.getHeaders(accessToken),
        timeout: 30000,
      };

      const response = await axios(config);

      console.log(" Warehouse API Response Status:", response.status);
      console.log(" Warehouse API Response:", response.data);

      if (response.data.code !== 0) {
        throw new Error(
          `API Error: ${response.data.message} (Code: ${response.data.code})`,
        );
      }

      return response.data.data;
    } catch (error) {
      console.error(" Error getting warehouses:", {
        status: error.response?.status,
        data: error.response?.data,
        message: error.message,
      });

      throw new Error(
        `Failed to get warehouses: ${error.response?.data?.message || error.message}`,
      );
    }
  }

  /**
   * Get Default Warehouse ID
   * Returns the first enabled warehouse ID, preferring default warehouse
   */
  async getDefaultWarehouseId(accessToken, shopCipher) {
    try {
      const warehouseData = await this.getWarehouses(accessToken, shopCipher);

      if (!warehouseData.warehouses || warehouseData.warehouses.length === 0) {
        throw new Error("No warehouses found for this shop");
      }

      // Filter enabled warehouses
      const enabledWarehouses = warehouseData.warehouses.filter(
        (warehouse) => warehouse.effect_status === "ENABLED",
      );

      if (enabledWarehouses.length === 0) {
        throw new Error("No enabled warehouses found");
      }

      // Prefer default warehouse
      const defaultWarehouse = enabledWarehouses.find(
        (warehouse) => warehouse.is_default === true,
      );

      const selectedWarehouse = defaultWarehouse || enabledWarehouses[0];

      console.log(" Selected warehouse:", {
        id: selectedWarehouse.id,
        name: selectedWarehouse.name,
        is_default: selectedWarehouse.is_default,
        type: selectedWarehouse.type,
      });

      return selectedWarehouse.id;
    } catch (error) {
      console.error(" Error getting default warehouse ID:", error.message);
      throw error;
    }
  }
}

module.exports = WarehouseApiService;
