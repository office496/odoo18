#!/bin/bash

# Odoo 18 Production Deployment Script
# This script sets up Odoo 18 for production use with systemd, nginx, and SSL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo"
ODOO_LOG="/var/log/odoo"
ODOO_DATA="/var/lib/odoo"
DOMAIN=""
EMAIL=""
DB_PASSWORD=""
ADMIN_PASSWORD=""

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root for production setup"
    fi
}

# Collect configuration
collect_config() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║     Odoo 18 Production Setup         ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "Enter your domain name (e.g., odoo.example.com): " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        error "Domain name is required"
    fi
    
    read -p "Enter your email for SSL certificate: " EMAIL
    if [[ -z "$EMAIL" ]]; then
        error "Email is required for SSL certificate"
    fi
    
    while [[ -z "$DB_PASSWORD" ]]; do
        read -s -p "Enter PostgreSQL password for odoo user: " DB_PASSWORD
        echo
    done
    
    while [[ -z "$ADMIN_PASSWORD" ]]; do
        read -s -p "Enter Odoo admin password: " ADMIN_PASSWORD
        echo
    done
    
    echo "Configuration:"
    echo "  Domain: $DOMAIN"
    echo "  Email: $EMAIL"
    echo "  Odoo User: $ODOO_USER"
    echo "  Odoo Home: $ODOO_HOME"
    echo ""
    read -p "Continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    apt-get update
    apt-get install -y python3 python3-pip python3-dev python3-venv \
        postgresql postgresql-contrib postgresql-client \
        libxml2-dev libxslt1-dev libevent-dev libsasl2-dev \
        libldap2-dev libpq-dev libjpeg-dev libpng-dev \
        git curl wget nodejs npm wkhtmltopdf \
        nginx certbot python3-certbot-nginx \
        supervisor htop
}

# Create odoo user
create_odoo_user() {
    log "Creating Odoo user..."
    
    if ! id "$ODOO_USER" &>/dev/null; then
        adduser --system --home="$ODOO_HOME" --group "$ODOO_USER"
        log "User $ODOO_USER created"
    else
        log "User $ODOO_USER already exists"
    fi
}

# Setup PostgreSQL
setup_postgresql() {
    log "Setting up PostgreSQL..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # Create Odoo database user
    sudo -u postgres psql << EOF
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$ODOO_USER') THEN
        CREATE USER $ODOO_USER WITH CREATEDB PASSWORD '$DB_PASSWORD';
    ELSE
        ALTER USER $ODOO_USER WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;
EOF
    
    log "PostgreSQL setup complete"
}

# Setup Odoo files
setup_odoo_files() {
    log "Setting up Odoo files..."
    
    # Create directories
    mkdir -p "$ODOO_HOME" "$ODOO_CONFIG" "$ODOO_LOG" "$ODOO_DATA" "$ODOO_HOME/custom_addons"
    
    # Copy Odoo source code
    if [[ ! -d "$ODOO_HOME/odoo" ]]; then
        cp -r . "$ODOO_HOME/odoo"
    fi
    
    # Create Python virtual environment
    sudo -u "$ODOO_USER" python3 -m venv "$ODOO_HOME/venv"
    sudo -u "$ODOO_USER" "$ODOO_HOME/venv/bin/pip" install --upgrade pip
    sudo -u "$ODOO_USER" "$ODOO_HOME/venv/bin/pip" install -r "$ODOO_HOME/odoo/requirements.txt"
    
    # Set ownership
    chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_HOME" "$ODOO_DATA" "$ODOO_LOG"
    
    log "Odoo files setup complete"
}

# Create Odoo configuration
create_odoo_config() {
    log "Creating Odoo configuration..."
    
    cat > "$ODOO_CONFIG/odoo.conf" << EOF
[options]
# Addon paths
addons_path = $ODOO_HOME/odoo/addons,$ODOO_HOME/custom_addons

# Data directory
data_dir = $ODOO_DATA

# Logging
logfile = $ODOO_LOG/odoo.log
log_level = warn
syslog = True

# Database settings
db_host = localhost
db_port = 5432
db_user = $ODOO_USER
db_password = $DB_PASSWORD
db_maxconn = 64

# Server settings
http_port = 8069
longpolling_port = 8072
workers = 4
max_cron_threads = 2

# Security
admin_passwd = $ADMIN_PASSWORD
list_db = False
proxy_mode = True

# Performance
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Multiprocessing
db_template = template0

# Internationalization
without_demo = all
EOF
    
    chown "$ODOO_USER:$ODOO_USER" "$ODOO_CONFIG/odoo.conf"
    chmod 640 "$ODOO_CONFIG/odoo.conf"
    
    log "Odoo configuration created"
}

# Create systemd service
create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/odoo.service" << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG/odoo.conf
StandardOutput=journal+console
KillMode=mixed
KillSignal=SIGINT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable odoo
    
    log "Systemd service created"
}

