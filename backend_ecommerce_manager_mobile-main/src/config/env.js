const dotenv = require("dotenv");

// Load environment variables
dotenv.config();

// Validate required environment variables
const requiredEnvVars = [
  "TIKTOK_APP_KEY",
  "TIKTOK_APP_SECRET",
  "TIKTOK_REDIRECT_URI",
  "SHOPEE_PARTNER_ID",
  "SHOPEE_PARTNER_KEY",
  "SHOPEE_REDIRECT_URI",
  "TOKEN_ENCRYPTION_KEY",
];

requiredEnvVars.forEach((envVar) => {
  if (!process.env[envVar]) {
    console.error(` Missing required environment variable: ${envVar}`);
    process.exit(1);
  }
});

const config = {
  // TikTok OAuth & API
  tiktok: {
    appKey: process.env.TIKTOK_APP_KEY,
    appSecret: process.env.TIKTOK_APP_SECRET,
    redirectUri: process.env.TIKTOK_REDIRECT_URI,
    scopes: process.env.TIKTOK_SCOPES || "",
    apiUrl:
      process.env.TIKTOK_API_URL || "https://open-api.tiktokglobalshop.com",
  },

  // Shopee OAuth & API
  shopee: {
    partnerId: process.env.SHOPEE_PARTNER_ID,
    partnerKey: process.env.SHOPEE_PARTNER_KEY,
    redirectUri: process.env.SHOPEE_REDIRECT_URI,
    // Default to sandbox for development, change to production in .env when ready
    apiUrl: process.env.SHOPEE_API_URL || "https://partner.test-stable.shopeemobile.com",
  },

  // Server
  server: {
    port: process.env.PORT || 5000,
    nodeEnv: process.env.NODE_ENV || "development",
    clientUrl: process.env.CLIENT_URL || "http://localhost:3000",
  },

  // Security
  security: {
    encryptionKey: process.env.TOKEN_ENCRYPTION_KEY,
  },

  // Database
  database: {
    host: process.env.DB_HOST || "localhost",
    name: process.env.DB_NAME || "ecommerce_manager",
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    port: process.env.DB_PORT || 5432,
    dialect: process.env.DB_DIALECT || "postgres",
    ssl: process.env.DB_SSL === "true",
  },
};

// API Config check
console.log(" Multi-Platform API Config:");
console.log("  TikTok:", {
  baseUrl: config.tiktok.apiUrl,
  appKey: config.tiktok.appKey ? " Loaded" : " Missing",
  redirectUri: config.tiktok.redirectUri,
});
console.log("  Shopee:", {
  baseUrl: config.shopee.apiUrl,
  partnerId: config.shopee.partnerId ? " Loaded" : " Missing",
  redirectUri: config.shopee.redirectUri,
});

module.exports = config;
