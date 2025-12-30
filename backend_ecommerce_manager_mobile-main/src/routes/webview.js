// src/routes/webview.js
const express = require('express');
const router = express.Router();

// Success page for WebView OAuth callback
router.get('/success', (req, res) => {
  const { platform, shopId, openId, seller } = req.query;

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Success</title>
      <style>
        body {
          font-family: sans-serif;
          text-align: center;
          padding: 50px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          margin: 0;
        }
        .container {
          max-width: 400px;
          margin: 0 auto;
        }
        .icon {
          font-size: 80px;
          margin-bottom: 20px;
        }
        h1 {
          font-size: 24px;
          margin-bottom: 10px;
        }
        p {
          font-size: 16px;
          opacity: 0.9;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">✓</div>
        <h1>Authorization Successful!</h1>
        <p>Toko berhasil ditambahkan</p>
        <p style="font-size: 14px; margin-top: 20px;">Menutup jendela...</p>
      </div>
    </body>
    </html>
  `);
});

// Error page for WebView OAuth callback
router.get('/error', (req, res) => {
  const { message } = req.query;

  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Error</title>
      <style>
        body {
          font-family: sans-serif;
          text-align: center;
          padding: 50px;
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
          color: white;
          margin: 0;
        }
        .container {
          max-width: 400px;
          margin: 0 auto;
        }
        .icon {
          font-size: 80px;
          margin-bottom: 20px;
        }
        h1 {
          font-size: 24px;
          margin-bottom: 10px;
        }
        p {
          font-size: 16px;
          opacity: 0.9;
        }
        .error-message {
          background: rgba(255, 255, 255, 0.2);
          padding: 15px;
          border-radius: 8px;
          margin-top: 20px;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">✕</div>
        <h1>Authorization Failed</h1>
        <p>Gagal menambahkan toko</p>
        ${message ? `<div class="error-message">${decodeURIComponent(message)}</div>` : ''}
      </div>
    </body>
    </html>
  `);
});

module.exports = router;
