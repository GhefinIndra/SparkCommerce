const crypto = require("crypto");
const axios = require("axios");

class OrderService {
  constructor() {
    this.baseURL = "https://open-api.tiktokglobalshop.com";
    this.appKey = process.env.TIKTOK_APP_KEY;
    this.appSecret = process.env.TIKTOK_APP_SECRET;

    console.log("️ OrderService initialized:", {
      baseURL: this.baseURL,
      hasAppKey: !!this.appKey,
      hasAppSecret: !!this.appSecret,
    });
  }

  generateSignature(path, queryParams, body = "") {
    const sortedParams = {};
    const paramKeys = Object.keys(queryParams)
      .filter((key) => key !== "sign" && key !== "access_token")
      .sort();

    paramKeys.forEach((key) => {
      sortedParams[key] = queryParams[key];
    });

    let paramString = "";
    for (const key in sortedParams) {
      paramString += key + sortedParams[key];
    }

    let bodyString = "";
    if (body && typeof body === "object") {
      bodyString = JSON.stringify(body);
    } else if (body) {
      bodyString = body.toString();
    }

    const stringToSign =
      this.appSecret + path + paramString + bodyString + this.appSecret;

    /* console.log(' Signature Debug:', {
      path,
      paramKeys,
      bodyLength: bodyString.length,
      bodyType: typeof body,
      bodyContent: bodyString || 'empty',
      stringToSignLength: stringToSign.length,
      stringToSignSample: stringToSign.substring(0, 100) + '...'
    }); */

    const signature = crypto
      .createHmac("sha256", this.appSecret)
      .update(stringToSign)
      .digest("hex");

    // console.log(' Generated signature (first 16 chars):', signature.substring(0, 16) + '...');

    return signature;
  }

  buildSignedQuery(path, baseParams, body = "") {
    // Always use current timestamp
    const currentTimestamp = Math.floor(Date.now() / 1000);

    const params = {
      ...baseParams,
      timestamp: currentTimestamp.toString(),
    };

    console.log(" Using current timestamp:", {
      timestamp: params.timestamp,
      readable: new Date(currentTimestamp * 1000).toISOString(),
    });

    const signature = this.generateSignature(path, params, body);

    return {
      ...params,
      sign: signature,
    };
  }

  buildApiUrl(baseUrl, path, params) {
    const queryString = new URLSearchParams(params).toString();
    return `${baseUrl}${path}?${queryString}`;
  }

  async getOrderList(accessToken, shopCipher, filters = {}) {
    try {
      const path = "/order/202309/orders/search";

      console.log(" OrderService.getOrderList called with:", {
        hasAccessToken: !!accessToken,
        accessTokenLength: accessToken?.length,
        shopCipher: shopCipher,
        filtersCount: Object.keys(filters).length,
      });

      //  Query parameters (pagination and sorting)
      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
        page_size: (filters.page_size || 20).toString(),
        sort_order: filters.sort_order || "DESC",
        // timestamp will be added in buildSignedQuery
      };

      // Optional query parameters
      if (filters.page_token) queryParams.page_token = filters.page_token;
      if (filters.sort_field) queryParams.sort_field = filters.sort_field;

      const requestBody = {};

      // Order status filter
      if (filters.order_status) requestBody.order_status = filters.order_status;

      // Time filters
      if (filters.create_time_ge) {
        requestBody.create_time_ge =
          typeof filters.create_time_ge === "string"
            ? this.formatTimeFilter(filters.create_time_ge)
            : filters.create_time_ge;
      }
      if (filters.create_time_lt) {
        requestBody.create_time_lt =
          typeof filters.create_time_lt === "string"
            ? this.formatTimeFilter(filters.create_time_lt)
            : filters.create_time_lt;
      }
      if (filters.update_time_ge) {
        requestBody.update_time_ge =
          typeof filters.update_time_ge === "string"
            ? this.formatTimeFilter(filters.update_time_ge)
            : filters.update_time_ge;
      }
      if (filters.update_time_lt) {
        requestBody.update_time_lt =
          typeof filters.update_time_lt === "string"
            ? this.formatTimeFilter(filters.update_time_lt)
            : filters.update_time_lt;
      }

      // Other filters
      if (filters.shipping_type)
        requestBody.shipping_type = filters.shipping_type;
      if (filters.buyer_user_id)
        requestBody.buyer_user_id = filters.buyer_user_id;
      if (filters.is_buyer_request_cancel !== undefined) {
        requestBody.is_buyer_request_cancel = filters.is_buyer_request_cancel;
      }
      if (filters.warehouse_ids) {
        requestBody.warehouse_ids = Array.isArray(filters.warehouse_ids)
          ? filters.warehouse_ids
          : [filters.warehouse_ids];
      }

      console.log(" Query params (before signature):", {
        ...queryParams,
        app_key: "[HIDDEN]",
      });
      console.log(" Request body:", requestBody);

      const signedParams = this.buildSignedQuery(
        path,
        queryParams,
        requestBody,
      );
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      console.log(
        " Final URL (sensitive data hidden):",
        url
          .replace(/app_key=[^&]+/, "app_key=[HIDDEN]")
          .replace(/sign=[^&]+/, "sign=[HIDDEN]"),
      );

      //  Make API request
      const response = await axios.post(url, requestBody, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" TikTok Order List API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        totalOrders: response.data?.data?.total_count,
        ordersCount: response.data?.data?.orders?.length,
        hasNextPage: !!response.data?.data?.next_page_token,
      });

