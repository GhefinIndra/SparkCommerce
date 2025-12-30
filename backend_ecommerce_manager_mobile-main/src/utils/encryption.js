// Simple AES-256-GCM encryption/decryption helper with backward compatibility for plaintext
const crypto = require("crypto");
const config = require("../config/env");

const PREFIX = "ENC::";

function getKey() {
  const raw = process.env.TOKEN_ENCRYPTION_KEY || config.security.encryptionKey;
  if (!raw) {
    throw new Error("TOKEN_ENCRYPTION_KEY is not set");
  }

  // Accept base64 or hex, fallback to utf8 if length fits 32 bytes
  let key;
  try {
    key = Buffer.from(raw, "base64");
  } catch (_) {
    key = null;
  }

  if (!key || key.length !== 32) {
    try {
      key = Buffer.from(raw, "hex");
    } catch (_) {
      key = null;
    }
  }

  if (!key || key.length !== 32) {
    key = Buffer.from(raw, "utf8");
  }

  if (key.length !== 32) {
    throw new Error("TOKEN_ENCRYPTION_KEY must be 32 bytes (256-bit)");
  }

  return key;
}

function encrypt(value) {
  if (!value) return value;
  const key = getKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();

  return (
    PREFIX +
    iv.toString("base64") +
    ":" +
    tag.toString("base64") +
    ":" +
    encrypted.toString("base64")
  );
}

function decrypt(value) {
  if (!value) return value;
  if (!value.startsWith(PREFIX)) return value; // backward compatibility for plaintext

  const key = getKey();
  const payload = value.slice(PREFIX.length);
  const [ivB64, tagB64, dataB64] = payload.split(":");
  if (!ivB64 || !tagB64 || !dataB64) return value;

  const iv = Buffer.from(ivB64, "base64");
  const tag = Buffer.from(tagB64, "base64");
  const encrypted = Buffer.from(dataB64, "base64");

  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
  return decrypted.toString("utf8");
}

module.exports = { encrypt, decrypt, PREFIX };
