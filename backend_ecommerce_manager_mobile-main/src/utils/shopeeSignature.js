// src/utils/shopeeSignature.js
const crypto = require('crypto');

/**
 * Generate Shopee API Signature using HMAC-SHA256
 *
 * Signature Formula based on API type:
 * - Public API: partner_id + api_path + timestamp
 * - Shop API: partner_id + api_path + timestamp + access_token + shop_id
 * - Merchant API: partner_id + api_path + timestamp + access_token + merchant_id
 *
 * @param {string} partnerId - Shopee Partner ID
 * @param {string} apiPath - API endpoint path (e.g., '/api/v2/auth/token/get')
 * @param {number} timestamp - Unix timestamp in seconds
 * @param {string} partnerKey - Shopee Partner Key for HMAC
 * @param {string} accessToken - Optional access token (for Shop/Merchant API)
 * @param {string} shopId - Optional shop ID (for Shop API)
 * @param {string} merchantId - Optional merchant ID (for Merchant API)
 * @returns {string} Hex-encoded signature
 */
function generateShopeeSignature(
  partnerId,
  apiPath,
  timestamp,
  partnerKey,
  accessToken = '',
  shopId = '',
  merchantId = ''
) {
  // Build base string based on API type
  let baseString = '';

  if (shopId) {
    // Shop API: partner_id + api_path + timestamp + access_token + shop_id
    baseString = `${partnerId}${apiPath}${timestamp}${accessToken}${shopId}`;
  } else if (merchantId) {
    // Merchant API: partner_id + api_path + timestamp + access_token + merchant_id
    baseString = `${partnerId}${apiPath}${timestamp}${accessToken}${merchantId}`;
  } else {
    // Public API: partner_id + api_path + timestamp
    baseString = `${partnerId}${apiPath}${timestamp}`;
  }

  console.log(' Shopee Signature Debug:', {
    partnerId,
    apiPath,
    timestamp,
    hasAccessToken: !!accessToken,
    hasShopId: !!shopId,
    hasMerchantId: !!merchantId,
    baseStringLength: baseString.length,
    baseStringSample: baseString.substring(0, 50) + '...',
    partnerKeyLength: partnerKey.length,
  });

  // Generate HMAC-SHA256 signature
  // Partner Key is used directly as-is (no decoding needed based on Shopee docs)
  const signature = crypto
    .createHmac('sha256', partnerKey)
    .update(baseString)
    .digest('hex');

  console.log(' Generated Shopee Signature:', signature.substring(0, 16) + '...');

  return signature;
}

/**
 * Build complete query parameters with signature for Shopee API
 *
 * @param {string} partnerId - Shopee Partner ID
 * @param {string} apiPath - API endpoint path
 * @param {string} partnerKey - Shopee Partner Key
 * @param {string} accessToken - Optional access token
 * @param {string} shopId - Optional shop ID
 * @param {string} merchantId - Optional merchant ID
 * @returns {object} Query parameters object with signature
 */
function buildShopeeParams(
  partnerId,
  apiPath,
  partnerKey,
  accessToken = '',
  shopId = '',
  merchantId = ''
) {
  // Generate current timestamp (in seconds)
  const timestamp = Math.floor(Date.now() / 1000);

  // Log timestamp info for debugging
  const now = new Date();
  console.log(' Timestamp Info:', {
    unix: timestamp,
    date: now.toISOString(),
    localTime: now.toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' }),
  });

  // Generate signature
  const sign = generateShopeeSignature(
    partnerId,
    apiPath,
    timestamp,
    partnerKey,
    accessToken,
    shopId,
    merchantId
  );

  // Build params object
  const params = {
    partner_id: parseInt(partnerId),
    timestamp,
    sign,
  };

  // Add optional parameters
  if (accessToken) params.access_token = accessToken;
  if (shopId) params.shop_id = parseInt(shopId);
  if (merchantId) params.merchant_id = parseInt(merchantId);

  return params;
}

/**
 * Build complete Shopee API URL with query parameters
 *
 * @param {string} baseUrl - Shopee API base URL
 * @param {string} apiPath - API endpoint path
 * @param {object} params - Query parameters
 * @returns {string} Complete URL with query string
 */
function buildShopeeUrl(baseUrl, apiPath, params) {
  const queryString = new URLSearchParams(params).toString();
  return `${baseUrl}${apiPath}?${queryString}`;
}

/**
 * Validate timestamp - Shopee API requires timestamp within 5 minutes
 *
 * @param {number} timestamp - Unix timestamp to validate
 * @returns {boolean} True if timestamp is valid
 */
function validateTimestamp(timestamp) {
  const now = Math.floor(Date.now() / 1000);
  const diff = Math.abs(now - timestamp);
  const isValid = diff <= 300; // 5 minutes tolerance

  console.log(' Timestamp Validation:', {
    provided: timestamp,
    current: now,
    difference: diff,
    differenceMinutes: Math.floor(diff / 60),
    isValid,
  });

  return isValid;
}

module.exports = {
  generateShopeeSignature,
  buildShopeeParams,
  buildShopeeUrl,
  validateTimestamp,
};
