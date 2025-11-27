# Dashboard Transaction Receiver

Example implementation of an external dashboard webhook receiver for SparkCommerce transaction synchronization. Demonstrates group-based data isolation and secure webhook handling.

## Overview

This Node.js application serves as a reference implementation for receiving and processing order transactions from SparkCommerce mobile application. Each group maintains an independent dashboard instance with isolated data.

## Features

- Multi-platform transaction ingestion (TikTok Shop, Shopee)
- HMAC-based webhook authentication per group
- Shop-level and platform-level data filtering
- Real-time transaction statistics
- In-memory storage (production should use persistent database)
- Simple web UI for transaction monitoring

## Group Isolation Model

Each business group operates an independent dashboard instance:

- Group A: `http://groupa-server.com:3001` - receives only Group A transactions
- Group B: `http://groupb-server.com:3001` - receives only Group B transactions

Groups cannot access each other's data. Complete separation of business intelligence.

## 🚀 Cara Install & Menjalankan

### 1. Install Dependencies

```bash
cd dashboard_receiver_example
npm install
```

### 2. Jalankan Server

```bash
npm start
```

Atau untuk development dengan auto-reload:

```bash
npm run dev
```

Server akan berjalan di **http://localhost:3001**

## 🔧 Konfigurasi

### Tambah/Edit Group Secret

Edit file `server.js` pada bagian `groupSecrets`:

```javascript
const groupSecrets = {
  'TELKOM001': 'mySecretKey123',  // Group ID TELKOM001
  'GROUP002': 'anotherSecret456',  // Group ID GROUP002
  // Tambahkan group baru di sini
};
```

### Setup di Database SparkCommerce

1. Buka database MySQL/MariaDB SparkCommerce
2. Insert data group ke tabel `groups`:

```sql
INSERT INTO groups (GID, nama_group, url, secret, created_at, updated_at)
VALUES (
  'TELKOM001',
  'Group Telkom',
  'http://YOUR_SERVER_IP:3001/webhook/transactions',  -- Ganti dengan IP server dashboard Anda
  'mySecretKey123',
  NOW(),
  NOW()
);
```

**Catatan Penting:**
- Jika dashboard di server yang sama dengan backend: gunakan `http://localhost:3001/webhook/transactions`
- Jika dashboard di server berbeda: gunakan `http://IP_SERVER:3001/webhook/transactions`
- Jangan gunakan `10.0.2.2` karena itu khusus untuk Android Emulator

### Setup User dengan Group

Update user agar punya `group_id`:

```sql
UPDATE users
SET group_id = 'TELKOM001'
WHERE email = 'user@example.com';
```

## 📡 API Endpoints

### 1. Webhook - Terima Transaksi (POST)

**Endpoint:** `POST /webhook/transactions`

**Headers:**
- `Content-Type: application/json`
- `X-Secret: mySecretKey123` (sesuai dengan secret di database)

**Request Body:**
```json
{
  "group_id": "TELKOM001",
  "shop_id": "123456",
  "platform": "TIKTOK",
  "shop_name": "Toko Saya",
  "sync_timestamp": 1704672500,
  "transactions": [
    {
      "order_id": "TT20250108001",
      "order_status": "DELIVERED",
      "total_amount": "150000",
      "currency": "IDR",
      "create_time": 1704672000,
      "update_time": 1704672300,
      "paid_date": "2025-01-08 10:30:00",
      "buyer_name": "Customer Name",
      "tracking_number": "JNE123456",
      "items_count": 2,
      "items": [
        {
          "product_id": "prod123",
          "product_name": "Product A",
          "sku_id": "sku_abc",
          "seller_sku": "SKU-001",
          "quantity": 2,
          "original_price": "75000",
          "price": "70000"
        }
      ]
    }
  ]
}
```

**Response Success:**
```json
{
  "success": true,
  "message": "Received 1 transactions",
  "data": {
    "received_count": 1,
    "total_in_database": 15,
    "timestamp": "2025-01-08T10:45:00.000Z"
  }
}
```

**Response Error - Invalid Secret:**
```json
{
  "success": false,
  "message": "Invalid secret key"
}
```

### 2. List Transaksi (GET)

**Endpoint:** `GET /transactions`

**Query Parameters:**
- `shop_id` (optional): Filter by shop
- `platform` (optional): Filter by platform (TIKTOK/SHOPEE)

**Example:**
```
GET /transactions?shop_id=123456&platform=TIKTOK
```

**Response:**
```json
{
  "success": true,
  "data": {
    "total": 10,
    "transactions": [...]
  }
}
```

### 3. Statistik (GET)

**Endpoint:** `GET /stats`

**Response:**
```json
{
  "success": true,
  "data": {
    "total_transactions": 50,
    "by_platform": {
      "TIKTOK": 30,
      "SHOPEE": 20
    },
    "total_revenue": {
      "IDR": 15000000
    }
  }
}
```

