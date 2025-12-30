// TikTok token refresh scheduler
const Token = require("../../models/Token");
const config = require("../../config/env");

const CHECK_INTERVAL_MS = 10 * 60 * 1000; // every 10 minutes
const REFRESH_THRESHOLD_MINUTES = 60; // refresh if <= 60 minutes remaining

function needsRefresh(token) {
  if (!token.refresh_token) return false;
  if (!token.expire_at) return true;

  const minutesLeft =
    (new Date(token.expire_at).getTime() - Date.now()) / (1000 * 60);
  return minutesLeft < REFRESH_THRESHOLD_MINUTES;
}

async function refreshTikTokToken(token) {
  try {
    const params = new URLSearchParams({
      app_key: config.tiktok.appKey,
      app_secret: config.tiktok.appSecret,
      refresh_token: token.refresh_token,
      grant_type: "refresh_token",
    });

    const url = `https://auth.tiktok-shops.com/api/v2/token/refresh?${params.toString()}`;

    const response = await fetch(url, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "User-Agent": "TikTokShop-OAuth/1.0",
      },
    });

    const data = await response.json();

    if (data.code !== 0 || !data.data?.access_token) {
      throw new Error(data.message || "Failed to refresh TikTok token");
    }

    const ttlSeconds = data.data.access_token_expire_in;
    const newExpireAt = ttlSeconds
      ? new Date(Date.now() + ttlSeconds * 1000)
      : token.expire_at;

    await Token.update(
      {
        access_token: data.data.access_token,
        refresh_token: data.data.refresh_token || token.refresh_token,
        expire_at: newExpireAt,
        status: "active",
        updated_at: new Date(),
      },
      { where: { id: token.id } },
    );

    console.log(
      `TikTok token refreshed for shop ${token.shop_id || token.open_id}, expires in ${ttlSeconds} seconds`,
    );
  } catch (error) {
    console.error(
      `Failed to refresh TikTok token for shop ${token.shop_id || token.open_id}:`,
      error.message,
    );
  }
}

async function checkAndRefreshTikTokTokens() {
  try {
    const tokens = await Token.findAll({
      where: { platform: "tiktok", status: "active" },
      order: [["updated_at", "DESC"]],
    });

    for (const token of tokens) {
      if (needsRefresh(token)) {
        await refreshTikTokToken(token);
      }
    }
  } catch (error) {
    console.error("TikTok token scheduler error:", error.message);
  }
}

function startTikTokTokenScheduler() {
  console.log(
    `Starting TikTok token scheduler (every ${CHECK_INTERVAL_MS / 60000} minutes, threshold ${REFRESH_THRESHOLD_MINUTES} minutes)`,
  );

  // Initial run
  checkAndRefreshTikTokTokens();

  // Interval runs
  setInterval(checkAndRefreshTikTokTokens, CHECK_INTERVAL_MS);
}

module.exports = { startTikTokTokenScheduler };
