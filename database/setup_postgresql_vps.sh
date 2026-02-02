#!/bin/bash
# =============================================================
# PostgreSQL Setup Script for SparkCommerce
# VPS Server: 103.38.109.27
# =============================================================

set -e

echo "=========================================="
echo "  SparkCommerce PostgreSQL Setup Script"
echo "=========================================="

# Configuration - GANTI PASSWORD INI!
DB_NAME="ecommerce_manager"
DB_USER="sparkcommerce"
DB_PASSWORD="YourSecurePassword123!"  # <-- GANTI DENGAN PASSWORD AMAN!

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[1/6] Updating system packages...${NC}"
apt update && apt upgrade -y

echo -e "${YELLOW}[2/6] Installing PostgreSQL...${NC}"
apt install postgresql postgresql-contrib -y

echo -e "${YELLOW}[3/6] Starting PostgreSQL service...${NC}"
systemctl start postgresql
systemctl enable postgresql

echo -e "${YELLOW}[4/6] Creating database and user...${NC}"
sudo -u postgres psql <<EOF
-- Create user
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Create database
CREATE DATABASE $DB_NAME OWNER $DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Connect to database and grant schema privileges
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF

echo -e "${YELLOW}[5/6] Configuring remote access...${NC}"

# Get PostgreSQL version directory
PG_VERSION=$(ls /etc/postgresql/)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Backup original configs
cp $PG_CONF ${PG_CONF}.backup
cp $PG_HBA ${PG_HBA}.backup

# Update postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF

# Add remote access rule to pg_hba.conf
echo "# SparkCommerce remote access" >> $PG_HBA
echo "host    $DB_NAME    $DB_USER    0.0.0.0/0    md5" >> $PG_HBA

echo -e "${YELLOW}[6/6] Configuring firewall and restarting PostgreSQL...${NC}"

# Open port in firewall (if UFW is active)
if command -v ufw &> /dev/null; then
    ufw allow 5432/tcp
    echo "UFW rule added for port 5432"
fi

# Restart PostgreSQL
systemctl restart postgresql

echo ""
echo -e "${GREEN}=========================================="
echo "  PostgreSQL Setup Complete!"
echo "==========================================${NC}"
echo ""
echo "Connection Details:"
echo "  Host:     103.38.109.27"
echo "  Port:     5432"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USER"
echo "  Password: $DB_PASSWORD"
echo ""
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo "1. Upload schema: scp database/ecommerce_manager_postgres.sql root@103.38.109.27:/tmp/"
echo "2. Import schema: sudo -u postgres psql -d $DB_NAME -f /tmp/ecommerce_manager_postgres.sql"
echo "3. Update backend .env with the connection details above"
echo ""
echo -e "${RED}SECURITY REMINDER:${NC}"
echo "- Change the default password!"
echo "- Consider restricting IP access in pg_hba.conf"
echo "- Enable SSL for production"