### 4. Health Check (GET)

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "OK",
  "service": "Dashboard Transaction Receiver",
  "version": "1.0.0",
  "timestamp": "2025-01-08T10:45:00.000Z"
}
```

## 🔍 Testing

### Test dengan CURL

```bash
# Test webhook endpoint
curl -X POST http://localhost:3001/webhook/transactions \
  -H "Content-Type: application/json" \
  -H "X-Secret: mySecretKey123" \
  -d '{
    "group_id": "TELKOM001",
    "shop_id": "123456",
    "platform": "TIKTOK",
    "sync_timestamp": 1704672500,
    "transactions": [
      {
        "order_id": "TEST001",
        "order_status": "DELIVERED",
        "total_amount": "100000",
        "currency": "IDR",
        "create_time": 1704672000,
        "update_time": 1704672300,
        "items_count": 1,
        "items": []
      }
    ]
  }'

# List transaksi
curl http://localhost:3001/transactions

# Statistik
curl http://localhost:3001/stats
```

### Test dengan Postman

1. Import collection dari `postman_collection.json` (akan dibuat)
2. Test endpoint webhook dengan body JSON di atas
3. Cek response dan console log

## 📊 Flow Lengkap

```
User klik "Lihat Pesanan" di App
    ↓
App fetch orders dari backend SparkCommerce
    ↓
App simpan ke SQLite lokal
    ↓
App reduce stock (SKU Master)
    ↓
App cek user punya group_id?
    ├─ Tidak → Stop (tidak ada dashboard sync)
    └─ Ya → Lanjut
    ↓
App ambil group info dari backend (GET /api/groups/{GID})
    ↓
App dapat dashboard URL & secret
    ↓
App filter order baru (compare dengan transaction_sync_log)
    ↓
App kirim POST ke dashboard URL dengan secret di header
    ↓
Dashboard terima & validasi secret
    ↓
Dashboard simpan transaksi ke database
    ↓
Dashboard response success
    ↓
App update transaction_sync_log
```

## 🔒 Security

1. **Secret Validation**: Setiap request harus include secret yang valid di header `X-Secret`
2. **CORS**: Configure CORS sesuai kebutuhan (default: allow all)
3. **Rate Limiting**: Tambahkan rate limiting untuk production
4. **HTTPS**: Gunakan HTTPS di production (bisa pakai nginx sebagai reverse proxy)

## 🗄️ Database Integration (Production)

Untuk production, ganti in-memory storage dengan database real:

### Contoh dengan MySQL

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'dashboard_db',
  waitForConnections: true,
  connectionLimit: 10,
});

// Di dalam endpoint POST /webhook/transactions
app.post('/webhook/transactions', validateSecret, async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    for (const transaction of transactions) {
      await connection.execute(
        'INSERT INTO transactions (order_id, shop_id, platform, ...) VALUES (?, ?, ?, ...)',
        [transaction.order_id, shop_id, platform, ...]
      );
    }

    await connection.commit();
    res.json({ success: true, ... });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ success: false, ... });
  } finally {
    connection.release();
  }
});
```

## 📝 Logs

Server akan print log setiap kali menerima transaksi:

```
========================================
📦 NEW TRANSACTIONS RECEIVED
========================================
Group ID: TELKOM001
Shop ID: 123456
Platform: TIKTOK
Sync Time: 1/8/2025, 10:45:00 AM
Transaction Count: 2
========================================

[Transaction 1]
  Order ID: TT20250108001
  Status: DELIVERED
  Amount: IDR 150000
  Items: 2
  Create Time: 1/8/2025, 10:30:00 AM
    [Item 1] Product A (2x @ 70000)
      SKU ID: sku_abc
      Seller SKU: SKU-001

✅ Saved 2 transactions to database
📊 Total transactions in DB: 15
```

## 🚧 Troubleshooting

### Error: "Cannot POST /webhook/transactions"

- Pastikan server sudah running
- Cek URL endpoint sudah benar
- Pastikan method POST (bukan GET)

### Error: "Invalid secret key"

- Cek secret di header `X-Secret` sama dengan di `groupSecrets`
- Pastikan group_id valid

### Error: "group_id not found"

- Pastikan group_id ada di tabel `groups` di database SparkCommerce
- Pastikan user sudah punya `group_id` di tabel `users`

### Dashboard tidak menerima transaksi dari app

1. Cek URL di tabel `groups` sudah benar
2. Pastikan dashboard server bisa diakses dari backend SparkCommerce
3. Cek firewall tidak block port 3001
4. Cek logs di dashboard server (console)
5. Cek logs di app Flutter (debug console)

## 📱 Next Steps

1. Buat UI dashboard untuk visualisasi transaksi
2. Tambah autentikasi untuk endpoint GET
3. Implement real database (MySQL/PostgreSQL)
4. Deploy ke server production
5. Setup monitoring & alerting

## 📞 Support

Jika ada pertanyaan atau issue, silakan hubungi tim development.
