# PostgreSQL VPS Setup Guide
## Server: 103.38.109.27

---

## Quick Setup (Automated)

### 1. Upload Script ke VPS
```powershell
# Dari PowerShell di Windows
scp C:\infomedia\SparkCommerce\database\setup_postgresql_vps.sh root@103.38.109.27:/tmp/
scp C:\infomedia\SparkCommerce\database\ecommerce_manager_postgres.sql root@103.38.109.27:/tmp/
```

### 2. SSH ke VPS dan Jalankan Script
```bash
ssh root@103.38.109.27

# Jalankan setup script
chmod +x /tmp/setup_postgresql_vps.sh
/tmp/setup_postgresql_vps.sh

# Import schema
sudo -u postgres psql -d ecommerce_manager -f /tmp/ecommerce_manager_postgres.sql
```

---

## Manual Setup (Step by Step)

### Step 1: SSH ke VPS
```bash
ssh root@103.38.109.27
```

### Step 2: Install PostgreSQL
```bash
apt update && apt upgrade -y
apt install postgresql postgresql-contrib -y
systemctl start postgresql
systemctl enable postgresql
```

### Step 3: Create Database & User
```bash
sudo -u postgres psql
```

Di dalam psql:
```sql
CREATE USER sparkcommerce WITH PASSWORD 'GantiDenganPasswordAman123!';
CREATE DATABASE ecommerce_manager OWNER sparkcommerce;
GRANT ALL PRIVILEGES ON DATABASE ecommerce_manager TO sparkcommerce;
\c ecommerce_manager
GRANT ALL ON SCHEMA public TO sparkcommerce;
\q
```

### Step 4: Enable Remote Access

Edit postgresql.conf:
```bash
nano /etc/postgresql/*/main/postgresql.conf
```
Ubah:
```
listen_addresses = '*'
```

Edit pg_hba.conf:
```bash
nano /etc/postgresql/*/main/pg_hba.conf
```
Tambahkan di akhir:
```
host    ecommerce_manager    sparkcommerce    0.0.0.0/0    md5
```

### Step 5: Firewall & Restart
```bash
ufw allow 5432/tcp
systemctl restart postgresql
```

### Step 6: Import Schema
```bash
sudo -u postgres psql -d ecommerce_manager -f /tmp/ecommerce_manager_postgres.sql
```

### Step 7: Verify
```bash
# Test login
psql -h 103.38.109.27 -U sparkcommerce -d ecommerce_manager

# Check tables
\dt
```

---

## Backend Configuration

Update file `.env` di `backend_ecommerce_manager_mobile-main/`:

```env
# PostgreSQL VPS Configuration
DB_HOST=103.38.109.27
DB_NAME=ecommerce_manager
DB_USERNAME=sparkcommerce
DB_PASSWORD=GantiDenganPasswordAman123!
DB_PORT=5432
DB_DIALECT=postgres
DB_SSL=false
```

---

## Test Connection dari Local

```bash
# Dari komputer lokal, test koneksi:
psql -h 103.38.109.27 -U sparkcommerce -d ecommerce_manager -W
```

Atau jalankan backend:
```bash
cd backend_ecommerce_manager_mobile-main
npm install
npm start
```

---

## Apache + Node.js (Reverse Proxy)

Jika ingin backend berjalan di belakang Apache:

### 1. Enable mod_proxy
```bash
a2enmod proxy
a2enmod proxy_http
systemctl restart apache2
```

### 2. Konfigurasi Virtual Host
```bash
nano /etc/apache2/sites-available/sparkcommerce.conf
```

```apache
<VirtualHost *:80>
    ServerName spark.tuantoko.com
    
    # Reverse proxy ke Node.js
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:5001/
    ProxyPassReverse / http://127.0.0.1:5001/
    
    # Logging
    ErrorLog ${APACHE_LOG_DIR}/sparkcommerce_error.log
    CustomLog ${APACHE_LOG_DIR}/sparkcommerce_access.log combined
</VirtualHost>
```

```bash
a2ensite sparkcommerce.conf
systemctl reload apache2
```

### 3. Jalankan Backend dengan PM2
```bash
# Install PM2
npm install -g pm2

# Start backend
cd /path/to/backend_ecommerce_manager_mobile-main
pm2 start server.js --name sparkcommerce
pm2 save
pm2 startup
```

---

## Security Recommendations

1. **Ganti password default** - Jangan gunakan password contoh!
2. **Batasi IP access** - Di pg_hba.conf, ganti `0.0.0.0/0` dengan IP spesifik
3. **Enable SSL** - Untuk production, aktifkan SSL:
   ```env
   DB_SSL=true
   ```
4. **Firewall** - Hanya buka port yang diperlukan
5. **Backup regular** - Setup cronjob untuk backup database

---

## Troubleshooting

### Connection refused
```bash
# Cek PostgreSQL running
systemctl status postgresql

# Cek port listening
netstat -tlnp | grep 5432

# Cek firewall
ufw status
```

### Authentication failed
```bash
# Cek pg_hba.conf
cat /etc/postgresql/*/main/pg_hba.conf | grep sparkcommerce

# Reset password
sudo -u postgres psql -c "ALTER USER sparkcommerce PASSWORD 'newpassword';"
```

### Permission denied
```bash
# Grant privileges lagi
sudo -u postgres psql -d ecommerce_manager -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO sparkcommerce;"
sudo -u postgres psql -d ecommerce_manager -c "GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO sparkcommerce;"
```
