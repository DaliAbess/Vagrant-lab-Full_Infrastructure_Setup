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