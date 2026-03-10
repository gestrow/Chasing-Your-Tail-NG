#!/bin/bash
#
# Chasing Your Tail (CYT) - All-in-one launcher
# Starts Kismet and the GUI (or CLI if no display is available)
#
# Usage:
#   ./run.sh              # Start Kismet + GUI
#   ./run.sh --cli        # Start Kismet + CLI monitoring (no GUI)
#   ./run.sh --gui-only   # GUI only (Kismet already running)
#   ./run.sh --stop       # Stop all CYT services
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Determine Python path
if [[ -f "$SCRIPT_DIR/.venv/bin/python3" ]]; then
    PYTHON="$SCRIPT_DIR/.venv/bin/python3"
else
    PYTHON="python3"
fi

# Read config from config.json if available
WIFI_INTERFACE="wlan1"
KISMET_LOG_DIR=""
if [[ -f "$SCRIPT_DIR/config.json" ]]; then
    iface=$(grep -oP '"wifi_interface":\s*"\K[^"]+' "$SCRIPT_DIR/config.json" 2>/dev/null || true)
    [[ -n "$iface" ]] && WIFI_INTERFACE="$iface"
    # Extract kismet_logs path and get the directory portion
    klog=$(grep -oP '"kismet_logs":\s*"\K[^"]+' "$SCRIPT_DIR/config.json" 2>/dev/null || true)
    if [[ -n "$klog" ]]; then
        KISMET_LOG_DIR="$(dirname "$klog")"
        # Expand ~ to real home dir
        KISMET_LOG_DIR="${KISMET_LOG_DIR/#\~/$HOME}"
    fi
fi

show_help() {
    echo -e "${BOLD}CYT Launcher${NC}"
    echo ""
    echo "Usage: ./run.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cli        Start Kismet + CLI monitoring (no GUI)"
    echo "  --gui-only   Start GUI only (assumes Kismet is already running)"
    echo "  --stop       Stop all CYT processes"
    echo "  --status     Show status of CYT services"
    echo "  --help, -h   Show this help message"
}

start_kismet() {
    if pgrep -f kismet >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Kismet already running"
        return 0
    fi

    echo -e "${CYAN}→${NC} Starting Kismet on ${WIFI_INTERFACE}..."

    # Try kismet from PATH, then /usr/local/bin
    local kismet_bin
    if command -v kismet &>/dev/null; then
        kismet_bin="kismet"
    elif [[ -x /usr/local/bin/kismet ]]; then
        kismet_bin="/usr/local/bin/kismet"
    else
        echo -e "${RED}✗${NC} Kismet not found. Install it or start it manually."
        return 1
    fi

    # Ensure log directory exists
    if [[ -n "$KISMET_LOG_DIR" ]]; then
        mkdir -p "$KISMET_LOG_DIR"
        sudo "$kismet_bin" -c "$WIFI_INTERFACE" --daemonize --log-prefix "$KISMET_LOG_DIR"
    else
        sudo "$kismet_bin" -c "$WIFI_INTERFACE" --daemonize
    fi

    # Wait for Kismet to initialize
    local attempts=0
    while ! pgrep -f kismet >/dev/null 2>&1; do
        sleep 1
        attempts=$((attempts + 1))
        if [[ $attempts -ge 10 ]]; then
            echo -e "${RED}✗${NC} Kismet failed to start"
            return 1
        fi
    done

    echo -e "${GREEN}✓${NC} Kismet running (web UI: http://localhost:2501)"
}

start_gui() {
    echo -e "${CYAN}→${NC} Starting CYT GUI..."
    $PYTHON "$SCRIPT_DIR/cyt_gui.py" &
    echo -e "${GREEN}✓${NC} GUI launched (PID: $!)"
}

start_cli() {
    echo -e "${CYAN}→${NC} Starting CYT CLI monitoring..."
    $PYTHON "$SCRIPT_DIR/chasing_your_tail.py"
}

stop_all() {
    echo -e "${CYAN}→${NC} Stopping CYT processes..."
    pkill -f "cyt_gui.py" 2>/dev/null && echo -e "${GREEN}✓${NC} GUI stopped" || echo -e "${YELLOW}⚠${NC} GUI not running"
    pkill -f "chasing_your_tail.py" 2>/dev/null && echo -e "${GREEN}✓${NC} CLI stopped" || echo -e "${YELLOW}⚠${NC} CLI not running"
    pkill -f "surveillance_analyzer.py" 2>/dev/null && echo -e "${GREEN}✓${NC} Analyzer stopped" || true
    echo ""
    echo -e "${YELLOW}⚠${NC} Kismet left running (stop manually with: sudo pkill kismet)"
}

show_status() {
    echo -e "${BOLD}CYT Status${NC}"
    echo ""

    if pgrep -f kismet >/dev/null 2>&1; then
        echo -e "  Kismet:     ${GREEN}running${NC}"
    else
        echo -e "  Kismet:     ${RED}stopped${NC}"
    fi

    if pgrep -f "cyt_gui.py" >/dev/null 2>&1; then
        echo -e "  GUI:        ${GREEN}running${NC}"
    else
        echo -e "  GUI:        ${RED}stopped${NC}"
    fi

    if pgrep -f "chasing_your_tail.py" >/dev/null 2>&1; then
        echo -e "  CLI:        ${GREEN}running${NC}"
    else
        echo -e "  CLI:        ${RED}stopped${NC}"
    fi
}

# Parse arguments
MODE="default"
case "${1:-}" in
    --cli)
        MODE="cli"
        ;;
    --gui-only)
        MODE="gui-only"
        ;;
    --stop)
        stop_all
        exit 0
        ;;
    --status)
        show_status
        exit 0
        ;;
    --help|-h)
        show_help
        exit 0
        ;;
    "")
        MODE="default"
        ;;
    *)
        echo -e "${RED}✗${NC} Unknown option: $1"
        show_help
        exit 1
        ;;
esac

echo ""
echo -e "${BOLD}${CYAN}Chasing Your Tail${NC}"
echo ""

case "$MODE" in
    default)
        start_kismet
        echo ""
        if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
            start_gui
        else
            echo -e "${YELLOW}⚠${NC} No display detected, falling back to CLI mode"
            start_cli
        fi
        ;;
    cli)
        start_kismet
        echo ""
        start_cli
        ;;
    gui-only)
        start_gui
        ;;
esac

echo ""
echo -e "${GREEN}✓${NC} CYT is running. Use ${CYAN}./run.sh --stop${NC} to stop."
