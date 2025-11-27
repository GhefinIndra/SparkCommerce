// src/routes/shopee/orderRoutes.js
const express = require('express');
const router = express.Router();
const OrderController = require('../../controllers/shopee/orderController');

// Test route
router.get('/test', async (req, res, next) => {
  try {
    await OrderController.testConnection(req, res);
  } catch (error) {
    next(error);
  }
});

// Order list routes
// POST /api/shopee/orders/:shopId/list
router.post('/:shopId/list', async (req, res, next) => {
  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// GET /api/shopee/orders/:shopId/list (with query params)
router.get('/:shopId/list', async (req, res, next) => {
  // Convert query params to body for consistency
  req.body = req.query.filters ? JSON.parse(req.query.filters) : req.query;

  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// Alternative route pattern with query params
// POST /api/shopee/orders/list
router.post('/list', async (req, res, next) => {
  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// GET /api/shopee/orders/list
router.get('/list', async (req, res, next) => {
  // Convert query params to body
  req.body = req.query.filters ? JSON.parse(req.query.filters) : {};

  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// Order detail routes
// GET /api/shopee/orders/:shopId/detail/:orderSns
// orderSns can be comma-separated list: "order1,order2,order3"
router.get('/:shopId/detail/:orderSns', async (req, res, next) => {
  try {
    await OrderController.getOrderDetail(req, res);
  } catch (error) {
    next(error);
  }
});

// GET /api/shopee/orders/detail
router.get('/detail', async (req, res, next) => {
  try {
    await OrderController.getOrderDetail(req, res);
  } catch (error) {
    next(error);
  }
});

// Shipping routes
// POST /api/shopee/orders/:shopId/ship/:orderSn
router.post('/:shopId/ship/:orderSn', async (req, res, next) => {
  try {
    await OrderController.shipOrder(req, res);
  } catch (error) {
    next(error);
  }
});

// GET /api/shopee/orders/:shopId/tracking/:orderSn
router.get('/:shopId/tracking/:orderSn', async (req, res, next) => {
  try {
    await OrderController.getTrackingNumber(req, res);
  } catch (error) {
    next(error);
  }
});

// Debug route to check all registered routes
router.get('/debug-routes', (req, res) => {
  const routes = [];

  router.stack.forEach((layer) => {
    if (layer.route) {
      routes.push({
        path: layer.route.path,
        methods: Object.keys(layer.route.methods),
        stack: layer.route.stack.length,
      });
    }
  });

  res.json({
    success: true,
    message: 'Shopee Order routes debug info',
    registeredRoutes: routes,
    totalRoutes: routes.length,
    timestamp: new Date().toISOString(),
  });
});

// Error handler
router.use((error, req, res, next) => {
  console.error('Shopee Order routes error:', error.message);

  // Check if response already sent
  if (res.headersSent) {
    return next(error);
  }

  res.status(500).json({
    success: false,
    message: error.message,
    stack: process.env.NODE_ENV === 'development' ? error.stack : undefined,
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
