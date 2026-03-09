#!/bin/bash
# Smart Python dependency installation for CYT
# Handles Kali's externally-managed-environment gracefully

set -e

# Source library functions (use parent's CYT_LIB_DIR if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYT_LIB_DIR="${CYT_LIB_DIR:-$SCRIPT_DIR/lib}"
source "$CYT_LIB_DIR/colors.sh"
source "$CYT_LIB_DIR/utils.sh"
source "$CYT_LIB_DIR/distro.sh"

print_section "Installing Python Dependencies"

# Configuration
INSTALL_DIR="${INSTALL_DIR:-.}"
REQUIREMENTS_FILE="$INSTALL_DIR/requirements.txt"
VENV_DIR="$INSTALL_DIR/.venv"

# Required packages with minimum versions
declare -A REQUIRED_PACKAGES=(
    ["requests"]="2.28.0"
    ["cryptography"]="40.0.0"
)

# Check if we can use system packages
check_apt_packages() {
    print_step "Checking apt package versions..."

    local all_satisfied=true

    for pkg in "${!REQUIRED_PACKAGES[@]}"; do
        local min_version="${REQUIRED_PACKAGES[$pkg]}"
        local apt_pkg="python3-$pkg"
        local apt_version

        apt_version=$(get_apt_version "$apt_pkg")

        if [[ -z "$apt_version" ]]; then
            print_step "$apt_pkg: not available in apt"
            all_satisfied=false
        elif version_gte "$apt_version" "$min_version"; then
            print_step "$apt_pkg: $apt_version >= $min_version ✓"
        else
            print_step "$apt_pkg: $apt_version < $min_version (need newer)"
            all_satisfied=false
        fi
    done

    $all_satisfied
}

# Install using apt packages
install_via_apt() {
    print_step "Installing Python packages via apt..."

    local packages=()
    for pkg in "${!REQUIRED_PACKAGES[@]}"; do
        packages+=("python3-$pkg")
    done

    $SUDO apt-get install -y -qq "${packages[@]}"
    print_success "Installed via apt: ${packages[*]}"
}

# Install using virtual environment
install_via_venv() {
    print_step "Creating virtual environment at $VENV_DIR..."

    # Ensure python3-venv is installed
    if ! package_installed "python3-venv"; then
        $SUDO apt-get install -y -qq python3-venv python3-pip
    fi

    # Create venv
    python3 -m venv "$VENV_DIR"

    # Activate and install
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip -q
    pip install -r "$REQUIREMENTS_FILE" -q

    print_success "Virtual environment created at $VENV_DIR"
    print_info "To activate: source $VENV_DIR/bin/activate"

    # Create activation helper script
    cat > "$INSTALL_DIR/activate_cyt.sh" << 'ACTIVATE_EOF'
#!/bin/bash
# Activate CYT virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.venv/bin/activate"
echo "CYT virtual environment activated"
ACTIVATE_EOF
    chmod +x "$INSTALL_DIR/activate_cyt.sh"

    # Mark that venv is being used
    echo "venv" > "$INSTALL_DIR/.python_install_method"
}

# Main installation logic
install_python_deps() {
    local platform
    platform=$(detect_platform)

    print_info "Platform: $platform"
    print_info "Install directory: $INSTALL_DIR"

    # Check if requirements.txt exists
    if [[ ! -f "$REQUIREMENTS_FILE" ]]; then
        fail "requirements.txt not found at $REQUIREMENTS_FILE"
    fi

    # Try apt packages first (cleaner for Kali)
    if check_apt_packages; then
        print_info "System packages satisfy requirements"
        if prompt_yn "Use system packages (recommended for Kali)?"; then
            install_via_apt
            echo "apt" > "$INSTALL_DIR/.python_install_method"
            return 0
        fi
    else
        print_info "System packages don't satisfy version requirements"
    fi

    # Fall back to venv
    print_info "Setting up virtual environment..."
    install_via_venv
}

# Run installation
install_python_deps

# Verify installation
print_step "Verifying Python packages..."

# Determine python path
if [[ -f "$INSTALL_DIR/.venv/bin/python3" ]]; then
    PYTHON="$INSTALL_DIR/.venv/bin/python3"
else
    PYTHON="python3"
fi

$PYTHON -c "import requests; print(f'requests {requests.__version__}')" || fail "requests import failed"
$PYTHON -c "import cryptography; print(f'cryptography {cryptography.__version__}')" || fail "cryptography import failed"

# Check tkinter
$PYTHON -c "import tkinter" 2>/dev/null && print_success "tkinter available" || warn "tkinter not available - GUI disabled"

print_success "Python dependencies installed successfully"
