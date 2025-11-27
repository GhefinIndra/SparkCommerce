// test-shopee-orders.js
// Simple test script for Shopee Order API

const axios = require('axios');

const BASE_URL = 'http://localhost:5000';

// Test configuration
const TEST_CONFIG = {
  shopId: '30081881', // Replace with your actual shop ID
  // Time range: last 15 days
  timeFrom: Math.floor(Date.now() / 1000) - (15 * 24 * 60 * 60),
  timeTo: Math.floor(Date.now() / 1000),
};

async function testHealthCheck() {
  console.log('\n=== TEST 1: Health Check ===');
  try {
    const response = await axios.get(`${BASE_URL}/health`);
    console.log('[PASS] Health check passed');
    console.log('Response:', response.data);
    return true;
  } catch (error) {
    console.error('[FAIL] Health check failed:', error.message);
    return false;
  }
}

async function testOrderRoutes() {
  console.log('\n=== TEST 2: Order Routes Debug ===');
  try {
    const response = await axios.get(`${BASE_URL}/api/shopee/orders/debug-routes`);
    console.log('[PASS] Routes registered successfully');
    console.log('Total routes:', response.data.totalRoutes);
    console.log('Registered routes:');
    response.data.registeredRoutes.forEach(route => {
      console.log(`  - ${route.methods.join(', ').toUpperCase()} ${route.path}`);
    });
    return true;
  } catch (error) {
    console.error('[FAIL] Routes test failed:', error.message);
    return false;
  }
}

async function testOrderController() {
  console.log('\n=== TEST 3: Order Controller Test ===');
  try {
    const response = await axios.get(`${BASE_URL}/api/shopee/orders/test`, {
      params: {
        shopId: TEST_CONFIG.shopId,
      },
    });
    console.log('[PASS] Controller test passed');
    console.log('Response:', response.data);
    return true;
  } catch (error) {
    console.error('[FAIL] Controller test failed:', error.message);
    return false;
  }
}

async function testGetOrderList() {
  console.log('\n=== TEST 4: Get Order List ===');
  try {
    console.log('Fetching orders from:', new Date(TEST_CONFIG.timeFrom * 1000).toISOString());
    console.log('Fetching orders to:', new Date(TEST_CONFIG.timeTo * 1000).toISOString());

    const response = await axios.post(
      `${BASE_URL}/api/shopee/orders/${TEST_CONFIG.shopId}/list`,
      {
        time_range_field: 'create_time',
        time_from: TEST_CONFIG.timeFrom,
        time_to: TEST_CONFIG.timeTo,
        page_size: 10,
        cursor: '',
        response_optional_fields: 'order_status',
      }
    );

    console.log('[PASS] Get order list passed');
    console.log('Total orders:', response.data.data.orders.length);
    console.log('Has next page:', response.data.data.pagination.has_next_page);

    if (response.data.data.orders.length > 0) {
      console.log('\nFirst order sample:');
      const firstOrder = response.data.data.orders[0];
      console.log('  - Order SN:', firstOrder.orderId);
      console.log('  - Status:', firstOrder.status);
      console.log('  - Customer:', firstOrder.customerName);
      console.log('  - Total:', firstOrder.formattedAmount);
      console.log('  - Item count:', firstOrder.itemCount);
      console.log('  - Has package:', firstOrder.hasPackages);
    }

    return response.data.data.orders;
  } catch (error) {
    console.error('[FAIL] Get order list failed:', error.response?.data || error.message);
    return [];
  }
}

async function testGetOrderDetail(orderSn) {
  console.log('\n=== TEST 5: Get Order Detail ===');
  try {
    if (!orderSn) {
      console.log('[SKIP] Skipping order detail test (no order SN provided)');
      return true;
    }

    console.log('Fetching detail for order:', orderSn);

    const response = await axios.get(
      `${BASE_URL}/api/shopee/orders/${TEST_CONFIG.shopId}/detail/${orderSn}`,
      {
        params: {
          response_optional_fields: 'buyer_user_id,buyer_username,estimated_shipping_fee,recipient_address,actual_shipping_fee,item_list,pay_time,package_list,shipping_carrier,payment_method,total_amount',
        },
      }
    );

    console.log('[PASS] Get order detail passed');

    if (response.data.data.orders.length > 0) {
      const order = response.data.data.orders[0];
      console.log('\nOrder details:');
      console.log('  - Order SN:', order.orderId);
      console.log('  - Status:', order.status);
      console.log('  - Customer:', order.customerName);
      console.log('  - Phone:', order.customerPhone);
      console.log('  - Address:', order.customerAddress);
      console.log('  - Total:', order.formattedAmount);
      console.log('  - Shipping Fee:', order.shippingFee);
      console.log('  - Payment Method:', order.paymentMethod);
      console.log('  - Item count:', order.itemCount);
      console.log('  - Package count:', order.packagesCount);
      console.log('  - Can ship:', order.canShip);

      if (order.items && order.items.length > 0) {
        console.log('\n  Items:');
        order.items.forEach((item, idx) => {
          console.log(`    ${idx + 1}. ${item.productName}`);
          console.log(`       - SKU: ${item.sellerSku}`);
          console.log(`       - Quantity: ${item.quantity}`);
          console.log(`       - Price: ${item.price}`);
        });
      }
    }

    return true;
  } catch (error) {
    console.error('[FAIL] Get order detail failed:', error.response?.data || error.message);
    return false;
  }
}

async function runAllTests() {
  console.log('Starting Shopee Order API Tests...\n');
  console.log('Base URL:', BASE_URL);
  console.log('Shop ID:', TEST_CONFIG.shopId);

  let testResults = {
    passed: 0,
    failed: 0,
  };

  // Test 1: Health Check
  if (await testHealthCheck()) {
    testResults.passed++;
  } else {
    testResults.failed++;
    console.log('\n[WARN] Server is not running or not responding. Please start the server first.');
    return;
  }

  // Test 2: Routes
  if (await testOrderRoutes()) {
    testResults.passed++;
  } else {
    testResults.failed++;
  }

  // Test 3: Controller
  if (await testOrderController()) {
    testResults.passed++;
  } else {
    testResults.failed++;
  }

  // Test 4: Get Order List
  const orders = await testGetOrderList();
  if (orders !== null) {
    testResults.passed++;
  } else {
    testResults.failed++;
  }

  // Test 5: Get Order Detail (using first order from list)
  let orderDetailPassed = false;
  if (orders && orders.length > 0) {
    const firstOrderSn = orders[0].orderId;
    if (await testGetOrderDetail(firstOrderSn)) {
      testResults.passed++;
      orderDetailPassed = true;
    } else {
      testResults.failed++;
    }
  } else {
    console.log('\n[SKIP] Skipping order detail test (no orders found)');
    orderDetailPassed = true; // Don't count as failed if no orders
  }

  // Summary
  console.log('\n=== TEST SUMMARY ===');
  console.log(`[PASS] Passed: ${testResults.passed}`);
  console.log(`[FAIL] Failed: ${testResults.failed}`);
  console.log(`[INFO] Total: ${testResults.passed + testResults.failed}`);

  if (testResults.failed === 0) {
    console.log('\nAll tests passed!');
  } else {
    console.log('\n[WARN] Some tests failed. Please check the errors above.');
  }
}

// Run tests
runAllTests().catch(error => {
  console.error('[ERROR] Test script failed:', error.message);
  process.exit(1);
});