      //  Check for API errors
      if (response.data?.code !== 0) {
        throw new Error(
          `TikTok API Error: ${response.data?.message} (Code: ${response.data?.code})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(" OrderService.getOrderList Error:", {
        status: error.response?.status,
        statusText: error.response?.statusText,
        errorCode: error.response?.data?.code,
        errorMessage: error.response?.data?.message,
        requestId: error.response?.data?.request_id,
        originalMessage: error.message,
      });

      let errorMessage = "TikTok Order API Error: ";
      if (error.response?.data?.message) {
        errorMessage += error.response.data.message;
        if (error.response?.data?.code) {
          errorMessage += ` (Code: ${error.response.data.code})`;
        }
      } else if (error.response?.statusText) {
        errorMessage += `HTTP ${error.response.status}: ${error.response.statusText}`;
      } else {
        errorMessage += error.message;
      }

      throw new Error(errorMessage);
    }
  }

  async getOrderDetail(accessToken, shopCipher, orderIds) {
    try {
      const path = "/order/202507/orders";

      console.log(" OrderService.getOrderDetail called with:", {
        hasAccessToken: !!accessToken,
        shopCipher: shopCipher,
        orderIds: orderIds,
      });

      // Query parameters for GET request
      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
        ids: orderIds,
      };

      console.log(" Query params for order detail:", {
        ...queryParams,
        app_key: "[HIDDEN]",
      });

      // Generate signature for GET request (empty body)
      const signedParams = this.buildSignedQuery(path, queryParams, "");
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      console.log(
        " Order Detail URL (sensitive data hidden):",
        url
          .replace(/app_key=[^&]+/, "app_key=[HIDDEN]")
          .replace(/sign=[^&]+/, "sign=[HIDDEN]"),
      );

      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" TikTok Order Detail API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        orderCount: response.data?.data?.orders?.length,
      });

      console.log("ORDER STATUS:", response.data?.data?.orders?.[0]?.status);
      console.log("FULL ORDER INFO:", {
        orderId: response.data?.data?.orders?.[0]?.id,
        orderStatus: response.data?.data?.orders?.[0]?.status,
        paidTime: response.data?.data?.orders?.[0]?.paid_time,
        createTime: response.data?.data?.orders?.[0]?.create_time,
      });

      if (response.data?.code !== 0) {
        throw new Error(
          `TikTok API Error: ${response.data?.message} (Code: ${response.data?.code})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(" OrderService.getOrderDetail Error:", error.message);
      throw error;
    }
  }

  // Helper method untuk format filter waktu
  formatTimeFilter(dateString) {
    if (!dateString) return null;

    try {
      const date = new Date(dateString);
      const timestamp = Math.floor(date.getTime() / 1000);

      console.log(" Time filter conversion:", {
        input: dateString,
        timestamp: timestamp,
        converted: new Date(timestamp * 1000).toISOString(),
      });

      return timestamp;
    } catch (error) {
      console.error(" Invalid date format:", dateString, error.message);
      return null;
    }
  }

  // Helper method untuk validate timestamp
  validateTimestamp(timestamp) {
    const now = Math.floor(Date.now() / 1000);
    const timeDiff = Math.abs(now - parseInt(timestamp));

    console.log(" Timestamp validation:", {
      provided: timestamp,
      current: now,
      difference: timeDiff,
      differenceMinutes: Math.floor(timeDiff / 60),
      isValid: timeDiff <= 300, // 5 minutes tolerance
    });

    return timeDiff <= 300; // 5 minutes tolerance
  }

