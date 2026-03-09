#!/bin/bash
# Interactive configuration setup for CYT

set -e

# Source library functions (use parent's CYT_LIB_DIR if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYT_LIB_DIR="${CYT_LIB_DIR:-$SCRIPT_DIR/lib}"
source "$CYT_LIB_DIR/colors.sh"
source "$CYT_LIB_DIR/utils.sh"
source "$CYT_LIB_DIR/distro.sh"

print_section "Configuring CYT"

# Configuration
INSTALL_DIR="${INSTALL_DIR:-.}"
CONFIG_FILE="$INSTALL_DIR/config.json"
CONFIG_TEMPLATE="$INSTALL_DIR/config.json.template"

# Default values
DEFAULT_KISMET_LOGS="/home/$USER/kismet_logs/*.kismet"
DEFAULT_WIFI_INTERFACE="wlan1"

# Detect available interfaces
print_step "Detecting Wi-Fi interfaces..."
WIFI_INTERFACES=($(detect_wifi_interfaces))

if [[ ${#WIFI_INTERFACES[@]} -gt 0 ]]; then
    print_info "Found interfaces: ${WIFI_INTERFACES[*]}"
    DEFAULT_WIFI_INTERFACE="${WIFI_INTERFACES[0]}"
else
    print_warning "No Wi-Fi interfaces detected"
fi

# Backup existing config
if [[ -f "$CONFIG_FILE" ]]; then
    backup_file "$CONFIG_FILE"
fi

# Interactive configuration
if [[ "$UNATTENDED" != "true" ]]; then
    print_info "Configure CYT settings (press Enter for defaults)"
    echo

    # Kismet logs path
    KISMET_LOGS=$(prompt_input "Kismet database path" "$DEFAULT_KISMET_LOGS")

    # Wi-Fi interface
    if [[ ${#WIFI_INTERFACES[@]} -gt 1 ]]; then
        echo "Available interfaces: ${WIFI_INTERFACES[*]}"
    fi
    WIFI_INTERFACE=$(prompt_input "Wi-Fi interface for monitoring" "$DEFAULT_WIFI_INTERFACE")

    # Geographic bounds (optional)
    if prompt_yn "Configure geographic search bounds?" "n"; then
        LAT_MIN=$(prompt_input "Minimum latitude (CONUS)" "24.5")
        LAT_MAX=$(prompt_input "Maximum latitude (CONUS)" "49.0")
        LON_MIN=$(prompt_input "Minimum longitude (CONUS)" "-125.0")
        LON_MAX=$(prompt_input "Maximum longitude (CONUS)" "-66.9")
    else
        LAT_MIN="24.5"
        LAT_MAX="49.0"
        LON_MIN="-125.0"
        LON_MAX="-66.9"
    fi
else
    # Unattended defaults
    KISMET_LOGS="${KISMET_LOGS:-$DEFAULT_KISMET_LOGS}"
    WIFI_INTERFACE="${WIFI_INTERFACE:-$DEFAULT_WIFI_INTERFACE}"
    LAT_MIN="${LAT_MIN:-24.5}"
    LAT_MAX="${LAT_MAX:-49.0}"
    LON_MIN="${LON_MIN:--125.0}"
    LON_MAX="${LON_MAX:--66.9}"
fi

# Generate config.json
print_step "Generating config.json..."

cat > "$CONFIG_FILE" << EOF
{
  "paths": {
    "base_dir": "$INSTALL_DIR",
    "log_dir": "logs",
    "kismet_logs": "$KISMET_LOGS",
    "ignore_lists": {
      "mac": "mac_list.json",
      "ssid": "ssid_list.json"
    }
  },
  "timing": {
    "check_interval": 60,
    "list_update_interval": 5,
    "time_windows": {
      "recent": 5,
      "medium": 10,
      "old": 15,
      "oldest": 20
    }
  },
  "search": {
    "lat_min": $LAT_MIN,
    "lat_max": $LAT_MAX,
    "lon_min": $LON_MIN,
    "lon_max": $LON_MAX
  },
  "wifi_interface": "$WIFI_INTERFACE"
}
EOF

print_success "Configuration saved to $CONFIG_FILE"

# Create required directories
print_step "Creating directory structure..."
ensure_dir "$INSTALL_DIR/logs"
ensure_dir "$INSTALL_DIR/reports"
ensure_dir "$INSTALL_DIR/surveillance_reports"
ensure_dir "$INSTALL_DIR/kml_files"
ensure_dir "$INSTALL_DIR/analysis_logs"
ensure_dir "$INSTALL_DIR/ignore_lists"
ensure_dir "$INSTALL_DIR/secure_credentials"

# Initialize empty ignore lists if they don't exist
if [[ ! -f "$INSTALL_DIR/ignore_lists/mac_list.json" ]]; then
    echo "[]" > "$INSTALL_DIR/ignore_lists/mac_list.json"
fi
if [[ ! -f "$INSTALL_DIR/ignore_lists/ssid_list.json" ]]; then
    echo "[]" > "$INSTALL_DIR/ignore_lists/ssid_list.json"
fi

print_success "Directory structure created"

# Credential migration
if [[ "$UNATTENDED" != "true" ]]; then
    if prompt_yn "Set up WiGLE API credentials now?" "n"; then
        print_info "Running credential migration..."
        cd "$INSTALL_DIR"
        python3 migrate_credentials.py || warn "Credential migration failed - you can run this later"
    else
        print_info "You can set up credentials later with: python3 migrate_credentials.py"
    fi
fi

print_success "Configuration complete"
