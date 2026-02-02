const crypto = require("crypto");

const ENC_VERSION = "v1";
const ENC_ALG = "AES-256-GCM";
const IV_LENGTH = 12;

function isEnabled() {
  return process.env.RESPONSE_ENCRYPTION_ENABLED === "true";
}

function isRequired() {
  return process.env.RESPONSE_ENCRYPTION_REQUIRED === "true";
}

function wantsEncrypted(req) {
  const header = req.headers["x-enc"];
  if (!header) return false;
  return header === "1" || header === "true";
}

function isExcludedPath(req) {
  if (req.method === "OPTIONS") return true;
  return req.path === "/health";
}

function getKey() {
  const rawKey = process.env.PAYLOAD_ENCRYPTION_KEY || "";
  if (!rawKey) {
    return null;
  }
  try {
    const key = Buffer.from(rawKey, "base64");
    if (key.length !== 32) {
      return null;
    }
    return key;
  } catch (error) {
    return null;
  }
}

function encryptPayload(payload) {
  const key = getKey();
  if (!key) {
    throw new Error("PAYLOAD_ENCRYPTION_KEY is missing or invalid (32 bytes base64)");
  }

  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([
    cipher.update(payload, "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();

  return {
    enc: ENC_VERSION,
    alg: ENC_ALG,
    iv: iv.toString("base64"),
    tag: tag.toString("base64"),
    data: encrypted.toString("base64"),
  };
}

function responseEncryption() {
  return (req, res, next) => {
    const originalJson = res.json.bind(res);

    if (!isEnabled() || isExcludedPath(req)) {
      return next();
    }

    const shouldEncrypt = wantsEncrypted(req);

    if (isRequired() && !shouldEncrypt) {
      res.status(400);
      return originalJson({
        success: false,
        message: "Encrypted response required. Send X-Enc: 1",
        code: "ENCRYPTION_REQUIRED",
      });
    }

    res.json = (payload) => {
      if (!shouldEncrypt) {
        return originalJson(payload);
      }

      try {
        const safePayload = payload === undefined ? null : payload;
        const plaintext = JSON.stringify(safePayload);
        const wrapped = encryptPayload(plaintext);
        res.setHeader("X-Enc", "1");
        return originalJson(wrapped);
      } catch (error) {
        res.status(500);
        return originalJson({
          success: false,
          message: "Failed to encrypt response",
          error:
            process.env.NODE_ENV === "development"
              ? error.message
              : "Encryption error",
        });
      }
    };

    next();
  };
}

module.exports = {
  responseEncryption,
};
