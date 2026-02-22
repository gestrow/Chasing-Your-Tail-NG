#!/bin/bash
# Verification script for CYT installation

set -e

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/distro.sh"

print_section "Verifying CYT Installation"

# Configuration
INSTALL_DIR="${INSTALL_DIR:-.}"
ERRORS=0
WARNINGS=0

# Determine Python path
if [[ -f "$INSTALL_DIR/.venv/bin/python3" ]]; then
    PYTHON="$INSTALL_DIR/.venv/bin/python3"
    print_info "Using virtual environment Python"
else
    PYTHON="python3"
    print_info "Using system Python"
fi

# Check Python version
print_step "Checking Python version..."
if $PYTHON -c "import sys; assert sys.version_info >= (3, 6), 'Python 3.6+ required'" 2>/dev/null; then
    PYTHON_VERSION=$($PYTHON --version 2>&1)
    print_success "$PYTHON_VERSION"
else
    print_error "Python 3.6+ required"
    ((ERRORS++))
fi

# Check required Python packages
print_step "Checking Python packages..."

check_python_import() {
    local module="$1"
    local name="${2:-$module}"
    if $PYTHON -c "import $module" 2>/dev/null; then
        local version=$($PYTHON -c "import $module; print(getattr($module, '__version__', 'installed'))" 2>/dev/null)
        print_success "$name: $version"
        return 0
    else
        print_error "$name: NOT FOUND"
        ((ERRORS++))
        return 1
    fi
}

check_python_import "requests"
check_python_import "cryptography"

# Check tkinter (optional for GUI)
if $PYTHON -c "import tkinter" 2>/dev/null; then
    print_success "tkinter: available"
else
    print_warning "tkinter: not available (GUI disabled)"
    ((WARNINGS++))
fi

# Check CYT modules
print_step "Checking CYT modules..."
cd "$INSTALL_DIR"

check_cyt_module() {
    local module="$1"
    if $PYTHON -c "import $module" 2>/dev/null; then
        print_success "$module"
        return 0
    else
        print_error "$module: IMPORT FAILED"
        ((ERRORS++))
        return 1
    fi
}

check_cyt_module "secure_credentials"
check_cyt_module "secure_database"
check_cyt_module "secure_ignore_loader"
check_cyt_module "surveillance_detector"
check_cyt_module "gps_tracker"

# Check system tools
print_step "Checking system tools..."

check_command() {
    local cmd="$1"
    local required="${2:-true}"
    if command_exists "$cmd"; then
        local version=$($cmd --version 2>&1 | head -1 || echo "installed")
        print_success "$cmd: $version"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            print_error "$cmd: NOT FOUND"
            ((ERRORS++))
        else
            print_warning "$cmd: not found (optional)"
            ((WARNINGS++))
        fi
        return 1
    fi
}

check_command "iwconfig" "true"
check_command "kismet" "false"
check_command "pandoc" "false"

# Check config file
print_step "Checking configuration..."
if [[ -f "$INSTALL_DIR/config.json" ]]; then
    if $PYTHON -c "import json; json.load(open('config.json'))" 2>/dev/null; then
        print_success "config.json: valid JSON"
    else
        print_error "config.json: invalid JSON"
        ((ERRORS++))
    fi
else
    print_error "config.json: NOT FOUND"
    ((ERRORS++))
fi

# Check directories
print_step "Checking directories..."
for dir in logs reports surveillance_reports kml_files ignore_lists; do
    if [[ -d "$INSTALL_DIR/$dir" ]]; then
        print_success "$dir/"
    else
        print_warning "$dir/: missing (will be created on first run)"
        ((WARNINGS++))
    fi
done

# Check systemd services (if available)
if has_systemd; then
    print_step "Checking systemd services..."
    for service in cyt-kismet cyt-gui; do
        if systemctl list-unit-files | grep -q "$service.service"; then
            local status=$(systemctl is-enabled "$service.service" 2>/dev/null || echo "disabled")
            print_success "$service.service: $status"
        else
            print_info "$service.service: not installed"
        fi
    done
fi

# Summary
print_section "Verification Summary"

if [[ $ERRORS -eq 0 ]]; then
    print_success "All checks passed!"
    if [[ $WARNINGS -gt 0 ]]; then
        print_warning "$WARNINGS warning(s) - see above for details"
    fi
    echo
    print_info "CYT is ready to use!"
    print_info "  GUI:     python3 cyt_gui.py"
    print_info "  CLI:     python3 chasing_your_tail.py"
    print_info "  Analyze: python3 surveillance_analyzer.py"
    exit 0
else
    print_error "$ERRORS error(s), $WARNINGS warning(s)"
    print_error "Please fix the errors above before using CYT"
    exit 1
fi
