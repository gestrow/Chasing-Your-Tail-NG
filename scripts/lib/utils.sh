#!/bin/bash
# Common utility functions for CYT installer

# Source colors if not already loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$NC" ]] && source "$SCRIPT_DIR/colors.sh"

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &>/dev/null; then
            SUDO="sudo"
            print_info "Will use sudo for privileged operations"
        else
            print_error "This script requires root privileges. Please run as root or install sudo."
            exit 1
        fi
    else
        SUDO=""
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if a package is installed (apt)
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Get package version from apt
get_apt_version() {
    local pkg="$1"
    apt-cache show "$pkg" 2>/dev/null | grep "^Version:" | head -1 | cut -d' ' -f2
}

# Compare versions (returns 0 if $1 >= $2)
version_gte() {
    dpkg --compare-versions "$1" ge "$2" 2>/dev/null
}

# Prompt for yes/no with default
prompt_yn() {
    local prompt="$1"
    local default="${2:-y}"
    local yn

    if [[ "$UNATTENDED" == "true" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " yn
        yn="${yn:-y}"
    else
        read -rp "$prompt [y/N]: " yn
        yn="${yn:-n}"
    fi

    [[ "$yn" =~ ^[Yy] ]]
}

# Prompt for input with default
prompt_input() {
    local prompt="$1"
    local default="$2"
    local result

    if [[ "$UNATTENDED" == "true" ]]; then
        echo "$default"
        return
    fi

    read -rp "$prompt [$default]: " result
    echo "${result:-$default}"
}

# Prompt for selection from list
prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local selection

    if [[ "$UNATTENDED" == "true" ]]; then
        echo "${options[0]}"
        return
    fi

    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done

    while true; do
        read -rp "Enter choice [1-${#options[@]}]: " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#options[@]} )); then
            echo "${options[$((selection-1))]}"
            return
        fi
        print_error "Invalid selection"
    done
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        print_step "Created directory: $dir"
    fi
}

# Backup a file with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        print_step "Backed up: $file → $backup"
    fi
}

# Detect available Wi-Fi interfaces
detect_wifi_interfaces() {
    local interfaces=()
    for iface in /sys/class/net/*/wireless; do
        if [[ -d "$iface" ]]; then
            interfaces+=("$(basename "$(dirname "$iface")")")
        fi
    done

    # Fallback: check iwconfig
    if [[ ${#interfaces[@]} -eq 0 ]] && command_exists iwconfig; then
        while IFS= read -r line; do
            interfaces+=("$line")
        done < <(iwconfig 2>/dev/null | grep -oP '^\w+(?=\s+IEEE)')
    fi

    echo "${interfaces[@]}"
}

# Check if systemd is available
has_systemd() {
    pidof systemd &>/dev/null || [[ -d /run/systemd/system ]]
}

# Fail with error message and exit
fail() {
    print_error "$1"
    exit 1
}

# Warn but continue
warn() {
    print_warning "$1"
}
