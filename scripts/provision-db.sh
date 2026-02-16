#!/bin/bash

echo "==================================="
echo "Provisioning Database Server (db01)"
echo "==================================="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Detect PostgreSQL version
PG_VERSION=$(ls /etc/postgresql/ | head -n1)
echo "Detected PostgreSQL version: $PG_VERSION"

# Configure PostgreSQL to accept remote connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf

# Configure authentication
echo "host    all    all    192.168.56.0/24    md5" | sudo tee -a /etc/postgresql/$PG_VERSION/main/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql@$PG_VERSION-main
sudo systemctl restart postgresql

# Wait for PostgreSQL to be ready
sleep 3

# Create database and user
sudo -u postgres psql <<EOF
CREATE DATABASE appdb;
CREATE USER appuser WITH ENCRYPTED PASSWORD 'apppass123';
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
\c appdb
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (username, email) VALUES ('john_doe', 'john@example.com');
INSERT INTO users (username, email) VALUES ('jane_smith', 'jane@example.com');
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO appuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO appuser;
EOF

# Verify setup
echo ""
echo "Verifying database setup..."
sudo -u postgres psql -d appdb -c "SELECT COUNT(*) FROM users;"

echo ""
echo "Database server setup complete!"
echo "PostgreSQL is listening on 0.0.0.0:5432"
echo "Database: appdb"
echo "User: appuser"
echo "Password: apppass123"