  // Test method untuk debugging API calls
  async testApiCall(accessToken, shopCipher) {
    console.log("\n🧪 === TESTING ORDER API CALL ===");

    try {
      const result = await this.getOrderList(accessToken, shopCipher, {
        page_size: 5,
        sort_order: "DESC",
      });

      console.log(" Test API call successful");
      return result;
    } catch (error) {
      console.error(" Test API call failed:", error.message);
      throw error;
    }
  }

  // Debug method untuk test signature generation
  debugSignature(shopCipher) {
    console.log("\n === SIGNATURE DEBUG ===");

    const path = "/order/202309/orders/search";
    const timestamp = Math.floor(Date.now() / 1000);

    const testParams = {
      app_key: this.appKey,
      timestamp: timestamp.toString(),
      shop_cipher: shopCipher,
      page_size: "20",
      sort_order: "DESC",
    };

    const testBody = {}; //  FIX: Empty object for your case

    console.log(" Test parameters:", {
      ...testParams,
      app_key: "[HIDDEN]",
      timestamp_readable: new Date(timestamp * 1000).toISOString(),
    });
    console.log(" Test body:", testBody);

    const signedParams = this.buildSignedQuery(path, testParams, testBody);
    const url = this.buildApiUrl(this.baseURL, path, signedParams);

    console.log(
      " Generated URL (hidden sensitive):",
      url
        .replace(/app_key=[^&]+/, "app_key=[HIDDEN]")
        .replace(/sign=[^&]+/, "sign=[HIDDEN]"),
    );

    console.log(
      " Signature format valid:",
      signedParams.sign.length === 64 && /^[a-f0-9]+$/.test(signedParams.sign),
    );
    console.log(
      " Timestamp valid:",
      this.validateTimestamp(signedParams.timestamp),
    );
    console.log("===============================\n");

    return {
      signature: signedParams.sign,
      url: url,
      isValid:
        signedParams.sign.length === 64 &&
        /^[a-f0-9]+$/.test(signedParams.sign),
    };
  }

  async shipPackage(accessToken, shopCipher, packageId, shipmentData = {}) {
    try {
      const path = `/fulfillment/202309/packages/${packageId}/ship`;

      console.log(" OrderService.shipPackage called with:", {
        packageId,
        hasAccessToken: !!accessToken,
        shopCipher: shopCipher,
        shipmentData,
      });

      //  Enhanced request body preparation
      const requestBody = {
        handover_method: shipmentData.handover_method || "PICKUP",
      };

      // Only add pickup_slot if handover_method is PICKUP and not provided
      if (requestBody.handover_method === "PICKUP") {
        if (shipmentData.pickup_slot) {
          requestBody.pickup_slot = shipmentData.pickup_slot;
          console.log(
            " Using provided pickup_slot:",
            requestBody.pickup_slot,
          );
        } else {
          //  Create a reasonable pickup slot (next day, business hours)
          const currentTime = Math.floor(Date.now() / 1000);
          const nextDay = currentTime + 24 * 3600; // 24 hours from now
          const businessStart = nextDay + 9 * 3600; // 9 AM next day
          const businessEnd = nextDay + 17 * 3600; // 5 PM next day

          requestBody.pickup_slot = {
            start_time: businessStart,
            end_time: businessEnd,
          };

          console.log(" Generated pickup_slot:", {
            start_time: businessStart,
            end_time: businessEnd,
            readable_start: new Date(businessStart * 1000).toISOString(),
            readable_end: new Date(businessEnd * 1000).toISOString(),
          });
        }
      }

      // Add self_shipment if provided
      if (shipmentData.self_shipment) {
        requestBody.self_shipment = shipmentData.self_shipment;
      }

      console.log(" Final ship package request body:", requestBody);

      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
      };

      const signedParams = this.buildSignedQuery(
        path,
        queryParams,
        requestBody,
      );
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      const response = await axios.post(url, requestBody, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" Ship Package API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        hasData: !!response.data?.data,
      });

