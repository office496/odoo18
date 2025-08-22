#!/bin/bash

# Test Deployment Script for Odoo 18
# This script tests the deployment tools and processes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() {
    echo -e "${GREEN}[TEST] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

success() {
    echo -e "${GREEN}[PASS] $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

# Test function
test_case() {
    local test_name="$1"
    local test_command="$2"
    
    log "Testing: $test_name"
    if eval "$test_command" >/dev/null 2>&1; then
        success "$test_name"
    else
        error "$test_name"
    fi
}

# Main test suite
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║      Odoo 18 Deployment Tests       ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Test script permissions
    test_case "Quick setup script exists and is executable" "test -x deployment/scripts/quick_setup.sh"
    test_case "Module helper script exists and is executable" "test -x deployment/scripts/module_helper.sh"
    test_case "Production setup script exists and is executable" "test -x deployment/scripts/production_setup.sh"
    
    # Test configuration files
    test_case "Development configuration exists" "test -f deployment/configs/development.conf"
    test_case "Production configuration exists" "test -f deployment/configs/production.conf"
    test_case "Testing configuration exists" "test -f deployment/configs/testing.conf"
    test_case "Docker configuration exists" "test -f deployment/configs/docker.conf"
    
    # Test Docker files
    test_case "Docker compose file exists" "test -f deployment/docker/docker-compose.yml"
    test_case "Dockerfile exists" "test -f deployment/docker/Dockerfile"
    test_case "Docker entrypoint exists" "test -f deployment/docker/entrypoint.sh"
    
    # Test documentation
    test_case "Main deployment guide exists" "test -f DEPLOYMENT.md"
    test_case "Customization guide exists" "test -f CUSTOMIZATION.md"
    test_case "Deployment README exists" "test -f deployment/README.md"
    
    # Test example module structure
    test_case "Example module manifest exists" "test -f custom_addons/example_todo_app/__manifest__.py"
    test_case "Example module models exist" "test -f custom_addons/example_todo_app/models/todo_task.py"
    test_case "Example module views exist" "test -f custom_addons/example_todo_app/views/todo_task_views.xml"
    test_case "Example module security exists" "test -f custom_addons/example_todo_app/security/ir.model.access.csv"
    test_case "Example module tests exist" "test -f custom_addons/example_todo_app/tests/test_todo_task.py"
    
    # Test Odoo core files
    test_case "Odoo bin exists" "test -f odoo-bin"
    test_case "Requirements file exists" "test -f requirements.txt"
    test_case "Core Odoo module exists" "test -d odoo"
    test_case "Base addons exist" "test -d addons"
    
    # Test Python syntax (if Python is available)
    if command -v python3 &> /dev/null; then
        test_case "Example module Python syntax is valid" "python3 -m py_compile custom_addons/example_todo_app/models/todo_task.py"
        test_case "Module helper script Python syntax is valid" "python3 -c 'import subprocess; subprocess.run([\"bash\", \"-n\", \"deployment/scripts/module_helper.sh\"])'"
    else
        warn "Python3 not available, skipping syntax tests"
    fi
    
    # Test file permissions and structure
    test_case "Custom addons directory is writable" "test -w custom_addons/"
    test_case "Deployment directory structure is correct" "test -d deployment/scripts && test -d deployment/configs && test -d deployment/docker"
    
    # Summary
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Test Results               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed! Deployment is ready.${NC}"
        echo ""
        echo "Next steps:"
        echo "1. For development: ./deployment/scripts/quick_setup.sh"
        echo "2. For production: sudo ./deployment/scripts/production_setup.sh"
        echo "3. For Docker: cd deployment/docker && docker-compose up -d"
        echo "4. For custom modules: ./deployment/scripts/module_helper.sh create my_module"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed. Please check the errors above.${NC}"
        exit 1
    fi
}

# Run tests
main "$@"