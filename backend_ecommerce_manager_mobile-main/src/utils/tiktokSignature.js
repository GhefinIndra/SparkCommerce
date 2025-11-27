// backend_ecommerce_manager_mobile/src/utils/signature.js
const crypto = require("crypto");

/**
 * Generate TikTok signature for API endpoints (Product, Order, etc)
 * Format: appSecret + path + paramString + body + appSecret
 * FIXED: Proper body handling and timestamp
 */
function generateApiSignature(path, queryParams, body, appSecret) {
  // 1. Filter out sign and access_token, then sort alphabetically
  const sortedParams = {};
  const paramKeys = Object.keys(queryParams)
    .filter((key) => key !== "sign" && key !== "access_token")
    .sort();

  paramKeys.forEach((key) => {
    sortedParams[key] = queryParams[key];
  });

  // 2. Concatenate parameters in format {key}{value}
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

  // 4. Create string to sign: appSecret + path + paramString + body + appSecret
  const stringToSign = appSecret + path + paramString + bodyString + appSecret;

  console.log("️ API Signature Debug:", {
    method: "generateApiSignature",
    path,
    paramCount: paramKeys.length,
    paramKeys,
    bodyLength: bodyString.length,
    bodyType: typeof body,
    bodyContent: body
      ? typeof body === "object"
        ? JSON.stringify(body)
        : body.toString()
      : "empty",
    stringToSignLength: stringToSign.length,
    stringToSignSample: stringToSign.substring(0, 100) + "...",
  });

  // 5. Generate HMAC-SHA256 signature
  const signature = crypto
    .createHmac("sha256", appSecret)
    .update(stringToSign, "utf8")
    .digest("hex");

  console.log(
    "️ Generated API signature (first 16 chars):",
    signature.substring(0, 16) + "...",
  );

  return signature;
}

/**
 *  FIX: Proper timestamp handling
 * Helper function to build query string with signature
 */
function buildSignedQuery(path, baseParams, body, appSecret) {
  // Always use current timestamp (Unix timestamp in seconds)
  const currentTimestamp = Math.floor(Date.now() / 1000);

  const params = {
    ...baseParams,
    timestamp: currentTimestamp.toString(),
  };

  console.log(" Timestamp validation:", {
    provided: baseParams.timestamp,
    corrected: params.timestamp,
    currentDate: new Date(currentTimestamp * 1000).toISOString(),
    isCurrentTime: true,
  });

  const signature = generateApiSignature(path, params, body, appSecret);

  return {
    ...params,
    sign: signature,
  };
}

/**
 * Generate TikTok signature for OAuth and Authorization endpoints
 */
function generateTikTokSignature(path, queryParams, body = "", appSecret) {
  return generateApiSignature(path, queryParams, body, appSecret);
}

/**
 * Helper function to build complete API URL
 */
function buildApiUrl(baseUrl, path, params) {
  const queryString = new URLSearchParams(params).toString();
  return `${baseUrl}${path}?${queryString}`;
}

/**
 * Validate timestamp - TikTok API accepts ±5 minutes tolerance
 */
function validateTimestamp(timestamp) {
  const now = Math.floor(Date.now() / 1000);
  const timeDiff = Math.abs(now - parseInt(timestamp));

  console.log(" Timestamp validation check:", {
    provided: timestamp,
    current: now,
    difference: timeDiff,
    differenceMinutes: Math.floor(timeDiff / 60),
    isValid: timeDiff <= 300, // 5 minutes tolerance
  });

  return timeDiff <= 300; // 5 minutes tolerance
}

/**
 *  FIXED: Test function with proper body handling
 */
function testSignatureGeneration(appKey, appSecret, shopCipher) {
  console.log("\n🧪 === TESTING SIGNATURE GENERATION ===");

  const path = "/order/202309/orders/search";
  const currentTimestamp = Math.floor(Date.now() / 1000);

  const testParams = {
    app_key: appKey,
    timestamp: currentTimestamp.toString(),
    shop_cipher: shopCipher,
    page_size: "20",
    sort_order: "DESC",
  };

  const testBody = {};

  console.log(" Test parameters:", {
    ...testParams,
    app_key: "[HIDDEN]",
    timestamp_date: new Date(currentTimestamp * 1000).toISOString(),
  });
  console.log(" Test body:", testBody);

  const signature = generateApiSignature(path, testParams, testBody, appSecret);

  const finalParams = {
    ...testParams,
    sign: signature,
  };

  const finalUrl = buildApiUrl(
    "https://open-api.tiktokglobalshop.com",
    path,
    finalParams,
  );

  console.log(
    " Final URL (hidden sensitive):",
    finalUrl
      .replace(/app_key=[^&]+/, "app_key=[HIDDEN]")
      .replace(/sign=[^&]+/, "sign=[HIDDEN]"),
  );
  console.log(
    " Signature format valid:",
    signature.length === 64 && /^[a-f0-9]+$/.test(signature),
  );
  console.log(" Timestamp valid:", validateTimestamp(testParams.timestamp));
  console.log("==========================================\n");

  return {
    signature,
    url: finalUrl,
    params: finalParams,
    isValid: signature.length === 64 && /^[a-f0-9]+$/.test(signature),
  };
}

/**
 * Generate signature with automatic timestamp correction
 */
function generateSignatureWithValidTimestamp(
  params,
  appSecret,
  path,
  method = "POST",
  body = {},
) {
  const correctedParams = {
    ...params,
    timestamp: Math.floor(Date.now() / 1000).toString(),
  };

  return generateApiSignature(path, correctedParams, body, appSecret);
}

// DEPRECATED functions for backward compatibility
function generateSignature(
  params,
  appSecret,
  path,
  method = "POST",
  body = "",
) {
  console.warn(
    "️ DEPRECATED: generateSignature() is deprecated. Use generateApiSignature() instead.",
  );
  return generateApiSignature(path, params, body, appSecret);
}

module.exports = {
  generateTikTokSignature, // For OAuth endpoints
  generateApiSignature, // For API endpoints (MAIN FUNCTION - FIXED)
  buildSignedQuery, // Helper to build signed params (FIXED)
  buildApiUrl, // Helper to build final URL
  testSignatureGeneration, // For debugging (FIXED)
  validateTimestamp, // Validate timestamp
  generateSignatureWithValidTimestamp, // Auto-correct timestamp (FIXED)
  generateSignature, // DEPRECATED - for backward compatibility
};
