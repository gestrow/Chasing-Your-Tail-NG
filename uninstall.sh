#!/bin/bash
#
# Chasing Your Tail (CYT) Uninstaller
#
# Usage:
#   ./uninstall.sh              # Interactive uninstall
#   ./uninstall.sh --force      # Remove everything without prompts
#   ./uninstall.sh --keep-data  # Keep logs and reports
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
if [[ -f "$SCRIPT_DIR/scripts/lib/colors.sh" ]]; then
    source "$SCRIPT_DIR/scripts/lib/colors.sh"
    source "$SCRIPT_DIR/scripts/lib/utils.sh"
    source "$SCRIPT_DIR/scripts/lib/distro.sh"
else
    # Minimal fallback if library not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    print_error() { echo -e "${RED}✗ $1${NC}"; }
    print_success() { echo -e "${GREEN}✓ $1${NC}"; }
    print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_info() { echo -e "$1"; }
    prompt_yn() {
        local prompt="$1" default="${2:-n}" yn
        read -rp "$prompt [y/N]: " yn
        [[ "${yn:-$default}" =~ ^[Yy] ]]
    }
fi

# Configuration
FORCE="${FORCE:-false}"
KEEP_DATA="${KEEP_DATA:-false}"
INSTALL_DIR="${INSTALL_DIR:-$SCRIPT_DIR}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            FORCE="true"
            shift
            ;;
        --keep-data|-k)
            KEEP_DATA="true"
            shift
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./uninstall.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force, -f      Remove without prompts"
            echo "  --keep-data, -k  Keep logs, reports, and user data"
            echo "  --install-dir    Specify install directory"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           CYT Uninstaller                                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

print_info "Install directory: $INSTALL_DIR"
echo ""

# Confirm uninstall
if [[ "$FORCE" != "true" ]]; then
    print_warning "This will remove CYT and its configuration."
    if ! prompt_yn "Are you sure you want to continue?"; then
        print_info "Uninstall cancelled."
        exit 0
    fi
fi

# Check root for systemd operations
if [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Stop and disable systemd services
echo ""
print_info "Stopping services..."

if pidof systemd &>/dev/null; then
    for service in cyt-kismet cyt-gui; do
        if systemctl list-unit-files 2>/dev/null | grep -q "$service.service"; then
            print_info "  Stopping $service..."
            $SUDO systemctl stop "$service.service" 2>/dev/null || true
            $SUDO systemctl disable "$service.service" 2>/dev/null || true
        fi
    done

    # Remove service files
    print_info "Removing systemd services..."
    $SUDO rm -f /etc/systemd/system/cyt-kismet.service
    $SUDO rm -f /etc/systemd/system/cyt-gui.service
    $SUDO systemctl daemon-reload 2>/dev/null || true
fi

# Kill any running CYT processes
print_info "Stopping running processes..."
pkill -f "cyt_gui.py" 2>/dev/null || true
pkill -f "chasing_your_tail.py" 2>/dev/null || true
pkill -f "surveillance_analyzer.py" 2>/dev/null || true

# Remove virtual environment
if [[ -d "$INSTALL_DIR/.venv" ]]; then
    print_info "Removing virtual environment..."
    rm -rf "$INSTALL_DIR/.venv"
fi

# Remove generated files
print_info "Removing generated files..."
rm -f "$INSTALL_DIR/.python_install_method"
rm -f "$INSTALL_DIR/activate_cyt.sh"
rm -f "$INSTALL_DIR/start_cyt.sh"
rm -f "$INSTALL_DIR/stop_cyt.sh"
rm -f "$INSTALL_DIR/cyt_security.log"
rm -f "$INSTALL_DIR/surveillance_analysis.log"

# Handle user data
DATA_DIRS=(
    "logs"
    "reports"
    "surveillance_reports"
    "kml_files"
    "analysis_logs"
    "secure_credentials"
)

if [[ "$KEEP_DATA" == "true" ]]; then
    print_info "Keeping user data directories..."
else
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        print_warning "The following directories contain your data:"
        for dir in "${DATA_DIRS[@]}"; do
            if [[ -d "$INSTALL_DIR/$dir" ]]; then
                local count=$(find "$INSTALL_DIR/$dir" -type f 2>/dev/null | wc -l)
                echo "  - $dir/ ($count files)"
            fi
        done
        echo ""
        if ! prompt_yn "Delete all data directories?"; then
            KEEP_DATA="true"
        fi
    fi

    if [[ "$KEEP_DATA" != "true" ]]; then
        print_info "Removing data directories..."
        for dir in "${DATA_DIRS[@]}"; do
            if [[ -d "$INSTALL_DIR/$dir" ]]; then
                rm -rf "$INSTALL_DIR/${dir:?}"
            fi
        done
    fi
fi

# If installed to /opt/cyt, offer to remove the whole directory
if [[ "$INSTALL_DIR" == "/opt/cyt" ]]; then
    if [[ "$FORCE" == "true" ]] || prompt_yn "Remove entire /opt/cyt directory?"; then
        print_info "Removing $INSTALL_DIR..."
        $SUDO rm -rf "$INSTALL_DIR"
    fi
fi

echo ""
print_success "CYT has been uninstalled."

if [[ "$KEEP_DATA" == "true" ]]; then
    print_info "Your data has been preserved in: $INSTALL_DIR"
fi

echo ""
