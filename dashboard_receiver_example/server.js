// Dashboard Transaction Receiver - MySQL-backed implementation
// Receives transactions from SparkCommerce and stores them in MySQL.

require('dotenv').config();

const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const mysql = require('mysql2/promise');
const crypto = require('crypto');

const app = express();
const PORT = Number(process.env.DASHBOARD_PORT || 3001);

const LOGIN_USER = process.env.DASHBOARD_LOGIN_USER || 'admin';
const LOGIN_PASSWORD = process.env.DASHBOARD_LOGIN_PASSWORD || 'admin';
const SESSION_SECRET = process.env.DASHBOARD_SESSION_SECRET || 'change-this-secret';
const COOKIE_SECURE = process.env.DASHBOARD_COOKIE_SECURE === 'true';
const SESSION_TTL_MS = Number(process.env.DASHBOARD_SESSION_TTL_MS || 12 * 60 * 60 * 1000);
const DASHBOARD_GROUP_ID = process.env.DASHBOARD_GROUP_ID || '';
const RAW_BASE_PATH = process.env.DASHBOARD_BASE_PATH || '';
const BASE_PATH = RAW_BASE_PATH
  ? `/${RAW_BASE_PATH.replace(/^\/|\/$/g, '')}`
  : '';

if (!process.env.DASHBOARD_LOGIN_USER || !process.env.DASHBOARD_LOGIN_PASSWORD) {
  console.warn('Warning: DASHBOARD_LOGIN_USER or DASHBOARD_LOGIN_PASSWORD is not set.');
}
if (!process.env.DASHBOARD_SESSION_SECRET) {
  console.warn('Warning: DASHBOARD_SESSION_SECRET is not set.');
}

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// CORS - Allow requests from SparkCommerce app
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, X-Secret, User-Agent');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Serve static files (HTML, CSS, JS) from 'public' folder (no auto index)
app.use(express.static(path.join(__dirname, 'public'), { index: false }));

// Database (MySQL) - configure via environment variables
const dbConfig = {
  host: process.env.DASHBOARD_DB_HOST || '127.0.0.1',
  port: Number(process.env.DASHBOARD_DB_PORT || 3306),
  user: process.env.DASHBOARD_DB_USER || 'root',
  password: process.env.DASHBOARD_DB_PASSWORD || '',
  database: process.env.DASHBOARD_DB_NAME || 'sparkcommerce_dashboard',
  waitForConnections: true,
  connectionLimit: Number(process.env.DASHBOARD_DB_POOL || 10),
  queueLimit: 0,
};

const pool = mysql.createPool(dbConfig);

const allowedPlatforms = new Set(['TIKTOK', 'SHOPEE', 'TOKOPEDIA', 'LAZADA', 'BUKALAPAK']);

async function getGroupById(groupId) {
  const [rows] = await pool.query(
    'SELECT gid, nama_group, url, secret FROM dashboard_groups WHERE gid = ? LIMIT 1',
    [groupId],
  );
  return rows[0] || null;
}

async function getDashboardGroup() {
  if (DASHBOARD_GROUP_ID) {
    return getGroupById(DASHBOARD_GROUP_ID);
  }
  const [rows] = await pool.query(
    'SELECT gid, nama_group, url FROM dashboard_groups ORDER BY created_at DESC LIMIT 1',
  );
  return rows[0] || null;
}

function normalizePlatform(platform) {
  return String(platform || '').trim().toUpperCase();
}

function toNumber(value, fallback = 0) {
  const num = Number.parseFloat(value);
  return Number.isFinite(num) ? num : fallback;
}

function formatEpochSeconds(seconds) {
  if (!Number.isFinite(Number(seconds))) return 'N/A';
  return new Date(Number(seconds) * 1000).toLocaleString();
}

function parseCookies(req) {
  const header = req.headers.cookie || '';
  return header.split(';').reduce((acc, part) => {
    const [key, ...rest] = part.trim().split('=');
    if (!key) return acc;
    acc[key] = decodeURIComponent(rest.join('='));
    return acc;
  }, {});
}

