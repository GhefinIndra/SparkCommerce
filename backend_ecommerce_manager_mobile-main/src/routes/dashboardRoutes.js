const express = require("express");
const router = express.Router();
const dashboardController = require("../controllers/dashboardController");
const { authenticateUserToken } = require("../middleware/auth");

router.get("/stats", authenticateUserToken, dashboardController.getDashboardStats);

module.exports = router;
