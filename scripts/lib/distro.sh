#!/bin/bash
# Distribution and platform detection for CYT installer

# Source colors if not already loaded
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$NC" ]] && source "$_LIB_DIR/colors.sh"

# Detect the platform/distribution
detect_platform() {
    # Check for Android/Termux first
    if [[ -d "/data/data/com.termux" ]]; then
        if [[ -f "/usr/share/kali-defaults/kali-nethunter" ]] || \
           grep -qi "nethunter" /etc/os-release 2>/dev/null; then
            echo "nethunter"
        elif [[ -f "/etc/debian_version" ]]; then
            # proot-distro Debian/Kali
            if grep -qi "kali" /etc/os-release 2>/dev/null; then
                echo "nethunter"  # Treat proot Kali same as NetHunter
            else
                echo "termux-proot"
            fi
        else
            echo "termux"
        fi
        return
    fi

    # Check for standard Linux distributions
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        case "${ID,,}" in
            kali)
                echo "kali"
                ;;
            debian)
                echo "debian"
                ;;
            ubuntu)
                echo "ubuntu"
                ;;
            parrot)
                echo "parrot"
                ;;
            *)
                if [[ -f "/etc/debian_version" ]]; then
                    echo "debian-like"
                else
                    echo "unknown"
                fi
                ;;
        esac
    elif [[ -f "/etc/debian_version" ]]; then
        echo "debian-like"
    else
        echo "unknown"
    fi
}

# Get detailed platform info
get_platform_info() {
    local platform
    platform=$(detect_platform)

    echo "Platform: $platform"

    case "$platform" in
        nethunter)
            echo "Type: Kali NetHunter (Android chroot)"
            echo "Package Manager: apt"
            echo "Systemd: $(has_systemd && echo "available" || echo "not available (chroot)")"
            ;;
        termux)
            echo "Type: Native Termux"
            echo "Package Manager: pkg"
            echo "Systemd: not available"
            ;;
        termux-proot)
            echo "Type: Termux proot-distro"
            echo "Package Manager: apt"
            echo "Systemd: not available"
            ;;
        kali)
            echo "Type: Kali Linux"
            echo "Package Manager: apt"
            echo "Systemd: $(has_systemd && echo "available" || echo "not available")"
            ;;
        debian|ubuntu|parrot|debian-like)
            echo "Type: Debian-based"
            echo "Package Manager: apt"
            echo "Systemd: $(has_systemd && echo "available" || echo "not available")"
            ;;
        *)
            echo "Type: Unknown"
            echo "Package Manager: unknown"
            ;;
    esac
}

# Check if platform is supported
is_supported_platform() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        kali|debian|ubuntu|parrot|debian-like|nethunter)
            return 0
            ;;
        termux|termux-proot)
            print_warning "Termux support is experimental"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get the package manager command
get_pkg_manager() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        termux)
            echo "pkg"
            ;;
        *)
            echo "apt"
            ;;
    esac
}

# Check if we're in a chroot (NetHunter)
is_chroot() {
    # Multiple detection methods
    if [[ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/. 2>/dev/null)" ]]; then
        return 0
    fi

    # Check if systemd PID 1 is missing
    if [[ ! -d "/run/systemd/system" ]] && [[ -f "/etc/debian_version" ]]; then
        # Likely chroot if on Debian without systemd
        return 0
    fi

    return 1
}
