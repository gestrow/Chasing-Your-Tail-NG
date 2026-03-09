# Chasing Your Tail (CYT)

A comprehensive Wi-Fi probe request analyzer that monitors and tracks wireless devices by analyzing their probe requests. The system integrates with Kismet for packet capture and WiGLE API for SSID geolocation analysis, featuring advanced surveillance detection capabilities.

## Requirements

- Linux-based system (Debian, Ubuntu, Kali, NetHunter)
- Python 3.6+
- **Dedicated Wi-Fi adapter supporting monitor mode** (e.g. Alfa AWUS036ACH)
- Kismet wireless packet capture (installed automatically)
- WiGLE API key (optional, for SSID geolocation)

**Important:** You need a **separate** USB Wi-Fi adapter for monitoring. Kismet puts the adapter into monitor mode, which disables normal connectivity. Do NOT use your primary Wi-Fi adapter — you will lose internet access.

## Installation

### Step 1: Clone the repository

**Use `git clone`** — do not download the ZIP from GitHub (path resolution may fail).

```bash
sudo apt-get install -y git
git clone -b dev https://github.com/gestrow/Chasing-Your-Tail-NG.git
cd Chasing-Your-Tail-NG
```

### Step 2: Run the installer

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer will walk you through:

1. **System dependencies** — Python, wireless-tools, Kismet (adds official repo if needed)
2. **Python packages** — requests, cryptography (installed in a virtual environment)
3. **Configuration** — generates `config.json` with your settings
4. **Auto-start services** (optional) — systemd units for Kismet and GUI

#### Installer prompts explained

| Prompt | Recommendation |
|--------|---------------|
| **Installation location** | In-place (current directory) is fine |
| **Kismet database path** | Press Enter for default (`~/kismet_logs/*.kismet`) |
| **Wi-Fi interface** | Enter your **dedicated monitoring adapter** (e.g. `wlan1`), NOT your primary Wi-Fi |
| **Geographic search bounds** | Defaults to CONUS (continental US). Press Enter to accept, or enter custom coordinates |
| **Auto-start services** | Say **NO** unless you have a dedicated adapter plugged in permanently |
| **WiGLE credentials** | Say NO here — set up separately in Step 3 |

#### Unattended install

```bash
sudo ./install.sh --unattended              # Interactive defaults
sudo ./install.sh --unattended --no-gui     # Headless server
sudo ./install.sh --help                    # All options
```

### Step 3: Set up WiGLE API credentials (optional)

WiGLE integration enables SSID geolocation lookups. Skip this if you don't have a WiGLE account.

1. Get your API credentials from https://wigle.net/account (under "API Token")
2. Run the credential migration tool:

```bash
cd Chasing-Your-Tail-NG
python3 migrate_credentials.py
```

Credentials are encrypted and stored in `./secure_credentials/encrypted_credentials.json`.

### Step 4: Verify installation

```bash
python3 chasing_your_tail.py
# Should show: "SECURE MODE: All SQL injection vulnerabilities have been eliminated!"
```

## Usage

### Quick Start

```bash
./run.sh              # Start Kismet + GUI (auto-detects display)
./run.sh --cli        # Start Kismet + CLI monitoring (no GUI)
./run.sh --gui-only   # GUI only (Kismet already running)
./run.sh --stop       # Stop all CYT processes
./run.sh --status     # Check what's running
```

### GUI Interface

```bash
python3 cyt_gui.py
```

- **Surveillance Analysis** button — GPS-correlated persistence detection with KML visualization
- **Analyze Logs** button — Historical probe request analysis
- Real-time status monitoring and file generation notifications

### Command Line Monitoring

```bash
python3 chasing_your_tail.py       # Core monitoring
./start_kismet_clean.sh            # Start Kismet standalone
```

### Data Analysis

```bash
python3 probe_analyzer.py              # Past 14 days, local only (default)
python3 probe_analyzer.py --days 7     # Past 7 days only
python3 probe_analyzer.py --all-logs   # All logs (may be slow)
python3 probe_analyzer.py --wigle      # With WiGLE API (uses credits)
```

### Surveillance Detection

```bash
python3 surveillance_analyzer.py                                    # Auto GPS from Kismet
python3 surveillance_analyzer.py --demo                             # Demo mode (Phoenix coords)
python3 surveillance_analyzer.py --kismet-db /path/to/kismet.db     # Specific database
python3 surveillance_analyzer.py --stalking-only --min-persistence 0.8  # High-persistence only
python3 surveillance_analyzer.py --output-json results.json         # Export to JSON
python3 surveillance_analyzer.py --gps-file gps_coordinates.json    # External GPS data
```

## Stopping & Uninstalling

### Stop CYT

```bash
./run.sh --stop                    # Stop CYT processes (leaves Kismet running)
sudo pkill kismet                  # Stop Kismet too
```

### Restore your Wi-Fi adapter

If Kismet grabbed your adapter and you lost connectivity:

```bash
sudo pkill -9 kismet
sudo ip link set <interface> down
sudo iw <interface> set type managed
sudo ip link set <interface> up
sudo systemctl restart NetworkManager
```

