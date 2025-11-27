// Dashboard Transaction Receiver - Example Implementation
// This is a simple Node.js/Express server that receives transactions from SparkCommerce app

const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const app = express();
const PORT = 3001;

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve static files (HTML, CSS, JS) from 'public' folder
app.use(express.static(path.join(__dirname, 'public')));

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

// In-memory storage (replace with real database in production)
const transactionsDB = [];
const groupSecrets = {
  // Add your group secrets here:
  // 'YOUR_GROUP_ID': 'your-secret-key',
};

// Middleware to validate secret
function validateSecret(req, res, next) {
  const secret = req.headers['x-secret'];
  const { group_id } = req.body;

  if (!group_id) {
    return res.status(400).json({
      success: false,
      message: 'group_id is required',
    });
  }

  const expectedSecret = groupSecrets[group_id];

  if (!expectedSecret) {
    return res.status(404).json({
      success: false,
      message: `Group ${group_id} not found`,
    });
  }

  if (secret !== expectedSecret) {
    return res.status(401).json({
      success: false,
      message: 'Invalid secret key',
    });
  }

  next();
}

// Main endpoint to receive transactions
app.post('/webhook/transactions', validateSecret, (req, res) => {
  try {
    const {
      group_id,
      shop_id,
      platform,
      shop_name,
      sync_timestamp,
      transactions
    } = req.body;

    console.log('\n========================================')
    console.log('NEW TRANSACTIONS RECEIVED');
    console.log('========================================')
    console.log(`Group ID: ${group_id}`);
    console.log(`Shop ID: ${shop_id}`);
    console.log(`Platform: ${platform}`);
    console.log(`Shop Name: ${shop_name || 'N/A'}`);
    console.log(`Sync Time: ${new Date(sync_timestamp * 1000).toLocaleString()}`);
    console.log(`Transaction Count: ${transactions.length}`);
    console.log('========================================\n');

    // Process each transaction
    transactions.forEach((transaction, index) => {
      console.log(`[Transaction ${index + 1}]`);
      console.log(`  Order ID: ${transaction.order_id}`);
      console.log(`  Status: ${transaction.order_status}`);
      console.log(`  Amount: ${transaction.currency} ${transaction.total_amount}`);
      console.log(`  Items: ${transaction.items_count}`);
      console.log(`  Create Time: ${new Date(transaction.create_time * 1000).toLocaleString()}`);

      // List items
      transaction.items.forEach((item, itemIndex) => {
        console.log(`    [Item ${itemIndex + 1}] ${item.product_name} (${item.quantity}x @ ${item.price})`);
        console.log(`      SKU ID: ${item.sku_id}`);
        console.log(`      Seller SKU: ${item.seller_sku}`);
      });
      console.log('');

      // Save to database (in-memory for this example)
      transactionsDB.push({
        ...transaction,
        group_id,
        shop_id,
        platform,
        received_at: new Date(),
      });
    });

    console.log(`Saved ${transactions.length} transactions to database`);
    console.log(`Total transactions in DB: ${transactionsDB.length}\n`);

    // Send success response
    res.json({
      success: true,
      message: `Received ${transactions.length} transactions`,
      data: {
        received_count: transactions.length,
        total_in_database: transactionsDB.length,
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

// Endpoint to view all received transactions (for testing)
app.get('/transactions', (req, res) => {
  const { group_id, shop_id, platform } = req.query;

  let filtered = transactionsDB;

  if (group_id) {
    filtered = filtered.filter(t => t.group_id === group_id);
  }
  if (shop_id) {
    filtered = filtered.filter(t => t.shop_id === shop_id);
  }
  if (platform) {
    filtered = filtered.filter(t => t.platform === platform);
  }

  res.json({
    success: true,
    data: {
      total: filtered.length,
      transactions: filtered,
    },
  });
});

// Endpoint to get transaction statistics
app.get('/stats', (req, res) => {
  const stats = {
    total_transactions: transactionsDB.length,
    by_platform: {},
    total_revenue: {},
  };

  transactionsDB.forEach(transaction => {
    // Count by platform
    stats.by_platform[transaction.platform] = (stats.by_platform[transaction.platform] || 0) + 1;

    // Sum revenue by currency (from total_amount in transaction)
    const amount = parseFloat(transaction.total_amount) || 0;
    const currency = transaction.currency || 'IDR';
    stats.total_revenue[currency] = (stats.total_revenue[currency] || 0) + amount;
  });

  res.json({
    success: true,
    data: stats,
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    service: 'Dashboard Transaction Receiver',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Dashboard Transaction Receiver API',
    version: '1.0.0',
    endpoints: {
      webhook: 'POST /webhook/transactions',
      list: 'GET /transactions?group_id=X&shop_id=Y&platform=Z',
      stats: 'GET /stats',
      health: 'GET /health',
    },
  });
});

// Start server
app.listen(PORT, () => {
  console.log('\n========================================')
  console.log('Dashboard Transaction Receiver');
  console.log('========================================')
  console.log(`Server running on: http://localhost:${PORT}`);
  console.log(`Webhook endpoint: http://localhost:${PORT}/webhook/transactions`);
  console.log('========================================\n');
  console.log('Registered Groups:');
  Object.keys(groupSecrets).forEach(groupId => {
    console.log(`  - ${groupId}: ${groupSecrets[groupId]}`);
  });
  console.log('\n========================================\n');
});
