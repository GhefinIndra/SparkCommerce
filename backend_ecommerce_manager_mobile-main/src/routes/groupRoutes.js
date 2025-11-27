// routes/groupRoutes.js
const express = require('express');
const router = express.Router();
const { authenticateUserToken } = require('../middleware/auth');
const Group = require('../models/Group');
const axios = require('axios');

// Get group info by GID
router.get('/:gid', authenticateUserToken, async (req, res) => {
  try {
    const { gid } = req.params;

    // Find group by GID
    const group = await Group.findByGID(gid);

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found',
      });
    }

    // Return group info (without sensitive secret in response - will be sent in headers during webhook)
    res.json({
      success: true,
      data: {
        GID: group.GID,
        nama_group: group.nama_group,
        url: group.url,
        secret: group.secret, // Frontend needs this to send with webhook
        created_at: group.created_at,
        updated_at: group.updated_at,
      },
    });
  } catch (error) {
    console.error('Error fetching group:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message,
    });
  }
});

// Get all groups (admin only - optional)
router.get('/', authenticateUserToken, async (req, res) => {
  try {
    const groups = await Group.findAll({
      attributes: ['GID', 'nama_group', 'url', 'created_at', 'updated_at'],
      order: [['created_at', 'DESC']],
    });

    res.json({
      success: true,
      data: groups,
    });
  } catch (error) {
    console.error('Error fetching groups:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: error.message,
    });
  }
});

// Sync transactions to dashboard (proxy endpoint)
router.post('/sync-transactions', authenticateUserToken, async (req, res) => {
  try {
    const { group_id, shop_id, platform, transactions } = req.body;

    // Validate required fields
    if (!group_id || !shop_id || !platform || !transactions) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: group_id, shop_id, platform, transactions',
      });
    }

    // Get group info to get dashboard URL and secret
    const group = await Group.findByGID(group_id);
    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found',
      });
    }

    // Send to dashboard
    console.log(` Proxying ${transactions.length} transactions to dashboard: ${group.url}`);

    const dashboardResponse = await axios.post(
      group.url,
      {
        group_id,
        shop_id,
        platform,
        transactions,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Secret': group.secret,
        },
        timeout: 10000, // 10 seconds
      }
    );

    console.log(` Dashboard responded with status: ${dashboardResponse.status}`);

    // Return success
    res.json({
      success: true,
      message: 'Transactions synced to dashboard successfully',
      dashboard_status: dashboardResponse.status,
      synced_count: transactions.length,
    });

  } catch (error) {
    console.error(' Error syncing to dashboard:', error.message);

    // Check if error is from dashboard
    if (error.response) {
      return res.status(502).json({
        success: false,
        message: 'Dashboard returned error',
        dashboard_status: error.response.status,
        dashboard_error: error.response.data,
      });
    }

    // Network or other error
    res.status(500).json({
      success: false,
      message: 'Failed to sync to dashboard',
      error: error.message,
    });
  }
});

module.exports = router;
