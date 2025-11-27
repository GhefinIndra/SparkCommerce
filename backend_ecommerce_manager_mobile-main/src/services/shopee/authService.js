// src/services/shopee/authService.js
const config = require("../../config/env");
const { buildShopeeParams, buildShopeeUrl } = require("../../utils/shopeeSignature");
const Token = require("../../models/Token");

/**
 * Shopee Auth Service
 * Handles token refresh and validation
 */
class ShopeeAuthService {
  /**
   * Check if token is expired or will expire soon (within 5 minutes)
   * @param {Date} expireAt - Token expiration date
   * @returns {boolean}
   */
  isTokenExpired(expireAt) {
    if (!expireAt) return true;

    const now = new Date();
    const expiryTime = new Date(expireAt);
    const bufferTime = 5 * 60 * 1000; // 5 minutes buffer

    return (expiryTime.getTime() - now.getTime()) <= bufferTime;
  }

  /**
   * Refresh Shopee access token
   * @param {string} shopId - Shop ID
   * @param {string} refreshToken - Current refresh token
   * @returns {Promise<object>} New token data
   */
  async refreshAccessToken(shopId, refreshToken) {
    try {
      const { partnerId, partnerKey, apiUrl } = config.shopee;
      const apiPath = "/api/v2/auth/access_token/get";

      console.log(` Refreshing access token for Shopee shop: ${shopId}`);

      // Build signature (Public API)
      const params = buildShopeeParams(partnerId, apiPath, partnerKey);
      const url = buildShopeeUrl(apiUrl, apiPath, params);

      // Request body
      const requestBody = {
        refresh_token: refreshToken,
        partner_id: parseInt(partnerId),
        shop_id: parseInt(shopId),
      };

      console.log(" Calling Shopee Refresh Token API");

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": "Shopee-OAuth/1.0",
        },
        body: JSON.stringify(requestBody),
      });

      const data = await response.json();

      if (data.error || !data.access_token) {
        throw new Error(`Shopee API Error: ${data.message || data.error || 'Token refresh failed'}`);
      }

      console.log(" Access token refreshed successfully");

      return {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        expire_in: data.expire_in,
      };
    } catch (error) {
      console.error(" Error refreshing access token:", error.message);
      throw error;
    }
  }

  /**
   * Get valid access token (auto-refresh if expired)
   * @param {string} shopId - Shop ID
   * @returns {Promise<object>} Token object with valid access_token
   */
  async getValidToken(shopId) {
    try {
      // Get token from database
      const tokenRecord = await Token.findOne({
        where: {
          shop_id: shopId.toString(),
          platform: "shopee",
        },
      });

      if (!tokenRecord) {
        throw new Error("Token not found in database");
      }

      // Check if token is expired or will expire soon
      if (this.isTokenExpired(tokenRecord.expire_at)) {
        console.log("️ Token expired or expiring soon, refreshing...");

        if (!tokenRecord.refresh_token) {
          throw new Error("Refresh token not available. Re-authentication required.");
        }

        // Refresh token
        const newTokenData = await this.refreshAccessToken(
          shopId,
          tokenRecord.refresh_token
        );

        // Update token in database
        await tokenRecord.update({
          access_token: newTokenData.access_token,
          refresh_token: newTokenData.refresh_token,
          expire_at: new Date(Date.now() + newTokenData.expire_in * 1000),
          updated_at: new Date(),
        });

        console.log(" Token updated in database");

        // Return updated token
        return {
          ...tokenRecord.toJSON(),
          access_token: newTokenData.access_token,
          refresh_token: newTokenData.refresh_token,
          expire_at: new Date(Date.now() + newTokenData.expire_in * 1000),
        };
      }

      // Token is still valid
      console.log(" Token is valid, no refresh needed");
      return tokenRecord;
    } catch (error) {
      console.error(" Error getting valid token:", error.message);
      throw error;
    }
  }
}

module.exports = new ShopeeAuthService();
