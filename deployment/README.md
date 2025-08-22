# Odoo 18 Deployment Resources

This directory contains scripts, configurations, and resources to help you deploy and customize Odoo 18.

## Quick Start

### Development Setup
```bash
# Quick development setup
./scripts/quick_setup.sh

# Start development server
./scripts/module_helper.sh start --dev=all
```

### Production Setup
```bash
# Run as root for production deployment
sudo ./scripts/production_setup.sh
```

## Directory Structure

```
deployment/
├── scripts/                 # Helper scripts
│   ├── quick_setup.sh      # Quick development setup
│   ├── module_helper.sh    # Module development utilities
│   └── production_setup.sh # Production deployment
├── configs/                # Configuration templates
│   ├── development.conf    # Development configuration
│   ├── production.conf     # Production configuration
│   ├── testing.conf        # Testing configuration
│   └── docker.conf         # Docker configuration
└── docker/                 # Docker deployment
    ├── docker-compose.yml  # Docker Compose setup
    ├── Dockerfile          # Odoo Docker image
    └── entrypoint.sh       # Docker entrypoint script
```

## Available Scripts

### quick_setup.sh
Automated setup script for development environment:
- Installs system dependencies
- Sets up PostgreSQL
- Creates Python virtual environment
- Installs Python dependencies
- Creates basic configuration
- Creates start script

### module_helper.sh
Utilities for module development:
```bash
# Create new module
./scripts/module_helper.sh create my_module

# Install module
./scripts/module_helper.sh install my_module -d mydb

# Update module
./scripts/module_helper.sh update my_module -d mydb

# Test module
./scripts/module_helper.sh test my_module

# Start development server
./scripts/module_helper.sh start --dev=all

# Start Odoo shell
./scripts/module_helper.sh shell -d mydb

# Backup database
./scripts/module_helper.sh backup mydb

# Deploy module to remote server
./scripts/module_helper.sh deploy custom_addons/my_module https://my-odoo.com
```

### production_setup.sh
Complete production deployment script:
- Installs and configures all system dependencies
- Sets up PostgreSQL with secure configuration
- Creates system user and directories
- Configures systemd service
- Sets up Nginx reverse proxy
- Configures SSL with Let's Encrypt
- Creates backup and monitoring scripts

## Configuration Templates

### Development (configs/development.conf)
- Debug logging enabled
- Development mode features
- Single-threaded for easier debugging
- Database listing enabled

### Production (configs/production.conf)
- Optimized for performance
- Multi-worker configuration
- Security hardened
- SSL and proxy mode enabled

### Testing (configs/testing.conf)
- Test-specific configuration
- Test database isolation
- Debug logging for troubleshooting

### Docker (configs/docker.conf)
- Container-optimized settings
- Environment variable integration
- Multi-addon path support

## Docker Deployment

### Quick Docker Setup
```bash
cd deployment/docker
docker-compose up -d
```

This will start:
- PostgreSQL database
- Odoo 18 application
- Nginx reverse proxy

### Custom Docker Build
```bash
# Build custom image
docker build -f deployment/docker/Dockerfile -t my-odoo18 .

# Run with custom addons
docker run -d \
  -v ./custom_addons:/mnt/custom-addons \
  -p 8069:8069 \
  my-odoo18
```

## Environment-Specific Deployment

### Development
```bash
# Setup development environment
./scripts/quick_setup.sh

# Start with specific configuration
./odoo-bin -c deployment/configs/development.conf
```

### Testing
```bash
# Run tests with testing configuration
./odoo-bin -c deployment/configs/testing.conf --test-enable -d test_db
```

### Production
```bash
# Complete production setup (run as root)
sudo ./scripts/production_setup.sh

# Or manual setup with production config
./odoo-bin -c deployment/configs/production.conf
```

## Customization

### Adding Custom Modules
1. Create module directory:
   ```bash
   mkdir -p custom_addons/my_module
   ```

2. Use scaffold to generate structure:
   ```bash
   ./scripts/module_helper.sh create my_module
   ```

3. Install the module:
   ```bash
   ./scripts/module_helper.sh install my_module
   ```

### Configuration Customization
1. Copy a configuration template:
   ```bash
   cp deployment/configs/development.conf my_custom.conf
   ```

2. Modify settings as needed

3. Use with Odoo:
   ```bash
   ./odoo-bin -c my_custom.conf
   ```

## Security Considerations

### Development
- Default passwords are used for convenience
- Database listing is enabled
- Debug mode is active

### Production
- Strong passwords required
- Database listing disabled
- SSL/TLS encryption enforced
- Firewall configuration recommended
- Regular security updates needed

## Backup and Maintenance

### Automated Backups
The production setup script creates automated backup scripts:
- Daily database backups
- File storage backups
- Automatic cleanup of old backups

### Manual Backup
```bash
# Backup database
./scripts/module_helper.sh backup mydb

# Backup filestore manually
tar -czf filestore_backup.tar.gz -C ~/.local/share/Odoo filestore
```

### Updates
```bash
# Update Odoo code
git pull origin 18.0

# Restart services
sudo systemctl restart odoo

# Update modules if needed
./odoo-bin -c /etc/odoo/odoo.conf -d mydb -u all
```

## Troubleshooting

### Common Issues
1. **Database connection errors**: Check PostgreSQL status and credentials
2. **Module import errors**: Verify Python dependencies and addon paths
3. **Permission errors**: Check file ownership and permissions
4. **Performance issues**: Adjust worker count and memory limits

### Logs
```bash
# View Odoo logs
tail -f /var/log/odoo/odoo.log

# View system logs
journalctl -u odoo -f

# View Nginx logs
tail -f /var/log/nginx/odoo.access.log
tail -f /var/log/nginx/odoo.error.log
```

## Support

For additional help:
- See main [DEPLOYMENT.md](../DEPLOYMENT.md) and [CUSTOMIZATION.md](../CUSTOMIZATION.md)
- Check [Odoo documentation](https://www.odoo.com/documentation/18.0/)
- Visit [Odoo Community Forum](https://www.odoo.com/forum/help-1)