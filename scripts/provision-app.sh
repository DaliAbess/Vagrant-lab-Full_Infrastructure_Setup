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