function signPayload(payload) {
  return crypto.createHmac('sha256', SESSION_SECRET).update(payload).digest('hex');
}

function createSessionToken(user) {
  const expiresAt = Date.now() + SESSION_TTL_MS;
  const payload = Buffer.from(`${user}:${expiresAt}`).toString('base64');
  const signature = signPayload(payload);
  return `${payload}.${signature}`;
}

function verifySessionToken(token) {
  if (!token) return null;
  const [payload, signature] = token.split('.');
  if (!payload || !signature) return null;
  if (signPayload(payload) !== signature) return null;

  const decoded = Buffer.from(payload, 'base64').toString('utf8');
  const [user, expiresAt] = decoded.split(':');
  if (!user || !expiresAt) return null;
  if (Date.now() > Number(expiresAt)) return null;
  return user;
}

function setAuthCookie(res, token) {
  const parts = [
    `dashboard_auth=${encodeURIComponent(token)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
  ];
  if (COOKIE_SECURE) {
    parts.push('Secure');
  }
  res.setHeader('Set-Cookie', parts.join('; '));
}

function clearAuthCookie(res) {
  const parts = [
    'dashboard_auth=',
    'Path=/',
    'Max-Age=0',
    'HttpOnly',
    'SameSite=Lax',
  ];
  if (COOKIE_SECURE) {
    parts.push('Secure');
  }
  res.setHeader('Set-Cookie', parts.join('; '));
}

function requireAuth(req, res, next) {
  const cookies = parseCookies(req);
  const user = verifySessionToken(cookies.dashboard_auth);

  if (!user) {
    if (req.accepts('html')) {
      return res.redirect(`${BASE_PATH}/login`);
    }
    return res.status(401).json({
      success: false,
      message: 'Unauthorized',
    });
  }

  req.user = user;
  next();
}

// Login routes
app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.post('/login', (req, res) => {
  const { username, password } = req.body;

  if (username === LOGIN_USER && password === LOGIN_PASSWORD) {
    const token = createSessionToken(username);
    setAuthCookie(res, token);
    return res.redirect(`${BASE_PATH}/`);
  }

  return res.redirect(`${BASE_PATH}/login?error=1`);
});

app.post('/logout', (req, res) => {
  clearAuthCookie(res);
  res.json({ success: true });
});

// Dashboard UI
app.get('/', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/group-info', requireAuth, async (req, res) => {
  try {
    const group = await getDashboardGroup();
    res.json({
      success: true,
      data: group
        ? { gid: group.gid, nama_group: group.nama_group, url: group.url }
        : null,
    });
  } catch (error) {
    console.error('Error loading group info:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to load group info',
    });
  }
});

// Middleware to validate secret
async function validateSecret(req, res, next) {
  const secret = req.headers['x-secret'];
  const { group_id } = req.body;

  if (!group_id) {
    return res.status(400).json({
      success: false,
      message: 'group_id is required',
    });
  }

  try {
    const group = await getGroupById(group_id);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: `Group ${group_id} not found`,
      });
    }

    if (!secret || secret !== group.secret) {
      return res.status(401).json({
        success: false,
        message: 'Invalid secret key',
      });
    }

    req.group = group;
    next();
  } catch (error) {
    console.error('Error validating secret:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to validate secret',
    });
  }
}

// Main endpoint to receive transactions
app.post('/webhook/transactions', validateSecret, async (req, res) => {
  try {
    const {
      group_id,
      shop_id,
      platform,
      shop_name,
      sync_timestamp,
      transactions,
    } = req.body;

    if (!shop_id || !platform) {
      return res.status(400).json({
        success: false,
        message: 'shop_id and platform are required',
      });
    }

    if (!Array.isArray(transactions) || transactions.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'transactions must be a non-empty array',
      });
    }

    const normalizedPlatform = normalizePlatform(platform);
    if (!allowedPlatforms.has(normalizedPlatform)) {
      return res.status(400).json({
        success: false,
        message: `Invalid platform: ${platform}`,
      });
    }

    console.log('\n========================================');
    console.log('NEW TRANSACTIONS RECEIVED');
    console.log('========================================');
    console.log(`Group ID: ${group_id}`);
    console.log(`Shop ID: ${shop_id}`);
    console.log(`Platform: ${normalizedPlatform}`);
    console.log(`Shop Name: ${shop_name || 'N/A'}`);
    console.log(`Sync Time: ${formatEpochSeconds(sync_timestamp)}`);
    console.log(`Transaction Count: ${transactions.length}`);
    console.log('========================================\n');

    const connection = await pool.getConnection();
    let savedCount = 0;

    try {
      await connection.beginTransaction();

      const insertTransactionSql = `
        INSERT INTO transactions (
          group_id,
          shop_id,
          platform,
          order_id,
          order_status,
          total_amount,
          currency,
          create_time,
          update_time,
          paid_date,
          buyer_name,
          tracking_number,
          items_count,
          raw_payload
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          order_status = VALUES(order_status),
          total_amount = VALUES(total_amount),
          currency = VALUES(currency),
          update_time = VALUES(update_time),
          paid_date = VALUES(paid_date),
          buyer_name = VALUES(buyer_name),
          tracking_number = VALUES(tracking_number),
          items_count = VALUES(items_count),
          raw_payload = VALUES(raw_payload)
      `;

      for (const [index, transaction] of transactions.entries()) {
        if (!transaction || !transaction.order_id) {
          continue;
        }

        console.log(`[Transaction ${index + 1}]`);
        console.log(`  Order ID: ${transaction.order_id}`);
        console.log(`  Status: ${transaction.order_status}`);
        console.log(`  Amount: ${transaction.currency} ${transaction.total_amount}`);
        console.log(`  Items: ${transaction.items_count}`);
        console.log(`  Create Time: ${formatEpochSeconds(transaction.create_time)}`);

        const items = Array.isArray(transaction.items) ? transaction.items : [];
        items.forEach((item, itemIndex) => {
          console.log(`    [Item ${itemIndex + 1}] ${item.product_name} (${item.quantity}x @ ${item.price})`);
          console.log(`      SKU ID: ${item.sku_id}`);
          console.log(`      Seller SKU: ${item.seller_sku}`);
        });
        console.log('');

        const totalAmount = toNumber(transaction.total_amount, 0);
        const currency = transaction.currency || 'IDR';
        const itemsCount = Number.isFinite(Number(transaction.items_count))
          ? Number(transaction.items_count)
          : items.length;

        await connection.query(insertTransactionSql, [
          group_id,
          shop_id,
          normalizedPlatform,
          String(transaction.order_id),
          transaction.order_status || 'UNKNOWN',
          totalAmount,
          currency,
          transaction.create_time || null,
          transaction.update_time || null,
          transaction.paid_date || null,
          transaction.buyer_name || null,
          transaction.tracking_number || null,
          itemsCount,
          JSON.stringify(transaction),
        ]);

        const [txRows] = await connection.query(
          'SELECT id FROM transactions WHERE group_id = ? AND shop_id = ? AND platform = ? AND order_id = ? LIMIT 1',
          [group_id, shop_id, normalizedPlatform, String(transaction.order_id)],
        );

        const transactionId = txRows[0]?.id;
        if (!transactionId) {
          continue;
        }

        await connection.query(
          'DELETE FROM transaction_items WHERE transaction_id = ?',
          [transactionId],
        );

        if (items.length > 0) {
          const itemValues = items.map((item) => [
            transactionId,
            item.product_id || null,
            item.product_name || null,
            item.sku_id || null,
            item.seller_sku || null,
            Number(item.quantity || 0),
            toNumber(item.original_price, 0),
            toNumber(item.price, 0),
          ]);

          await connection.query(
            `INSERT INTO transaction_items (
              transaction_id,
              product_id,
              product_name,
              sku_id,
              seller_sku,
              quantity,
              original_price,
              price
            ) VALUES ?`,
            [itemValues],
          );
        }

        savedCount += 1;
      }

      await connection.commit();
    } catch (dbError) {
      await connection.rollback();
      throw dbError;
    } finally {
      connection.release();
    }

    const [countRows] = await pool.query('SELECT COUNT(*) as total FROM transactions');
    const totalCount = countRows[0]?.total || 0;

    console.log(`Saved ${savedCount} transactions to database`);
    console.log(`Total transactions in DB: ${totalCount}\n`);

    res.json({
      success: true,
      message: `Received ${savedCount} transactions`,
      data: {
        received_count: savedCount,
        total_in_database: totalCount,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Error processing transactions:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message,
    });
  }
});

// Endpoint to view all received transactions
app.get('/transactions', requireAuth, async (req, res) => {
  const { group_id, shop_id, platform } = req.query;

  const filters = [];
  const params = [];

  if (group_id) {
    filters.push('group_id = ?');
    params.push(group_id);
  }
  if (shop_id) {
    filters.push('shop_id = ?');
    params.push(shop_id);
  }
  if (platform) {
    filters.push('platform = ?');
    params.push(normalizePlatform(platform));
  }

  const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

  try {
    const [rows] = await pool.query(
      `SELECT * FROM transactions ${whereClause} ORDER BY received_at DESC LIMIT 200`,
      params,
    );

    if (rows.length > 0) {
      const ids = rows.map((row) => row.id);
      const placeholders = ids.map(() => '?').join(',');
      const [itemRows] = await pool.query(
        `SELECT * FROM transaction_items WHERE transaction_id IN (${placeholders})`,
        ids,
      );

      const itemsByTx = {};
      itemRows.forEach((item) => {
        if (!itemsByTx[item.transaction_id]) {
          itemsByTx[item.transaction_id] = [];
        }
        itemsByTx[item.transaction_id].push(item);
      });

      rows.forEach((row) => {
        row.items = itemsByTx[row.id] || [];
        if (row.raw_payload && typeof row.raw_payload === 'string') {
          try {
            row.raw_payload = JSON.parse(row.raw_payload);
          } catch (_) {
            // keep raw string if parsing fails
          }
        }
      });
    }

    res.json({
      success: true,
      data: {
        total: rows.length,
        transactions: rows,
      },
    });
  } catch (error) {
    console.error('Error loading transactions:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to load transactions',
    });
  }
});

// Endpoint to get transaction statistics
app.get('/stats', requireAuth, async (req, res) => {
  try {
    const [[totalRow]] = await pool.query('SELECT COUNT(*) as total FROM transactions');
    const [platformRows] = await pool.query(
      'SELECT platform, COUNT(*) as total FROM transactions GROUP BY platform',
    );
    const [revenueRows] = await pool.query(
      'SELECT currency, SUM(total_amount) as total FROM transactions GROUP BY currency',
    );

    const byPlatform = {};
    platformRows.forEach((row) => {
      byPlatform[row.platform] = row.total;
    });

    const totalRevenue = {};
    revenueRows.forEach((row) => {
      totalRevenue[row.currency || 'IDR'] = Number(row.total || 0);
    });

    res.json({
      success: true,
      data: {
        total_transactions: totalRow?.total || 0,
        by_platform: byPlatform,
        total_revenue: totalRevenue,
      },
    });
  } catch (error) {
    console.error('Error loading stats:', error.message);
    res.status(500).json({
      success: false,
      message: 'Failed to load stats',
    });
  }
});

// Health check
app.get('/health', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.ping();
    connection.release();

    res.json({
      status: 'OK',
      service: 'Dashboard Transaction Receiver',
      version: '1.2.0',
      timestamp: new Date().toISOString(),
      database: 'connected',
    });
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      service: 'Dashboard Transaction Receiver',
      version: '1.2.0',
      timestamp: new Date().toISOString(),
      database: 'disconnected',
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log('\n========================================');
  console.log('Dashboard Transaction Receiver');
  console.log('========================================');
  console.log(`Server running on: http://localhost:${PORT}`);
  console.log(`Webhook endpoint: http://localhost:${PORT}/webhook/transactions`);
  console.log(`Database: ${dbConfig.database}`);
  console.log('========================================\n');
});