      // TikTok Shop success code is 0
      if (response.data?.code !== 0) {
        const errorCode = response.data?.code;
        const errorMessage = response.data?.message || "Unknown error";

        console.error(" TikTok API Error:", {
          code: errorCode,
          message: errorMessage,
          packageId: packageId,
        });

        throw new Error(
          `Ship Package Error: ${errorMessage} (Code: ${errorCode})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(" OrderService.shipPackage Error:", {
        message: error.message,
        packageId: packageId,
        isAxiosError: !!error.response,
      });

      //  Handle axios errors (network issues, 4xx, 5xx)
      if (error.response) {
        const statusCode = error.response.status;
        const responseData = error.response.data;

        console.error("HTTP Error Response:", {
          status: statusCode,
          data: responseData,
        });

        if (responseData?.message) {
          throw new Error(
            `Ship Package API Error: ${responseData.message} (HTTP ${statusCode})`,
          );
        } else {
          throw new Error(`Ship Package HTTP Error: ${statusCode}`);
        }
      }

      throw error;
    }
  }

  async getPackageDetail(accessToken, shopCipher, packageId) {
    try {
      const path = `/fulfillment/202309/packages/${packageId}`;

      console.log(" OrderService.getPackageDetail called with:", {
        packageId,
        hasAccessToken: !!accessToken,
        shopCipher: shopCipher,
      });

      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
      };

      const signedParams = this.buildSignedQuery(path, queryParams, "");
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" Get Package Detail API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        packageStatus: response.data?.data?.package_status,
        trackingNumber: response.data?.data?.tracking_number,
        hasOrders: !!response.data?.data?.orders,
      });

      if (response.data?.code !== 0) {
        throw new Error(
          `Get Package Detail Error: ${response.data?.message} (Code: ${response.data?.code})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(" OrderService.getPackageDetail Error:", error.message);

      //  Don't throw for certain errors that shouldn't block shipping
      if (error.response?.status === 404) {
        throw new Error(`Package ${packageId} not found (Code: 21011001)`);
      }

      throw error;
    }
  }

  //  NEW: Get Package Shipping Document API
  async getShippingDocument(
    accessToken,
    shopCipher,
    packageId,
    documentType = "SHIPPING_LABEL",
    documentSize = "A6",
    documentFormat = "PDF",
  ) {
    try {
      const path = `/fulfillment/202309/packages/${packageId}/shipping_documents`;

      console.log(" OrderService.getShippingDocument called with:", {
        packageId,
        documentType,
        documentSize,
        documentFormat,
        hasAccessToken: !!accessToken,
        shopCipher: shopCipher,
      });

      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
        document_type: documentType,
        document_size: documentSize,
        document_format: documentFormat,
      };

      const signedParams = this.buildSignedQuery(path, queryParams, "");
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" Get Shipping Document API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        hasDocUrl: !!response.data?.data?.doc_url,
        trackingNumber: response.data?.data?.tracking_number,
      });

      if (response.data?.code !== 0) {
        throw new Error(
          `Get Shipping Document Error: ${response.data?.message} (Code: ${response.data?.code})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(
        " OrderService.getShippingDocument Error:",
        error.message,
      );
      throw error;
    }
  }

  //  NEW: Get Package Detail API
  async getPackageDetail(accessToken, shopCipher, packageId) {
    try {
      const path = `/fulfillment/202309/packages/${packageId}`;

      console.log(" OrderService.getPackageDetail called with:", {
        packageId,
        hasAccessToken: !!accessToken,
        shopCipher: shopCipher,
      });

      const queryParams = {
        app_key: this.appKey,
        shop_cipher: shopCipher,
      };

      const signedParams = this.buildSignedQuery(path, queryParams, "");
      const url = this.buildApiUrl(this.baseURL, path, signedParams);

      const response = await axios.get(url, {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "x-tts-access-token": accessToken,
          "User-Agent": "TikTokShop-API/1.0",
        },
        timeout: 30000,
      });

      console.log(" Get Package Detail API Response:", {
        status: response.status,
        code: response.data?.code,
        message: response.data?.message,
        packageStatus: response.data?.data?.package_status,
        trackingNumber: response.data?.data?.tracking_number,
      });

      console.log(
        " FULL PACKAGE DETAIL RESPONSE:",
        JSON.stringify(response.data, null, 2),
      );

      if (response.data?.code !== 0) {
        throw new Error(
          `Get Package Detail Error: ${response.data?.message} (Code: ${response.data?.code})`,
        );
      }

      return response.data;
    } catch (error) {
      console.error(" OrderService.getPackageDetail Error:", error.message);
      throw error;
    }
  }
}

module.exports = new OrderService();
