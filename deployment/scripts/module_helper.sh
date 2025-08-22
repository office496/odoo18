#!/bin/bash

# Odoo 18 Module Development Helper Script
# Provides utilities for creating, testing, and deploying custom modules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ODOO_BIN="./odoo-bin"
ADDONS_PATH="custom_addons"
DB_NAME="dev_db"
CONFIG_FILE="deployment/configs/development.conf"

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

# Help function
show_help() {
    cat << EOF
Odoo 18 Module Development Helper

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    create <module_name>        Create a new module using scaffold
    install <module_name>       Install a module in development database
    update <module_name>        Update a module in development database
    test <module_name>          Run tests for a specific module
    deploy <module_path> <url>  Deploy module to remote server
    start                       Start development server
    shell                       Start Odoo shell
    backup <db_name>            Backup database
    restore <backup_file>       Restore database from backup

Options:
    -d, --database <name>       Database name (default: $DB_NAME)
    -c, --config <file>         Configuration file (default: $CONFIG_FILE)
    -a, --addons-path <path>    Custom addons path (default: $ADDONS_PATH)
    -h, --help                  Show this help message

Examples:
    $0 create my_custom_module
    $0 install my_custom_module -d my_db
    $0 test my_custom_module
    $0 deploy custom_addons/my_module https://my-odoo.com
    $0 start --dev=all

EOF
}

# Create new module
create_module() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        error "Module name is required"
    fi
    
    if [[ ! -d "$ADDONS_PATH" ]]; then
        mkdir -p "$ADDONS_PATH"
        log "Created addons directory: $ADDONS_PATH"
    fi
    
    log "Creating module: $module_name"
    $ODOO_BIN scaffold "$module_name" "$ADDONS_PATH/"
    
    # Create additional structure
    local module_path="$ADDONS_PATH/$module_name"
    mkdir -p "$module_path/tests"
    mkdir -p "$module_path/wizard"
    mkdir -p "$module_path/report"
    mkdir -p "$module_path/static/src/js"
    mkdir -p "$module_path/static/src/css"
    mkdir -p "$module_path/static/src/xml"
    
    # Create test file
    cat > "$module_path/tests/__init__.py" << EOF
# -*- coding: utf-8 -*-
from . import test_${module_name}
EOF
    
    cat > "$module_path/tests/test_${module_name}.py" << EOF
# -*- coding: utf-8 -*-
from odoo.tests.common import TransactionCase

class Test${module_name^}(TransactionCase):
    
    def setUp(self):
        super(Test${module_name^}, self).setUp()
        # Setup test data here
    
    def test_basic_functionality(self):
        """Test basic functionality of the module"""
        # Add your tests here
        self.assertTrue(True, "Basic test should pass")
EOF
    
    log "Module $module_name created successfully in $module_path"
    log "Next steps:"
    echo "  1. Edit the module files in $module_path"
    echo "  2. Install the module: $0 install $module_name"
    echo "  3. Test the module: $0 test $module_name"
}

# Install module
install_module() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        error "Module name is required"
    fi
    
    log "Installing module: $module_name in database: $DB_NAME"
    $ODOO_BIN -c "$CONFIG_FILE" -d "$DB_NAME" -i "$module_name" --stop-after-init
    log "Module $module_name installed successfully"
}

# Update module
update_module() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        error "Module name is required"
    fi
    
    log "Updating module: $module_name in database: $DB_NAME"
    $ODOO_BIN -c "$CONFIG_FILE" -d "$DB_NAME" -u "$module_name" --stop-after-init
    log "Module $module_name updated successfully"
}

# Test module
test_module() {
    local module_name="$1"
    
    if [[ -z "$module_name" ]]; then
        error "Module name is required"
    fi
    
    log "Running tests for module: $module_name"
    $ODOO_BIN -c "$CONFIG_FILE" -d "${DB_NAME}_test" --test-enable -i "$module_name" --stop-after-init
    log "Tests completed for module: $module_name"
}

# Deploy module
deploy_module() {
    local module_path="$1"
    local url="$2"
    
    if [[ -z "$module_path" ]] || [[ -z "$url" ]]; then
        error "Module path and URL are required"
    fi
    
    if [[ ! -d "$module_path" ]]; then
        error "Module path does not exist: $module_path"
    fi
    
    log "Deploying module from $module_path to $url"
    $ODOO_BIN deploy "$module_path" "$url"
    log "Module deployed successfully"
}

# Start development server
start_server() {
    log "Starting Odoo development server..."
    log "Configuration: $CONFIG_FILE"
    log "Database: $DB_NAME"
    log "Addons path: $ADDONS_PATH"
    echo ""
    echo "Access Odoo at: http://localhost:8069"
    echo "Press Ctrl+C to stop the server"
    echo ""
    
    $ODOO_BIN -c "$CONFIG_FILE" --addons-path="addons,$ADDONS_PATH" --db-filter="$DB_NAME" "$@"
}

# Start Odoo shell
start_shell() {
    log "Starting Odoo shell..."
    $ODOO_BIN shell -c "$CONFIG_FILE" -d "$DB_NAME"
}

# Backup database
backup_database() {
    local db_name="${1:-$DB_NAME}"
    local backup_file="backup_${db_name}_$(date +%Y%m%d_%H%M%S).sql"
    
    log "Backing up database: $db_name"
    pg_dump -U odoo -h localhost "$db_name" > "$backup_file"
    log "Database backup saved to: $backup_file"
}

# Restore database
restore_database() {
    local backup_file="$1"
    local db_name="${2:-${DB_NAME}_restored}"
    
    if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
        error "Backup file is required and must exist"
    fi
    
    log "Restoring database from: $backup_file"
    log "Target database: $db_name"
    
    # Drop database if exists
    dropdb -U odoo -h localhost --if-exists "$db_name"
    
    # Create new database
    createdb -U odoo -h localhost "$db_name"
    
    # Restore data
    psql -U odoo -h localhost -d "$db_name" -f "$backup_file"
    
    log "Database restored successfully to: $db_name"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--database)
            DB_NAME="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -a|--addons-path)
            ADDONS_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        create)
            create_module "$2"
            exit 0
            ;;
        install)
            install_module "$2"
            exit 0
            ;;
        update)
            update_module "$2"
            exit 0
            ;;
        test)
            test_module "$2"
            exit 0
            ;;
        deploy)
            deploy_module "$2" "$3"
            exit 0
            ;;
        start)
            shift
            start_server "$@"
            exit 0
            ;;
        shell)
            start_shell
            exit 0
            ;;
        backup)
            backup_database "$2"
            exit 0
            ;;
        restore)
            restore_database "$2" "$3"
            exit 0
            ;;
        *)
            error "Unknown command: $1. Use -h for help."
            ;;
    esac
done

# If no command provided, show help
show_help