#!/bin/bash
#
# Chasing Your Tail (CYT) Universal Installer
# Supports: Debian, Ubuntu, Kali Linux, Kali NetHunter
#
# Usage:
#   ./install.sh                    # Interactive installation
#   ./install.sh --unattended       # Non-interactive with defaults
#   ./install.sh --help             # Show all options
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/scripts/lib/colors.sh"
source "$SCRIPT_DIR/scripts/lib/utils.sh"
source "$SCRIPT_DIR/scripts/lib/distro.sh"

# Version
VERSION="1.0.0"

# Default configuration
UNATTENDED="${UNATTENDED:-false}"
INSTALL_DIR=""
NO_AUTOSTART="${NO_AUTOSTART:-false}"
NO_GUI="${NO_GUI:-false}"
WIFI_INTERFACE=""
KISMET_LOGS=""

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unattended|-u)
                UNATTENDED="true"
                shift
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --no-autostart)
                NO_AUTOSTART="true"
                shift
                ;;
            --no-gui|--headless)
                NO_GUI="true"
                shift
                ;;
            --wifi-interface)
                WIFI_INTERFACE="$2"
                shift 2
                ;;
            --kismet-logs)
                KISMET_LOGS="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "CYT Installer v$VERSION"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Chasing Your Tail (CYT) Installer v$VERSION

Usage: ./install.sh [OPTIONS]

Options:
  --unattended, -u       Non-interactive installation with defaults
  --install-dir PATH     Install to specific directory (default: in-place or /opt/cyt)
  --no-autostart         Skip systemd/autostart setup
  --no-gui, --headless   Headless installation (skip GUI components)
  --wifi-interface IF    Wi-Fi interface for Kismet (default: auto-detect)
  --kismet-logs PATH     Kismet database path (default: ~/kismet_logs/*.kismet)
  --help, -h             Show this help message
  --version, -v          Show version

Examples:
  ./install.sh                                    # Interactive install
  ./install.sh --unattended                       # Quick install with defaults
  ./install.sh --unattended --no-gui              # Headless server install
  ./install.sh --install-dir /opt/cyt             # Install to /opt/cyt

Supported Platforms:
  - Debian 10+
  - Ubuntu 20.04+
  - Kali Linux
  - Kali NetHunter (Android)

EOF
}

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
   _____ _               _                __   __               _____     _ _
  / ____| |             (_)              \ \ / /              |_   _|   (_) |
 | |    | |__   __ _ ___ _ _ __   __ _    \ V /___  _   _ _ __  | | __ _ _| |
 | |    | '_ \ / _` / __| | '_ \ / _` |    > </ _ \| | | | '__| | |/ _` | | |
 | |____| | | | (_| \__ \ | | | | (_| |   / . \ (_) | |_| | |    | | (_| | | |
  \_____|_| |_|\__,_|___/_|_| |_|\__, |  /_/ \_\___/ \__,_|_|    \_/\__,_|_|_|
                                  __/ |
                                 |___/
EOF
    echo -e "${NC}"
    echo -e "${WHITE}Wi-Fi Probe Request Analyzer & Surveillance Detector${NC}"
    echo -e "${CYAN}Installer v$VERSION${NC}"
    echo
}

# Main installation flow
main() {
    parse_args "$@"

    show_banner

    # Check root/sudo
    check_root

    # Detect and display platform
    print_section "Platform Detection"
    PLATFORM=$(detect_platform)
    get_platform_info

    if ! is_supported_platform; then
        fail "Unsupported platform: $PLATFORM"
    fi

    # Choose install location
    print_section "Installation Location"
    if [[ -z "$INSTALL_DIR" ]]; then
        if [[ "$UNATTENDED" == "true" ]]; then
            INSTALL_DIR="$SCRIPT_DIR"
            print_info "Installing in-place: $INSTALL_DIR"
        else
            echo "Where would you like to install CYT?"
            local choice=$(prompt_select "Select installation type:" \
                "In-place (current directory: $SCRIPT_DIR)" \
                "System-wide (/opt/cyt)")

            if [[ "$choice" == *"In-place"* ]]; then
                INSTALL_DIR="$SCRIPT_DIR"
            else
                INSTALL_DIR="/opt/cyt"
            fi
        fi
    fi

    print_info "Install directory: $INSTALL_DIR"

    # Copy files if installing to different location
    if [[ "$INSTALL_DIR" != "$SCRIPT_DIR" ]]; then
        print_step "Copying files to $INSTALL_DIR..."
        $SUDO mkdir -p "$INSTALL_DIR"
        $SUDO cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
        $SUDO chown -R "$USER:$USER" "$INSTALL_DIR" 2>/dev/null || true
    fi

    # Export for subscripts
    export INSTALL_DIR
    export UNATTENDED
    export NO_GUI
    export WIFI_INTERFACE
    export KISMET_LOGS
    export SUDO

    # Run installation steps
    print_section "Installing System Dependencies"
    bash "$INSTALL_DIR/scripts/install_system_deps.sh"

    print_section "Installing Python Dependencies"
    bash "$INSTALL_DIR/scripts/install_python_deps.sh"

    print_section "Configuring CYT"
    bash "$INSTALL_DIR/scripts/setup_config.sh"

    # Setup autostart (unless disabled)
    if [[ "$NO_AUTOSTART" != "true" ]]; then
        if has_systemd || is_chroot; then
            if [[ "$UNATTENDED" == "true" ]] || prompt_yn "Set up auto-start services?"; then
                bash "$INSTALL_DIR/scripts/setup_systemd.sh"
            fi
        fi
    fi

    # Verify installation
    print_section "Verifying Installation"
    bash "$INSTALL_DIR/scripts/verify.sh"

    # Final instructions
    print_header "Installation Complete!"

    echo -e "${GREEN}CYT has been successfully installed!${NC}"
    echo
    echo -e "${BOLD}Quick Start:${NC}"
    echo -e "  ${CYAN}cd $INSTALL_DIR${NC}"
    echo

    if [[ -f "$INSTALL_DIR/.venv/bin/python3" ]]; then
        echo -e "  ${CYAN}source .venv/bin/activate${NC}  # Activate virtual environment"
    fi

    echo -e "  ${CYAN}python3 cyt_gui.py${NC}          # Start GUI"
    echo -e "  ${CYAN}python3 chasing_your_tail.py${NC} # CLI monitoring"
    echo
    echo -e "${BOLD}Documentation:${NC}"
    echo -e "  README.md     - Full documentation"
    echo -e "  CLAUDE.md     - Developer guide"
    echo

    if has_systemd; then
        echo -e "${BOLD}Service Management:${NC}"
        echo -e "  ${CYAN}sudo systemctl start cyt-kismet${NC}   # Start Kismet"
        echo -e "  ${CYAN}sudo systemctl start cyt-gui${NC}      # Start GUI"
        echo -e "  ${CYAN}sudo systemctl status cyt-*${NC}       # Check status"
        echo
    fi

    print_success "Happy hunting!"
}

# Run main
main "$@"