If that doesn't work, reboot.

### Uninstall

```bash
# Remove systemd services (if installed)
sudo systemctl stop cyt-kismet cyt-gui 2>/dev/null
sudo systemctl disable cyt-kismet cyt-gui 2>/dev/null
sudo rm /etc/systemd/system/cyt-kismet.service /etc/systemd/system/cyt-gui.service 2>/dev/null
sudo systemctl daemon-reload

# Delete the directory
rm -rf /path/to/Chasing-Your-Tail-NG
```

System packages (Kismet, Python, etc.) are left in place.

## Configuration

All settings are in `config.json` (generated by the installer):

```json
{
  "paths": {
    "base_dir": ".",
    "log_dir": "logs",
    "kismet_logs": "~/kismet_logs/*.kismet",
    "ignore_lists": { "mac": "mac_list.json", "ssid": "ssid_list.json" }
  },
  "timing": {
    "check_interval": 60,
    "time_windows": { "recent": 5, "medium": 10, "old": 15, "oldest": 20 }
  },
  "search": {
    "lat_min": 24.5, "lat_max": 49.0,
    "lon_min": -125.0, "lon_max": -66.9
  },
  "wifi_interface": "wlan1"
}
```

To reconfigure, edit `config.json` directly or re-run `sudo ./install.sh`.

## Features

- **Real-time Wi-Fi monitoring** with Kismet integration
- **Advanced surveillance detection** with persistence scoring (0-1.0)
- **Automatic GPS integration** from Kismet (Bluetooth GPS support)
- **Location clustering** with 100m threshold
- **KML visualization** for Google Earth with color-coded threat levels
- **Multi-format reporting** — Markdown, HTML (with pandoc), KML
- **Time-window tracking** (5, 10, 15, 20 minute sliding windows)
- **WiGLE API integration** for SSID geolocation
- **Multi-location tracking** for detecting following behavior
- **GUI and CLI interfaces**
- **Security-hardened** — parameterized SQL, encrypted credentials, input validation

## Core Components

| File | Purpose |
|------|---------|
| `chasing_your_tail.py` | Core monitoring engine — queries Kismet SQLite in real-time |
| `cyt_gui.py` | Tkinter GUI with surveillance analysis |
| `surveillance_analyzer.py` | GPS surveillance detection with KML visualization |
| `surveillance_detector.py` | Persistence detection engine |
| `gps_tracker.py` | GPS tracking with location clustering and KML generation |
| `probe_analyzer.py` | Post-processing with WiGLE integration |
| `run.sh` | All-in-one launcher |
| `install.sh` | Universal installer |
| `start_kismet_clean.sh` | Standalone Kismet startup |

### Security modules

| File | Purpose |
|------|---------|
| `secure_database.py` | SQL injection prevention |
| `secure_credentials.py` | Encrypted credential management |
| `secure_ignore_loader.py` | Safe ignore list loading |
| `secure_main_logic.py` | Secure monitoring logic |
| `input_validation.py` | Input sanitization |
| `migrate_credentials.py` | Credential migration tool |

## Output Files

| Directory | Contents |
|-----------|----------|
| `./surveillance_reports/` | Markdown and HTML reports |
| `./kml_files/` | Google Earth KML visualizations |
| `./logs/` | CYT monitoring logs |
| `./analysis_logs/` | Surveillance analysis logs |
| `./reports/` | Probe analysis reports |
| `./ignore_lists/` | MAC and SSID ignore lists (JSON) |
| `./secure_credentials/` | Encrypted API credentials |

## Technical Architecture

### Time Window System

Four overlapping sliding windows detect device persistence:
- **Recent**: Past 5 minutes
- **Medium**: 5-10 minutes ago
- **Old**: 10-15 minutes ago
- **Oldest**: 15-20 minutes ago

Lists rotate every 5 cycles (5 minutes) from fresh database queries.

### Surveillance Detection

- **Temporal Persistence** — consistent device appearances over time
- **Location Correlation** — devices following across multiple locations
- **Probe Pattern Analysis** — suspicious SSID probe requests
- **Timing Analysis** — unusual appearance patterns (work hours, intervals)
- **Persistence Scoring** — weighted scores (0-1.0) from combined indicators
- **Multi-location Tracking** — detects following behavior across locations

### GPS & KML Visualization

- Automatic GPS extraction from Kismet database (Bluetooth GPS)
- Location clustering with configurable threshold
- Device-to-location correlation with precise timing
- Professional KML output: color-coded markers, tracking paths, heatmaps, interactive balloons

## Security

- **Parameterized SQL queries** prevent injection attacks
- **Encrypted credential storage** protects API keys
- **Input validation** prevents malicious input
- **Audit logging** tracks security events (`cyt_security.log`)
- **Safe ignore list loading** eliminates code execution risks

## Author

@matt0177

## License

MIT License

## Disclaimer

This tool is intended for legitimate security research, network administration, and personal safety purposes. Users are responsible for complying with all applicable laws and regulations in their jurisdiction.
