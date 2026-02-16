# Vagrant VirtualBox Lab: Full Infrastructure Setup

A hands-on guided lab to create a complete infrastructure with database server, web server, and application running on Nginx using Vagrant and VirtualBox.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Lab Setup](#lab-setup)
- [Step-by-Step Guide](#step-by-step-guide)
- [Testing the Infrastructure](#testing-the-infrastructure)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before starting this lab, ensure you have the following installed:

- **VirtualBox** (6.1 or later): [Download here](https://www.virtualbox.org/wiki/Downloads)
- **Vagrant** (2.2 or later): [Download here](https://www.vagrantup.com/downloads)
- **Minimum System Requirements**: 8GB RAM, 20GB free disk space
- **Basic knowledge**: Command line, SSH, basic networking

Verify installations:
```bash
vagrant --version
vboxmanage --version
```

## Architecture Overview

This lab creates a three-tier infrastructure:

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Web Server (web01)                             │
│  - Nginx                                        │
│  - Node.js Application                          │
│  - IP: 192.168.56.10                           │
│                                                 │
└────────────────┬────────────────────────────────┘
                 │
                 │ HTTP/App Communication
                 │
┌────────────────▼────────────────────────────────┐
│                                                 │
│  Application Server (app01)                     │
│  - Python Flask/Node.js App                     │
│  - IP: 192.168.56.11                           │
│                                                 │
└────────────────┬────────────────────────────────┘
                 │
                 │ Database Queries
                 │
┌────────────────▼────────────────────────────────┐
│                                                 │
│  Database Server (db01)                         │
│  - PostgreSQL/MySQL                             │
│  - IP: 192.168.56.12                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Lab Setup

### Step 1: Create Project Directory

```bash
mkdir vagrant-infrastructure-lab
cd vagrant-infrastructure-lab
```

### Step 2: Create the Vagrantfile

Create a file named `Vagrantfile` with the following content:

```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Define common settings
  config.vm.box = "ubuntu/jammy64"  # Ubuntu 22.04 LTS
  config.vm.box_check_update = false

  # Database Server
  config.vm.define "db01" do |db|
    db.vm.hostname = "db01"
    db.vm.network "private_network", ip: "192.168.56.12"
    
    db.vm.provider "virtualbox" do |vb|
      vb.name = "db01"
      vb.memory = "1024"
      vb.cpus = 1
    end

    db.vm.provision "shell", path: "scripts/provision-db.sh"
  end

  # Application Server
  config.vm.define "app01" do |app|
    app.vm.hostname = "app01"
    app.vm.network "private_network", ip: "192.168.56.11"
    
    app.vm.provider "virtualbox" do |vb|
      vb.name = "app01"
      vb.memory = "1024"
      vb.cpus = 1
    end

    app.vm.provision "shell", path: "scripts/provision-app.sh"
  end

  # Web Server
  config.vm.define "web01" do |web|
    web.vm.hostname = "web01"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.network "forwarded_port", guest: 80, host: 8080
    
    web.vm.provider "virtualbox" do |vb|
      vb.name = "web01"
      vb.memory = "512"
      vb.cpus = 1
    end

    web.vm.provision "shell", path: "scripts/provision-web.sh"
  end
end
```

### Step 3: Create Provisioning Scripts Directory

```bash
mkdir scripts
```

## Step-by-Step Guide

### Phase 1: Database Server Setup

Create `scripts/provision-db.sh`:

```bash
#!/bin/bash

echo "==================================="
echo "Provisioning Database Server (db01)"
echo "==================================="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Detect PostgreSQL version automatically
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
```

Make it executable:
```bash
chmod +x scripts/provision-db.sh
```

### Phase 2: Application Server Setup

Create `scripts/provision-app.sh`:

```bash
#!/bin/bash

echo "======================================"
echo "Provisioning Application Server (app01)"
echo "======================================"

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Python and dependencies
sudo apt-get install -y python3 python3-pip python3-venv postgresql-client

# Create application directory
mkdir -p /opt/app
cd /opt/app

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Flask and psycopg2
pip install flask psycopg2-binary gunicorn

# Create Flask application
cat > /opt/app/app.py <<'EOF'
from flask import Flask, jsonify
import psycopg2
import os

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host='192.168.56.12',
        database='appdb',
        user='appuser',
        password='apppass123'
    )
    return conn

@app.route('/')
def home():
    return jsonify({
        'message': 'Welcome to the Infrastructure Lab API',
        'endpoints': {
            '/users': 'Get all users',
            '/health': 'Health check'
        }
    })

@app.route('/users')
def get_users():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute('SELECT id, username, email, created_at FROM users;')
        users = cur.fetchall()
        cur.close()
        conn.close()
        
        user_list = []
        for user in users:
            user_list.append({
                'id': user[0],
                'username': user[1],
                'email': user[2],
                'created_at': str(user[3])
            })
        
        return jsonify({'users': user_list})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({'status': 'healthy', 'database': 'connected'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

# Create systemd service
sudo tee /etc/systemd/system/flaskapp.service > /dev/null <<EOF
[Unit]
Description=Flask Application
After=network.target

[Service]
User=vagrant
WorkingDirectory=/opt/app
Environment="PATH=/opt/app/venv/bin"
ExecStart=/opt/app/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 2 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Change ownership
sudo chown -R vagrant:vagrant /opt/app

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable flaskapp
sudo systemctl start flaskapp

echo "Application server setup complete!"
```

Make it executable:
```bash
chmod +x scripts/provision-app.sh
```

### Phase 3: Web Server Setup

Create `scripts/provision-web.sh`:

```bash
#!/bin/bash

echo "================================="
echo "Provisioning Web Server (web01)"
echo "================================="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Nginx
sudo apt-get install -y nginx

# Remove default configuration
sudo rm /etc/nginx/sites-enabled/default

# Create Nginx configuration
sudo tee /etc/nginx/sites-available/app > /dev/null <<'EOF'
upstream app_backend {
    server 192.168.56.11:5000;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://app_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://app_backend/health;
    }

    location /nginx-health {
        access_log off;
        return 200 "Nginx is healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Enable configuration
sudo ln -s /etc/nginx/sites-available/app /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "Web server setup complete!"
```

Make it executable:
```bash
chmod +x scripts/provision-web.sh
```

## Bringing Up the Infrastructure

### Step 1: Start All VMs

```bash
# Start all VMs (this will take several minutes)
vagrant up

# Or start them individually in order:
vagrant up db01
vagrant up app01
vagrant up web01
```

### Step 2: Verify VM Status

```bash
vagrant status
```

Expected output:
```
Current machine states:

db01                      running (virtualbox)
app01                     running (virtualbox)
web01                     running (virtualbox)
```

## Testing the Infrastructure

### Test 1: Check Web Server

Open your browser and navigate to:
```
http://localhost:8080
```

Or use curl:
```bash
curl http://localhost:8080
```

Expected response:
```json
{
  "message": "Welcome to the Infrastructure Lab API",
  "endpoints": {
    "/users": "Get all users",
    "/health": "Health check"
  }
}
```

### Test 2: Check Users Endpoint

```bash
curl http://localhost:8080/users
```

Expected response:
```json
{
  "users": [
    {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "created_at": "2024-..."
    },
    {
      "id": 2,
      "username": "jane_smith",
      "email": "jane@example.com",
      "created_at": "2024-..."
    }
  ]
}
```

### Test 3: Health Check

```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "database": "connected"
}
```

### Test 4: SSH into VMs

```bash
# SSH into database server
vagrant ssh db01

# Check PostgreSQL status
sudo systemctl status postgresql

# Exit
exit
```

```bash
# SSH into application server
vagrant ssh app01

# Check Flask app status
sudo systemctl status flaskapp

# View logs
sudo journalctl -u flaskapp -f

# Exit
exit
```

```bash
# SSH into web server
vagrant ssh web01

# Check Nginx status
sudo systemctl status nginx

# View access logs
sudo tail -f /var/log/nginx/access.log

# Exit
exit
```

### Test 5: Network Connectivity

```bash
# SSH into web server
vagrant ssh web01

# Test connection to app server
curl http://192.168.56.11:5000/health

# Test database connectivity from app server
vagrant ssh app01
psql -h 192.168.56.12 -U appuser -d appdb -c "SELECT * FROM users;"
# Password: apppass123
```

## Advanced Tasks

### Task 1: Add a New User via Database

```bash
vagrant ssh db01
sudo -u postgres psql appdb
```

```sql
INSERT INTO users (username, email) VALUES ('alice_wonder', 'alice@example.com');
SELECT * FROM users;
\q
```

Then verify via API:
```bash
curl http://localhost:8080/users
```

### Task 2: Monitor Resources

```bash
# Check VM resource usage
vagrant ssh web01
htop  # Install with: sudo apt-get install htop

# Check disk usage
df -h

# Check memory
free -h
```


## Troubleshooting

### Common Issue: Provisioning Scripts Not Running

If you see services not installed or configured after `vagrant up`, the provisioning scripts may not have run:

```bash
# Check if scripts exist and are executable
ls -la scripts/

# Make scripts executable
chmod +x scripts/provision-db.sh
chmod +x scripts/provision-app.sh
chmod +x scripts/provision-web.sh

# Manually provision a specific VM
vagrant provision db01
vagrant provision app01
vagrant provision web01

# Or provision all VMs
vagrant provision

# Check provisioning output for errors
vagrant up db01 2>&1 | tee db01-provision.log
grep -i error db01-provision.log
```

### Issue: VMs won't start
```bash
# Check VirtualBox
VBoxManage list vms

# Destroy and recreate
vagrant destroy -f
vagrant up
```

### Issue: Can't connect to application
```bash
# Check if app is running
vagrant ssh app01
sudo systemctl status flaskapp
sudo journalctl -u flaskapp -n 50

# Restart the service
sudo systemctl restart flaskapp
```

### Issue: Database connection fails
```bash
# Verify PostgreSQL is running
vagrant ssh db01
sudo systemctl status postgresql

# Check the actual PostgreSQL cluster
sudo systemctl status postgresql@*

# Detect PostgreSQL version
ls /etc/postgresql/

# Check PostgreSQL logs (replace 14 with your version)
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Verify PostgreSQL is listening on network (not just localhost)
sudo ss -tlnp | grep 5432
# Should show: 0.0.0.0:5432 (not 127.0.0.1:5432)

# Test connection
psql -h 192.168.56.12 -U appuser -d appdb
# Password: apppass123

# If PostgreSQL isn't listening on the network:
PG_VERSION=$(ls /etc/postgresql/ | head -n1)
sudo sed -i "s/listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
sudo systemctl restart postgresql@$PG_VERSION-main
```

### Issue: Nginx errors
```bash
# Check Nginx status
vagrant ssh web01
sudo nginx -t
sudo systemctl status nginx

# View error logs
sudo tail -f /var/log/nginx/error.log
```

## Cleanup

### Suspend VMs (save state)
```bash
vagrant suspend
```

### Halt VMs (shutdown)
```bash
vagrant halt
```

### Destroy VMs (delete completely)
```bash
vagrant destroy -f
```

### Resume VMs
```bash
vagrant up
# or
vagrant resume
```

## Project Structure

```
vagrant-infrastructure-lab/
├── Vagrantfile
├── README.md
└── scripts/
    ├── provision-db.sh
    ├── provision-app.sh
    └── provision-web.sh
```




## References

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [VirtualBox Documentation](https://www.virtualbox.org/wiki/Documentation)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Flask Documentation](https://flask.palletsprojects.com/)

## License

This lab is provided for educational purposes.

---

