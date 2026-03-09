#!/bin/bash
# Install system dependencies for CYT

set -e

# Source library functions (use parent's CYT_LIB_DIR if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYT_LIB_DIR="${CYT_LIB_DIR:-$SCRIPT_DIR/lib}"
source "$CYT_LIB_DIR/colors.sh"
source "$CYT_LIB_DIR/utils.sh"
source "$CYT_LIB_DIR/distro.sh"

print_section "Installing System Dependencies"

# Detect platform
PLATFORM=$(detect_platform)
PKG_MANAGER=$(get_pkg_manager)

# Define packages
REQUIRED_PKGS=(
    "python3"
    "python3-tk"
    "wireless-tools"
)

OPTIONAL_PKGS=(
    "kismet"
    "pandoc"
    "iw"
)

# NetHunter/Kali usually has these pre-installed
if [[ "$PLATFORM" == "kali" || "$PLATFORM" == "nethunter" ]]; then
    print_info "Kali/NetHunter detected - some packages may already be installed"
fi

# Update package lists
print_step "Updating package lists..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
    $SUDO apt-get update -qq
elif [[ "$PKG_MANAGER" == "pkg" ]]; then
    pkg update -y
fi

# Install required packages
print_step "Installing required packages..."
for pkg in "${REQUIRED_PKGS[@]}"; do
    if ! package_installed "$pkg"; then
        print_step "Installing $pkg..."
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            $SUDO apt-get install -y -qq "$pkg" || warn "Failed to install $pkg"
        else
            pkg install -y "$pkg" || warn "Failed to install $pkg"
        fi
    else
        print_step "$pkg already installed"
    fi
done

# Install optional packages
print_step "Installing optional packages..."
for pkg in "${OPTIONAL_PKGS[@]}"; do
    if ! package_installed "$pkg"; then
        if prompt_yn "Install $pkg (recommended)?"; then
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                $SUDO apt-get install -y -qq "$pkg" || warn "Failed to install $pkg"
            else
                pkg install -y "$pkg" || warn "Failed to install $pkg"
            fi
        fi
    else
        print_step "$pkg already installed"
    fi
done

# Verify critical tools
print_step "Verifying installations..."

if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_success "Python $PYTHON_VERSION installed"
else
    fail "Python3 installation failed"
fi

if command_exists iwconfig; then
    print_success "wireless-tools installed"
else
    warn "iwconfig not found - Wi-Fi monitoring may not work"
fi

if command_exists kismet; then
    KISMET_VERSION=$(kismet --version 2>&1 | head -1)
    print_success "Kismet installed: $KISMET_VERSION"
else
    warn "Kismet not installed - you'll need to install it manually or use external packet capture"
fi

print_success "System dependencies installed"