# Setup Nginx
setup_nginx() {
    log "Setting up Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Odoo site configuration
    cat > "/etc/nginx/sites-available/odoo" << EOF
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL configuration will be added by certbot
    
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # Proxy settings
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;
    proxy_read_timeout 900s;
    proxy_connect_timeout 900s;
    proxy_send_timeout 900s;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # Handle longpolling requests
    location /longpolling {
        proxy_pass http://odoochat;
    }

    # Handle main requests
    location / {
        proxy_pass http://odoo;
        proxy_redirect off;
    }

    # Optimize static files
    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
    
    # Test configuration
    nginx -t
    
    systemctl restart nginx
    systemctl enable nginx
    
    log "Nginx setup complete"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log "Setting up SSL certificate..."
    
    # Get SSL certificate
    certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --redirect
    
    # Setup auto-renewal
    crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | crontab -
    
    log "SSL certificate setup complete"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > "$ODOO_HOME/backup.sh" << 'EOF'
#!/bin/bash

# Odoo Backup Script
BACKUP_DIR="/var/backups/odoo"
DATE=$(date +%Y%m%d_%H%M%S)
ODOO_USER="odoo"
ODOO_DATA="/var/lib/odoo"

mkdir -p "$BACKUP_DIR"

# Backup database
sudo -u postgres pg_dumpall > "$BACKUP_DIR/database_$DATE.sql"

# Backup filestore
tar -czf "$BACKUP_DIR/filestore_$DATE.tar.gz" -C "$ODOO_DATA" filestore

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
EOF
    
    chmod +x "$ODOO_HOME/backup.sh"
    chown "$ODOO_USER:$ODOO_USER" "$ODOO_HOME/backup.sh"
    
    # Add to crontab
    sudo -u "$ODOO_USER" crontab -l 2>/dev/null | { cat; echo "0 2 * * * $ODOO_HOME/backup.sh"; } | sudo -u "$ODOO_USER" crontab -
    
    log "Backup script created"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up basic monitoring..."
    
    # Create log rotation
    cat > "/etc/logrotate.d/odoo" << EOF
$ODOO_LOG/*.log {
    daily
    missingok
    rotate 52
    compress
    notifempty
    create 0640 $ODOO_USER $ODOO_USER
    postrotate
        systemctl reload odoo
    endscript
}
EOF
    
    # Create status check script
    cat > "$ODOO_HOME/status_check.sh" << 'EOF'
#!/bin/bash

# Check if Odoo is running
if ! systemctl is-active --quiet odoo; then
    echo "Odoo is not running!"
    systemctl start odoo
fi

# Check if Nginx is running
if ! systemctl is-active --quiet nginx; then
    echo "Nginx is not running!"
    systemctl start nginx
fi

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "Disk usage is above 80%: $DISK_USAGE%"
fi
EOF
    
    chmod +x "$ODOO_HOME/status_check.sh"
    
    # Add to crontab for monitoring
    crontab -l 2>/dev/null | { cat; echo "*/5 * * * * $ODOO_HOME/status_check.sh"; } | crontab -
    
    log "Monitoring setup complete"
}

# Final setup
final_setup() {
    log "Performing final setup..."
    
    # Start services
    systemctl start odoo
    
    # Wait for Odoo to start
    sleep 10
    
    # Check if services are running
    if systemctl is-active --quiet odoo; then
        log "Odoo service is running"
    else
        error "Odoo service failed to start"
    fi
    
    if systemctl is-active --quiet nginx; then
        log "Nginx service is running"
    else
        error "Nginx service failed to start"
    fi
    
    log "Production deployment complete!"
}

# Print summary
print_summary() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║     Deployment Complete!             ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "Your Odoo instance is now running at:"
    echo "  URL: https://$DOMAIN"
    echo "  Admin User: admin"
    echo "  Admin Password: [the one you set]"
    echo ""
    echo "Important files and directories:"
    echo "  Odoo Home: $ODOO_HOME"
    echo "  Configuration: $ODOO_CONFIG/odoo.conf"
    echo "  Logs: $ODOO_LOG/odoo.log"
    echo "  Data: $ODOO_DATA"
    echo "  Custom Addons: $ODOO_HOME/custom_addons"
    echo ""
    echo "Useful commands:"
    echo "  Check status: systemctl status odoo"
    echo "  View logs: journalctl -u odoo -f"
    echo "  Restart: systemctl restart odoo"
    echo "  Backup: $ODOO_HOME/backup.sh"
    echo ""
    echo "Next steps:"
    echo "  1. Access your Odoo instance at https://$DOMAIN"
    echo "  2. Create your first database"
    echo "  3. Install required modules"
    echo "  4. Configure your business settings"
}

# Main execution
main() {
    check_root
    collect_config
    install_dependencies
    create_odoo_user
    setup_postgresql
    setup_odoo_files
    create_odoo_config
    create_systemd_service
    setup_nginx
    setup_ssl
    create_backup_script
    setup_monitoring
    final_setup
    print_summary
}

# Run main function
main "$@"