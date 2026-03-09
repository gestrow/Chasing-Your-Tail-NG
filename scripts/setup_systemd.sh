#!/bin/bash
# Systemd service setup for CYT

set -e

# Source library functions (use parent's CYT_LIB_DIR if available)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYT_LIB_DIR="${CYT_LIB_DIR:-$SCRIPT_DIR/lib}"
source "$CYT_LIB_DIR/colors.sh"
source "$CYT_LIB_DIR/utils.sh"
source "$CYT_LIB_DIR/distro.sh"

print_section "Setting Up Auto-Start Services"

# Configuration
INSTALL_DIR="${INSTALL_DIR:-.}"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_USER="${SERVICE_USER:-$USER}"

# Check if systemd is available
if ! has_systemd; then
    print_warning "Systemd not available (running in chroot?)"
    print_info "Creating manual start/stop scripts instead..."

    # Create start script
    cat > "$INSTALL_DIR/start_cyt.sh" << EOF
#!/bin/bash
# Start CYT services manually
cd "$INSTALL_DIR"

# Start Kismet
echo "Starting Kismet..."
sudo kismet -c \$(grep -oP '"wifi_interface":\s*"\K[^"]+' config.json) --daemonize

# Wait for Kismet to initialize
sleep 5

# Start GUI (if display available)
if [[ -n "\$DISPLAY" ]]; then
    echo "Starting CYT GUI..."
    python3 cyt_gui.py &
else
    echo "No display available - run 'python3 cyt_gui.py' manually when display is ready"
fi

echo "CYT services started"
EOF
    chmod +x "$INSTALL_DIR/start_cyt.sh"

    # Create stop script
    cat > "$INSTALL_DIR/stop_cyt.sh" << EOF
#!/bin/bash
# Stop CYT services
echo "Stopping CYT services..."
pkill -f cyt_gui.py 2>/dev/null || true
sudo pkill kismet 2>/dev/null || true
echo "CYT services stopped"
EOF
    chmod +x "$INSTALL_DIR/stop_cyt.sh"

    print_success "Created start_cyt.sh and stop_cyt.sh"
    print_info "Run ./start_cyt.sh to start services manually"
    exit 0
fi

# Get Wi-Fi interface from config
WIFI_INTERFACE=$(grep -oP '"wifi_interface":\s*"\K[^"]+' "$INSTALL_DIR/config.json" 2>/dev/null || echo "wlan1")

# Determine Python path
if [[ -f "$INSTALL_DIR/.venv/bin/python3" ]]; then
    PYTHON_PATH="$INSTALL_DIR/.venv/bin/python3"
else
    PYTHON_PATH="/usr/bin/python3"
fi

# Create Kismet service
print_step "Creating Kismet service..."
$SUDO tee "$SYSTEMD_DIR/cyt-kismet.service" > /dev/null << EOF
[Unit]
Description=Kismet Wireless Packet Capture for CYT
Documentation=https://github.com/gestrow/Chasing-Your-Tail-NG/tree/dev
After=network.target
Wants=network.target

[Service]
Type=forking
ExecStart=/usr/bin/kismet -c $WIFI_INTERFACE --daemonize
ExecStop=/usr/bin/pkill kismet
Restart=on-failure
RestartSec=10
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create GUI service (only if not headless)
if [[ "$NO_GUI" != "true" ]]; then
    print_step "Creating GUI service..."
    $SUDO tee "$SYSTEMD_DIR/cyt-gui.service" > /dev/null << EOF
[Unit]
Description=Chasing Your Tail GUI
Documentation=https://github.com/gestrow/Chasing-Your-Tail-NG/tree/dev
After=graphical.target cyt-kismet.service
Wants=graphical.target

[Service]
Type=simple
User=$SERVICE_USER
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$SERVICE_USER/.Xauthority
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_PATH $INSTALL_DIR/cyt_gui.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF
fi

# Reload systemd
print_step "Reloading systemd daemon..."
$SUDO systemctl daemon-reload

# Enable services
if prompt_yn "Enable services to start on boot?"; then
    print_step "Enabling services..."
    $SUDO systemctl enable cyt-kismet.service
    [[ "$NO_GUI" != "true" ]] && $SUDO systemctl enable cyt-gui.service
    print_success "Services enabled"
fi

# Start services now
if prompt_yn "Start services now?"; then
    print_step "Starting Kismet service..."
    $SUDO systemctl start cyt-kismet.service || warn "Failed to start Kismet"

    if [[ "$NO_GUI" != "true" ]] && [[ -n "$DISPLAY" ]]; then
        print_step "Starting GUI service..."
        $SUDO systemctl start cyt-gui.service || warn "Failed to start GUI"
    fi
fi

# Print status
print_section "Service Status"
$SUDO systemctl status cyt-kismet.service --no-pager || true
[[ "$NO_GUI" != "true" ]] && $SUDO systemctl status cyt-gui.service --no-pager || true

print_success "Systemd services configured"
print_info "Commands:"
print_info "  Start:   sudo systemctl start cyt-kismet cyt-gui"
print_info "  Stop:    sudo systemctl stop cyt-kismet cyt-gui"
print_info "  Status:  sudo systemctl status cyt-kismet cyt-gui"
print_info "  Logs:    journalctl -u cyt-kismet -u cyt-gui -f"
