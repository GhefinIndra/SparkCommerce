// backend_ecommerce_manager_mobile/src/services/customerServiceAPI.js
const { generateTikTokSignature } = require("../../utils/tiktokSignature");
const config = require("../../config/env");

class CustomerServiceAPI {
  constructor() {
    this.baseUrl = "https://open-api.tiktokglobalshop.com";
    this.apiVersion = "202309";
  }

  // Helper untuk generate common parameters
  generateCommonParams() {
    const timestamp = Math.floor(Date.now() / 1000);
    return {
      app_key: config.tiktok.appKey,
      timestamp: timestamp.toString(),
    };
  }

  // Helper untuk create URL with signature
  createSignedUrl(path, queryParams, accessToken) {
    const signature = generateTikTokSignature(
      path,
      queryParams,
      "",
      config.tiktok.appSecret,
    );
    queryParams.sign = signature;

    const queryString = new URLSearchParams(queryParams).toString();
    return `${this.baseUrl}${path}?${queryString}`;
  }

  // 1. Get Conversations
  async getConversations(
    accessToken,
    shopCipher,
    pageSize = 20,
    pageToken = "",
    locale = "id-ID",
  ) {
    try {
      const path = `/customer_service/${this.apiVersion}/conversations`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
        page_size: pageSize.toString(),
        locale: locale,
      };

      if (pageToken) {
        queryParams.page_token = pageToken;
      }

      const url = this.createSignedUrl(path, queryParams);

      const response = await fetch(url, {
        method: "GET",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "x-tts-access-token": accessToken,
        },
      });

      const data = await response.json();
      console.log(" Get Conversations API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in getConversations:", error);
      throw error;
    }
  }

  // 2. Get Conversation Messages
  async getConversationMessages(
    accessToken,
    shopCipher,
    conversationId,
    pageSize = 10,
    pageToken = "",
    locale = "id-ID",
  ) {
    try {
      const path = `/customer_service/${this.apiVersion}/conversations/${conversationId}/messages`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
        page_size: pageSize.toString(),
        locale: locale,
        sort_order: "DESC",
        sort_field: "create_time",
      };

      if (pageToken) {
        queryParams.page_token = pageToken;
      }

      const url = this.createSignedUrl(path, queryParams);

      const response = await fetch(url, {
        method: "GET",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "x-tts-access-token": accessToken,
        },
      });

      const data = await response.json();
      console.log(" Get Messages API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in getConversationMessages:", error);
      throw error;
    }
  }

  // 3. Create Conversation
  async createConversation(accessToken, shopCipher, buyerUserId) {
    try {
      const path = `/customer_service/${this.apiVersion}/conversations`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        buyer_user_id: buyerUserId,
      });

      const url = this.createSignedUrl(path, queryParams, body);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "x-tts-access-token": accessToken,
        },
        body: body,
      });

      const data = await response.json();
      console.log(" Create Conversation API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in createConversation:", error);
      throw error;
    }
  }

  // 4. Send Message
  async sendMessage(
    accessToken,
    shopCipher,
    conversationId,
    messageType,
    content,
  ) {
    try {
      const path = `/customer_service/${this.apiVersion}/conversations/${conversationId}/messages`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
      };

      const body = JSON.stringify({
        type: messageType,
        content: content,
      });

      const url = this.createSignedUrl(path, queryParams, body);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "x-tts-access-token": accessToken,
        },
        body: body,
      });

      const data = await response.json();
      console.log(" Send Message API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in sendMessage:", error);
      throw error;
    }
  }

  // 5. Read Messages
  async readMessages(accessToken, shopCipher, conversationId) {
    try {
      const path = `/customer_service/${this.apiVersion}/conversations/${conversationId}/messages/read`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
      };

      const url = this.createSignedUrl(path, queryParams);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "x-tts-access-token": accessToken,
        },
      });

      const data = await response.json();
      console.log("️ Read Messages API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in readMessages:", error);
      throw error;
    }
  }

  // 6. Upload Image
  async uploadImage(accessToken, shopCipher, imageFile) {
    try {
      const path = `/customer_service/${this.apiVersion}/images/upload`;
      const queryParams = {
        ...this.generateCommonParams(),
        shop_cipher: shopCipher,
      };

      const url = this.createSignedUrl(path, queryParams);

      const formData = new FormData();
      formData.append("data", imageFile);

      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "x-tts-access-token": accessToken,
        },
        body: formData,
      });

      const data = await response.json();
      console.log("️ Upload Image API Response:", data.code);
      return data;
    } catch (error) {
      console.error(" Error in uploadImage:", error);
      throw error;
    }
  }
}

module.exports = new CustomerServiceAPI();
