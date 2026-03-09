#!/usr/bin/env python3
"""
CYT Configuration & Credential Setup Tool
Reviews config.json for missing or default settings and prompts for updates.
Sets up WiGLE API credentials in encrypted storage.
"""
import json
import sys
import base64
import os
from pathlib import Path
from secure_credentials import SecureCredentialManager


def prompt_value(label, current, allow_empty=False):
    """Prompt user for a value, showing current. Enter keeps current value."""
    if current is not None:
        response = input(f"  {label} [{current}]: ").strip()
        return response if response else current
    else:
        response = input(f"  {label}: ").strip()
        if not response and not allow_empty:
            return None
        return response


def review_config(config, config_file):
    """Review and update config.json settings interactively."""
    changed = False

    # --- Paths ---
    print("\n📂 Paths")
    print("-" * 40)

    paths = config.setdefault('paths', {})

    kismet_logs = paths.get('kismet_logs', '')
    new_val = prompt_value("Kismet database path", kismet_logs or "~/kismet_logs/*.kismet")
    if new_val != kismet_logs:
        paths['kismet_logs'] = new_val
        changed = True

    log_dir = paths.get('log_dir', 'logs')
    new_val = prompt_value("Log directory", log_dir)
    if new_val != log_dir:
        paths['log_dir'] = new_val
        changed = True

    # Ensure ignore_lists sub-config exists
    ignore = paths.setdefault('ignore_lists', {})
    if 'mac' not in ignore:
        ignore['mac'] = 'mac_list.json'
        changed = True
    if 'ssid' not in ignore:
        ignore['ssid'] = 'ssid_list.json'
        changed = True

    # --- Wi-Fi Interface ---
    print("\n📡 Wi-Fi Interface")
    print("-" * 40)

    wifi = config.get('wifi_interface', 'wlan1')
    # Show available interfaces
    try:
        interfaces = []
        net_dir = Path('/sys/class/net')
        if net_dir.exists():
            for iface in net_dir.iterdir():
                wireless_dir = iface / 'wireless'
                if wireless_dir.exists():
                    interfaces.append(iface.name)
        if interfaces:
            print(f"  Detected Wi-Fi interfaces: {', '.join(interfaces)}")
    except Exception:
        pass
    print("  (Use a DEDICATED monitoring adapter, NOT your primary Wi-Fi)")
    new_val = prompt_value("Wi-Fi interface for monitoring", wifi)
    if new_val != wifi:
        config['wifi_interface'] = new_val
        changed = True

    # --- Timing ---
    print("\n⏱️  Timing")
    print("-" * 40)

    timing = config.setdefault('timing', {})
    check_interval = timing.get('check_interval', 60)
    new_val = prompt_value("Check interval (seconds)", str(check_interval))
    try:
        new_int = int(new_val)
        if new_int != check_interval:
            timing['check_interval'] = new_int
            changed = True
    except ValueError:
        print("  Invalid number, keeping current value")

    list_update = timing.get('list_update_interval', 5)
    new_val = prompt_value("List update interval (cycles)", str(list_update))
    try:
        new_int = int(new_val)
        if new_int != list_update:
            timing['list_update_interval'] = new_int
            changed = True
    except ValueError:
        print("  Invalid number, keeping current value")

    windows = timing.setdefault('time_windows', {})
    window_defaults = {'recent': 5, 'medium': 10, 'old': 15, 'oldest': 20}
    for name, default in window_defaults.items():
        current = windows.get(name, default)
        new_val = prompt_value(f"  Time window '{name}' (minutes)", str(current))
        try:
            new_int = int(new_val)
            if new_int != current:
                windows[name] = new_int
                changed = True
        except ValueError:
            print("    Invalid number, keeping current value")

    # --- Geographic Search Bounds ---
    print("\n🌍 Geographic Search Bounds (CONUS defaults)")
    print("-" * 40)

    search = config.setdefault('search', {})
    geo_defaults = {
        'lat_min': 24.5,
        'lat_max': 49.0,
        'lon_min': -125.0,
        'lon_max': -66.9,
    }
    geo_labels = {
        'lat_min': 'Minimum latitude',
        'lat_max': 'Maximum latitude',
        'lon_min': 'Minimum longitude',
        'lon_max': 'Maximum longitude',
    }
    for key, default in geo_defaults.items():
        current = search.get(key, default)
        new_val = prompt_value(geo_labels[key], str(current))
        try:
            new_float = float(new_val)
            if new_float != current:
                search[key] = new_float
                changed = True
        except ValueError:
            print("  Invalid number, keeping current value")

    # --- Save if changed ---
    if changed:
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        print(f"\n✅ Configuration saved to {config_file}")
    else:
        print("\n✅ No changes made to configuration")

    return config


