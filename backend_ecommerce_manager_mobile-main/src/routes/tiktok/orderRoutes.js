const express = require("express");
const router = express.Router();
const OrderController = require("../../controllers/tiktok/orderController");
const { authenticateUserToken, verifyShopAccess } = require("../../middleware/auth");

const requireNotProduction = (req, res, next) => {
  if (process.env.NODE_ENV === "production") {
    return res.status(404).json({ success: false, message: "Not found" });
  }
  next();
};

// Test route
router.get("/test", requireNotProduction, async (req, res, next) => {
  try {
    await OrderController.testConnection(req, res);
  } catch (error) {
    next(error);
  }
});

// Debug tokens route
router.get("/debug-tokens", requireNotProduction, async (req, res, next) => {
  try {
    await OrderController.debugTokens(req, res);
  } catch (error) {
    next(error);
  }
});

// Order list routes
router.post("/:shopId/list", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

router.get("/:shopId/list", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  // Convert query params to body for consistency
  req.body = req.query.filters ? JSON.parse(req.query.filters) : req.query;

  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// Alternative route pattern with query params
router.post("/list", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

router.get("/list", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  // Convert query params to body
  req.body = req.query.filters ? JSON.parse(req.query.filters) : {};

  try {
    await OrderController.getOrderList(req, res);
  } catch (error) {
    next(error);
  }
});

// Order detail routes
router.get("/:shopId/detail/:orderIds", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.getOrderDetail(req, res);
  } catch (error) {
    next(error);
  }
});

router.get("/detail", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.getOrderDetail(req, res);
  } catch (error) {
    next(error);
  }
});

// Shipping routes
router.post("/:shopId/packages/:packageId/ship", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.shipPackage(req, res);
  } catch (error) {
    next(error);
  }
});

router.get(
  "/:shopId/packages/:packageId/shipping-document",
  authenticateUserToken,
  verifyShopAccess,
  async (req, res, next) => {
    try {
      await OrderController.getShippingDocument(req, res);
    } catch (error) {
      next(error);
    }
  },
);

router.get("/:shopId/packages/:packageId/detail", authenticateUserToken, verifyShopAccess, async (req, res, next) => {
  try {
    await OrderController.getPackageDetail(req, res);
  } catch (error) {
    next(error);
  }
});

// Debug route untuk cek semua routes terdaftar
router.get("/debug-routes", requireNotProduction, (req, res) => {
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
    message: "Order routes debug info",
    registeredRoutes: routes,
    totalRoutes: routes.length,
    timestamp: new Date().toISOString(),
  });
});

// Error handler
router.use((error, req, res, next) => {
  console.error("Order routes error:", error.message);

  // Check if response already sent
  if (res.headersSent) {
    return next(error);
  }

  res.status(500).json({
    success: false,
    message: error.message,
    stack: process.env.NODE_ENV === "development" ? error.stack : undefined,
    timestamp: new Date().toISOString(),
  });
});

module.exports = router;
