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

# Install Kismet (requires its own repo on most Debian-based systems)
if ! command_exists kismet; then
    if prompt_yn "Install Kismet (required for packet capture)?"; then
        print_step "Installing Kismet..."

        # Check if kismet is available in current repos
        if apt-cache show kismet &>/dev/null 2>&1; then
            $SUDO apt-get install -y kismet || warn "Failed to install Kismet from repos"
        else
            # Add official Kismet repository
            print_step "Kismet not found in repos - adding official Kismet repository..."
            if ! command_exists wget; then
                $SUDO apt-get install -y -qq wget
            fi

            # Detect release codename
            RELEASE=$(lsb_release -cs 2>/dev/null || echo "")
            if [[ -z "$RELEASE" ]]; then
                # Fallback for systems without lsb_release
                RELEASE=$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2)
            fi
            # Kali uses its own codename but Kismet repo uses Debian names
            if [[ "$PLATFORM" == "kali" ]]; then
                RELEASE="bookworm"
            fi

            if [[ -n "$RELEASE" ]]; then
                print_step "Adding Kismet repo for $RELEASE..."
                wget -q -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key | \
                    $SUDO tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null
                echo "deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/$RELEASE $RELEASE main" | \
                    $SUDO tee /etc/apt/sources.list.d/kismet.list >/dev/null
                $SUDO apt-get update -qq
                $SUDO apt-get install -y kismet || warn "Failed to install Kismet from official repo"
            else
                warn "Could not detect release codename - install Kismet manually:"
                warn "  See https://www.kismetwireless.net/docs/readme/installing/linux/"
            fi
        fi

        # Add current user to kismet group for non-root capture
        if getent group kismet &>/dev/null; then
            $SUDO usermod -aG kismet "${SUDO_USER:-$USER}" 2>/dev/null || true
            print_info "Added ${SUDO_USER:-$USER} to kismet group (re-login required)"
        fi
    fi
else
    KISMET_VERSION=$(kismet --version 2>&1 | head -1)
    print_step "Kismet already installed: $KISMET_VERSION"
fi

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
