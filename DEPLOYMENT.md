# Odoo 18 Deployment and Customization Guide

This guide provides comprehensive instructions for deploying and customizing Odoo 18.

## Table of Contents

1. [Quick Start](#quick-start)
2. [System Requirements](#system-requirements)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Running Odoo](#running-odoo)
6. [Production Deployment](#production-deployment)
7. [Customization](#customization)
8. [Module Development](#module-development)
9. [Troubleshooting](#troubleshooting)

## Quick Start

The fastest way to get Odoo 18 running:

```bash
# 1. Install dependencies
pip3 install -r requirements.txt

# 2. Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib

# 3. Create database user
sudo -u postgres createuser -s $USER

# 4. Run Odoo
./odoo-bin --addons-path=addons --db-filter=odoo18_demo
```

## System Requirements

### Minimum Requirements
- **Python**: 3.10 or higher
- **PostgreSQL**: 13 or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 10GB minimum

### Supported Operating Systems
- Ubuntu 20.04 LTS or higher
- Debian 11 or higher
- CentOS 8 or higher
- macOS 10.15 or higher
- Windows 10 or higher

## Installation

### 1. Python Dependencies

Install Python dependencies using pip:

```bash
pip3 install -r requirements.txt
```

For development, also install optional dependencies:

```bash
pip3 install -r requirements.txt
pip3 install pytest coverage
```

### 2. Database Setup

#### PostgreSQL Installation

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib postgresql-client
```

**CentOS/RHEL:**
```bash
sudo dnf install postgresql postgresql-server postgresql-contrib
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**macOS:**
```bash
brew install postgresql
brew services start postgresql
```

#### Database User Setup

Create a PostgreSQL user for Odoo:

```bash
sudo -u postgres createuser -s $USER
sudo -u postgres createdb $USER
```

For production, create a dedicated user:

```bash
sudo -u postgres createuser -d -R -S odoo
sudo -u postgres psql -c "ALTER USER odoo WITH PASSWORD 'secure_password';"
```

### 3. Additional Dependencies

Install system dependencies for full functionality:

**Ubuntu/Debian:**
```bash
sudo apt-get install -y python3-dev libxml2-dev libxslt1-dev libevent-dev libsasl2-dev libldap2-dev libpq-dev libjpeg-dev wkhtmltopdf
```

**CentOS/RHEL:**
```bash
sudo dnf install -y python3-devel libxml2-devel libxslt-devel libevent-devel openldap-devel postgresql-devel libjpeg-turbo-devel wkhtmltopdf
```

## Configuration

### Basic Configuration File

Create a configuration file `odoo.conf`:

```ini
[options]
addons_path = addons
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log
log_level = info

# Database settings
db_host = localhost
db_port = 5432
db_user = odoo
db_password = secure_password

# Server settings
http_port = 8069
workers = 4
max_cron_threads = 2

# Security
admin_passwd = your_admin_password
list_db = False
```

### Configuration Options

Key configuration options:

| Option | Description | Default |
|--------|-------------|---------|
| `addons_path` | Comma-separated list of addon directories | `addons` |
| `data_dir` | Directory to store sessions and attachments | `~/.local/share/Odoo` |
| `db_host` | Database server hostname | `localhost` |
| `db_port` | Database server port | `5432` |
| `db_user` | Database username | Current user |
| `db_password` | Database password | None |
| `http_port` | HTTP port | `8069` |
| `workers` | Number of worker processes | `0` (threading) |
| `log_level` | Logging level | `info` |

## Running Odoo

### Development Mode

For development with auto-reload:

```bash
./odoo-bin --addons-path=addons --dev=all --db-filter=mydb
```

### Production Mode

For production with multiple workers:

```bash
./odoo-bin -c odoo.conf --workers=4
```

### Command Line Options

Common command line options:

```bash
# Basic server start
./odoo-bin

# Specify configuration file
./odoo-bin -c /path/to/odoo.conf

# Specify database
./odoo-bin -d database_name

# Install modules
./odoo-bin -d database_name -i module1,module2

# Update modules
./odoo-bin -d database_name -u module1,module2

# Development mode with debugging
./odoo-bin --dev=all --log-level=debug

# Run tests
./odoo-bin --test-enable -d test_database --stop-after-init
```

## Production Deployment

### Using systemd

Create a systemd service file `/etc/systemd/system/odoo.service`:

```ini
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console
KillMode=mixed
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable odoo
sudo systemctl start odoo
```

### Nginx Reverse Proxy

Configure Nginx as a reverse proxy `/etc/nginx/sites-available/odoo`:

```nginx
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;

    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://odoo;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://odoochat;
    }

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo;
    }
}
```

### SSL Configuration

Use Let's Encrypt for free SSL certificates:

```bash
sudo apt-get install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Customization

### Module Structure

Odoo modules follow this structure:

```
my_custom_module/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   └── my_model.py
├── views/
│   └── my_views.xml
├── static/
│   ├── description/
│   │   └── icon.png
│   └── src/
│       ├── css/
│       ├── js/
│       └── xml/
├── security/
│   └── ir.model.access.csv
└── data/
    └── my_data.xml
```

### Basic Module Example

Create a new module using the scaffold command:

```bash
./odoo-bin scaffold my_module addons/
```

### Custom Configuration

Create custom configuration for different environments:

**Development (`odoo-dev.conf`):**
```ini
[options]
addons_path = addons,custom_addons
dev_mode = True
log_level = debug
workers = 0
```

**Testing (`odoo-test.conf`):**
```ini
[options]
addons_path = addons,custom_addons
test_enable = True
workers = 0
stop_after_init = True
```

**Production (`odoo-prod.conf`):**
```ini
[options]
addons_path = addons,custom_addons
workers = 4
max_cron_threads = 2
log_level = warn
list_db = False
```

## Module Development

### Using the Scaffold Command

Generate a new module:

```bash
# Basic module
./odoo-bin scaffold my_module addons/

# Module with specific template
./odoo-bin scaffold -t theme my_theme addons/
```

### Module Deployment

Deploy modules to a running instance:

```bash
# Deploy to local instance
./odoo-bin deploy /path/to/module

# Deploy to remote instance
./odoo-bin deploy /path/to/module https://your-odoo-instance.com --login admin --password admin
```

### Development Workflow

1. **Create module structure:**
   ```bash
   ./odoo-bin scaffold my_module addons/
   ```

2. **Start development server:**
   ```bash
   ./odoo-bin --addons-path=addons --dev=all -d mydb
   ```

3. **Install module:**
   ```bash
   ./odoo-bin -d mydb -i my_module
   ```

4. **Update module after changes:**
   ```bash
   ./odoo-bin -d mydb -u my_module
   ```

### Testing

Run tests for specific modules:

```bash
# Test specific module
./odoo-bin --test-enable -d test_db -i my_module --stop-after-init

# Test with coverage
coverage run --source=addons/my_module ./odoo-bin --test-enable -d test_db -i my_module --stop-after-init
coverage report
```

## Troubleshooting

### Common Issues

1. **Database connection errors:**
   - Check PostgreSQL is running: `sudo systemctl status postgresql`
   - Verify connection settings in configuration file
   - Test connection: `psql -h localhost -U odoo -d postgres`

2. **Module import errors:**
   - Check Python dependencies: `pip3 install -r requirements.txt`
   - Verify addons_path includes module directory
   - Check module __manifest__.py for correct dependencies

3. **Permission errors:**
   - Ensure Odoo user has correct file permissions
   - Check data_dir permissions: `chown -R odoo:odoo /var/lib/odoo`
   - Verify log file permissions: `chown -R odoo:odoo /var/log/odoo`

4. **Performance issues:**
   - Increase worker count for high load
   - Optimize database queries
   - Use database indexing
   - Configure proper caching

### Logs and Debugging

Monitor Odoo logs:

```bash
# View real-time logs
tail -f /var/log/odoo/odoo.log

# Search for errors
grep ERROR /var/log/odoo/odoo.log

# Check database logs
sudo -u postgres tail -f /var/log/postgresql/postgresql-*.log
```

Enable debug mode:

```bash
./odoo-bin --log-level=debug --dev=all
```

### Database Maintenance

Regular maintenance tasks:

```bash
# Backup database
pg_dump -U odoo database_name > backup.sql

# Restore database
createdb -U odoo new_database
psql -U odoo new_database < backup.sql

# Update statistics
psql -U odoo -d database_name -c "ANALYZE;"
```

## Additional Resources

- [Official Documentation](https://www.odoo.com/documentation/18.0/)
- [Developer Documentation](https://www.odoo.com/documentation/18.0/developer/)
- [Community Forum](https://www.odoo.com/forum/help-1)
- [GitHub Repository](https://github.com/odoo/odoo)

For more specific deployment scenarios or customization needs, refer to the helper scripts in the `deployment/` directory.