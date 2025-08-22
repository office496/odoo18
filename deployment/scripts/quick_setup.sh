#!/bin/bash

# Odoo 18 Quick Setup Script
# This script helps you quickly set up Odoo 18 with all dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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
    if [[ $EUID -eq 0 ]]; then
        warn "This script should not be run as root for security reasons"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
        elif command -v dnf &> /dev/null; then
            OS="fedora"
        elif command -v yum &> /dev/null; then
            OS="centos"
        else
            error "Unsupported Linux distribution"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        error "Unsupported operating system: $OSTYPE"
    fi
    log "Detected OS: $OS"
}

# Install system dependencies
install_system_deps() {
    log "Installing system dependencies..."
    
    case $OS in
        "ubuntu")
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-dev python3-venv \
                postgresql postgresql-contrib postgresql-client \
                libxml2-dev libxslt1-dev libevent-dev libsasl2-dev \
                libldap2-dev libpq-dev libjpeg-dev libpng-dev \
                git curl wget nodejs npm wkhtmltopdf
            ;;
        "fedora")
            sudo dnf install -y python3 python3-pip python3-devel \
                postgresql postgresql-server postgresql-contrib \
                libxml2-devel libxslt-devel libevent-devel \
                openldap-devel postgresql-devel libjpeg-turbo-devel \
                git curl wget nodejs npm wkhtmltopdf
            ;;
        "centos")
            sudo yum install -y python3 python3-pip python3-devel \
                postgresql postgresql-server postgresql-contrib \
                libxml2-devel libxslt-devel libevent-devel \
                openldap-devel postgresql-devel libjpeg-turbo-devel \
                git curl wget nodejs npm
            ;;
        "macos")
            if ! command -v brew &> /dev/null; then
                error "Homebrew is required on macOS. Install from https://brew.sh/"
            fi
            brew install python3 postgresql libxml2 libxslt git nodejs npm
            ;;
    esac
}

# Setup PostgreSQL
setup_postgresql() {
    log "Setting up PostgreSQL..."
    
    case $OS in
        "ubuntu")
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        "fedora"|"centos")
            if [[ ! -d "/var/lib/pgsql/data" ]]; then
                sudo postgresql-setup --initdb
            fi
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            ;;
        "macos")
            brew services start postgresql
            ;;
    esac
    
    # Wait for PostgreSQL to start
    sleep 3
    
    # Create Odoo user
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
        log "Creating PostgreSQL user 'odoo'..."
        sudo -u postgres createuser -d -R -S odoo
        sudo -u postgres psql -c "ALTER USER odoo WITH PASSWORD 'odoo';"
    else
        log "PostgreSQL user 'odoo' already exists"
    fi
}

# Create Python virtual environment
setup_python_env() {
    log "Setting up Python virtual environment..."
    
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
    fi
    
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    
    log "Python environment setup complete"
}

# Create basic configuration
create_config() {
    log "Creating basic configuration..."
    
    if [[ ! -f "odoo.conf" ]]; then
        cat > odoo.conf << EOF
[options]
addons_path = addons
data_dir = ./data
logfile = ./logs/odoo.log
log_level = info

# Database settings
db_host = localhost
db_port = 5432
db_user = odoo
db_password = odoo

# Server settings
http_port = 8069
workers = 0
max_cron_threads = 2

# Security
admin_passwd = admin
list_db = True
EOF
        log "Configuration file 'odoo.conf' created"
    else
        log "Configuration file 'odoo.conf' already exists"
    fi
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p data logs custom_addons
}

# Create start script
create_start_script() {
    log "Creating start script..."
    
    cat > start_odoo.sh << 'EOF'
#!/bin/bash

# Activate virtual environment
source venv/bin/activate

# Start Odoo
./odoo-bin -c odoo.conf "$@"
EOF
    
    chmod +x start_odoo.sh
    log "Start script 'start_odoo.sh' created"
}

# Main installation process
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║        Odoo 18 Quick Setup           ║"
    echo "║                                      ║"
    echo "║  This script will install and       ║"
    echo "║  configure Odoo 18 on your system   ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Confirmation
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Check prerequisites
    check_root
    detect_os
    
    # Installation steps
    install_system_deps
    setup_postgresql
    setup_python_env
    create_directories
    create_config
    create_start_script
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         Setup Complete!              ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo "Next steps:"
    echo "1. Start Odoo: ./start_odoo.sh"
    echo "2. Open browser: http://localhost:8069"
    echo "3. Create your first database"
    echo ""
    echo "For development:"
    echo "./start_odoo.sh --dev=all --db-filter=mydb"
    echo ""
    echo "For more options, see: ./odoo-bin --help"
}

# Run main function
main "$@"