def setup_wigle_credentials(cred_manager):
    """Interactive WiGLE API credential setup"""
    print("\n📡 WiGLE API Credential Setup")
    print("-" * 40)
    print("  Get your API credentials from: https://wigle.net/account")
    print("  (Under 'API Token' section)\n")

    api_name = input("  WiGLE API Name: ").strip()
    if not api_name:
        print("  Skipped — no API name entered")
        return False

    api_token = input("  WiGLE API Token: ").strip()
    if not api_token:
        print("  Skipped — no API token entered")
        return False

    # WiGLE uses HTTP Basic Auth with base64-encoded "name:token"
    encoded_token = base64.b64encode(f"{api_name}:{api_token}".encode()).decode()

    cred_manager.store_credential('wigle', 'encoded_token', encoded_token)
    print("  ✅ WiGLE API credentials stored securely")
    return True


def migrate_from_config(cred_manager, config, config_file):
    """Migrate existing credentials from config.json to encrypted storage"""
    api_keys = config['api_keys']

    print("⚠️  Found API keys in config.json — this is a security risk!")
    print("🔒 Migrating to encrypted storage...")

    # Migrate WiGLE credentials
    if 'wigle' in api_keys:
        wigle_config = api_keys['wigle']
        if 'encoded_token' in wigle_config:
            print("\n📡 Migrating WiGLE API token...")
            cred_manager.store_credential('wigle', 'encoded_token', wigle_config['encoded_token'])
            print("✅ WiGLE API token stored securely")

    # Remove API keys from config
    config.pop('api_keys', None)

    # Save cleaned config
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"✅ API keys removed from {config_file}")
    print("🔐 Credentials are now in ./secure_credentials/ (encrypted)")


def main():
    print("🔐 CYT Configuration & Credential Setup")
    print("=" * 50)

    config_file = 'config.json'
    if not Path(config_file).exists():
        print(f"❌ Error: {config_file} not found")
        print("Run the installer first: sudo ./install.sh")
        sys.exit(1)

    # Load current config
    with open(config_file, 'r') as f:
        config = json.load(f)

    # Initialize credential manager
    cred_manager = SecureCredentialManager()

    # Migrate insecure credentials from config.json if present
    if 'api_keys' in config:
        has_tokens = any(
            'token' in str(value).lower() or 'key' in str(value).lower()
            for value in config['api_keys'].values() if isinstance(value, dict)
        )
        if has_tokens:
            migrate_from_config(cred_manager, config, config_file)

    # --- Review all config settings ---
    print("\nReview configuration settings (press Enter to keep current value):")
    review_config(config, config_file)

    # --- Credential setup ---
    print("\n🔑 API Credentials")
    print("-" * 40)

    existing_token = None
    try:
        existing_token = cred_manager.get_wigle_token()
    except Exception:
        pass

    if existing_token:
        print("  WiGLE API: ✅ configured")
        response = input("  Reconfigure WiGLE credentials? (y/N): ").strip().lower()
        if response == 'y':
            setup_wigle_credentials(cred_manager)
    else:
        print("  WiGLE API: ❌ not configured")
        response = input("  Set up WiGLE API credentials? (y/N): ").strip().lower()
        if response == 'y':
            setup_wigle_credentials(cred_manager)
        else:
            print("  Skipped. CYT works without WiGLE, but SSID geolocation will be unavailable.")

    # --- Summary ---
    print("\n" + "=" * 50)
    print("🔐 Setup Complete!")
    print("\nRun this script again anytime to update settings.")
    print("Start CYT with: ./run.sh")


if __name__ == '__main__':
    main()
