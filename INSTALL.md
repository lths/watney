# Watney Installation Guide

This guide provides instructions for installing Watney on an existing Raspberry Pi system.

## Quick Start

For the fastest installation, use the automated installation script:

```bash
# Clone the repository
git clone https://github.com/nikivanov/watney.git
cd watney

# Make the script executable
chmod +x install.sh

# Run the installation (requires root)
sudo ./install.sh
```

The installation takes approximately 45-60 minutes and will:
- Install all system dependencies
- Build Janus WebRTC Server (~30 minutes)
- Build Mimic TTS (~15 minutes)
- Configure system settings
- Set up WiFi hotspot capability

## Prerequisites

### Hardware Requirements
- **Raspberry Pi**: 3A+, 3B/3B+, 4B, or Zero 2 W
- **Camera Module**: v1, v2, v3, or HQ Camera
- **SD Card**: Minimum 8GB (16GB+ recommended)
- **Free Disk Space**: At least 3GB for installation

### Software Requirements
- **Operating System**: Raspberry Pi OS Bookworm or Bullseye (Lite or Desktop)
- **SSH Access**: Enabled for remote installation
- **Internet Connection**: Required for downloading packages

## Installation Methods

### Method 1: Automated Installation (Recommended)

The `install.sh` script handles everything automatically:

```bash
sudo ./install.sh
```

**What it does:**
1. Verifies system compatibility
2. Installs system dependencies
3. Builds and installs Janus WebRTC Server
4. Builds and installs Mimic TTS
5. Installs Watney Python software
6. Configures system settings (GPIO, boot, audio)
7. Sets up systemd services
8. Configures WiFi hotspot (Turnkey)

**During installation:**
- Progress is logged to `/tmp/watney-install.log`
- You'll be prompted to confirm before starting
- The script can be safely re-run if interrupted

### Method 2: Manual Installation

For advanced users who want more control, see the [Upgrade Guide](UPGRADE_GUIDE.md) which details the manual installation steps.

### Method 3: Pre-built Image

Download a pre-built SD card image from the [Releases page](https://github.com/nikivanov/watney/releases) and flash it using [balenaEtcher](https://www.balena.io/etcher/).

## Installation Steps Explained

### 1. Pre-flight Checks
The script verifies:
- Running on a Raspberry Pi
- OS version compatibility (Bookworm/Bullseye)
- Sufficient disk space (3GB+)
- Camera module presence (warning if not found)

### 2. System Dependencies
Installs required packages:
- Python 3 and pip
- GPIO libraries (pigpio, RPi.GPIO)
- Camera system (libcamera-apps)
- GStreamer for video streaming
- Network tools (dnsmasq, hostapd)

### 3. Janus WebRTC Server
Builds from source:
- Clones specific commit for stability
- Compiles with optimized settings
- Installs to `/opt/janus`
- Takes ~30 minutes on Pi 3/4

### 4. Mimic TTS
Builds text-to-speech engine:
- Clones MycroftAI/mimic
- Compiles from specific commit
- Installs system-wide
- Takes ~15 minutes

### 5. Watney Software
Installs Watney components:
- Python dependencies via pip
- Copies files to `/home/pi/watney`
- Sets up SSL certificates
- Configures Janus settings

### 6. System Configuration
Configures:
- Boot settings (`/boot/firmware/config.txt`)
- GPIO pin modes
- Audio system (disables default, enables I2S)
- Camera LED disable
- SPI and I2C interfaces

### 7. Systemd Services
Creates services for:
- Watney main application
- WiFi configuration (Turnkey)
- Hostapd (WiFi hotspot)

## Post-Installation

### 1. Verify Installation
```bash
# Check if services are enabled
sudo systemctl status watney
sudo systemctl status pigpiod

# View installation log
cat /tmp/watney-install.log
```

### 2. Configure Watney
Edit the configuration file:
```bash
nano /home/pi/watney/rover.conf
```

Key settings:
- Motor GPIO pins
- Servo settings
- Speed adjustments
- Volume levels

### 3. Reboot
```bash
sudo reboot
```

### 4. Access Web Interface
After reboot:
- **If connected to WiFi**: https://watney.local:5000
- **If in hotspot mode**: 
  - Connect to "Watney" WiFi network
  - Navigate to https://192.168.4.1:5000

### 5. Configure WiFi (if needed)
If Watney starts in hotspot mode:
- Connect to "Watney" network
- Visit http://192.168.4.1
- Enter your WiFi credentials
- Watney will reboot and connect

## Troubleshooting

### Installation Fails

**Check the log:**
```bash
tail -f /tmp/watney-install.log
```

**Common issues:**
- Insufficient disk space: Free up space and retry
- Network timeout: Check internet connection
- Build failures: Ensure OS is up to date: `sudo apt update && sudo apt upgrade`

### Camera Not Working

```bash
# Test camera
libcamera-hello --list-cameras

# If using older OS, you may need to enable legacy camera
sudo raspi-config
# Navigate to Interface Options > Legacy Camera
```

### Services Not Starting

```bash
# Check service status
sudo systemctl status watney
sudo journalctl -u watney -n 50

# Restart services
sudo systemctl restart watney
```

### No Video Stream

1. Check camera connection
2. Verify Janus is running: `ps aux | grep janus`
3. Check video.sh permissions: `ls -la /home/pi/watney/video.sh`
4. View video logs: `cat /home/pi/watney/video.log`

### WiFi Hotspot Not Working

```bash
# Check hostapd status
sudo systemctl status hostapd

# View hostapd logs
sudo journalctl -u hostapd -n 50

# Verify WiFi is not blocked
rfkill list
sudo rfkill unblock wifi
```

## Uninstallation

To remove Watney:

```bash
# Stop and disable services
sudo systemctl stop watney
sudo systemctl disable watney
sudo systemctl stop turnkey
sudo systemctl disable turnkey

# Remove files
sudo rm -rf /home/pi/watney
sudo rm -rf /home/pi/raspberry-pi-turnkey
sudo rm -rf /opt/janus
sudo rm /etc/systemd/system/watney.service
sudo rm /etc/systemd/system/turnkey.service

# Remove packages (optional)
sudo apt remove libcamera-apps janus-gateway

# Reload systemd
sudo systemctl daemon-reload
```

## Advanced Options

### Skip Components

You can modify `install.sh` to skip certain components by commenting out functions in the `main()` section.

### Custom Installation Directory

By default, Watney installs to `/home/pi/watney`. To change this, modify the `watney_dir` variable in the `install_watney_software()` function.

### Development Installation

For development, you may want to run Watney without systemd:

```bash
cd /home/pi/watney
python3 server.py
```

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/nikivanov/watney/issues)
- **Discussions**: Check existing issue threads
- **Documentation**: [Main README](README.md), [Upgrade Guide](UPGRADE_GUIDE.md)

When reporting issues, include:
- Raspberry Pi model
- OS version: `cat /etc/os-release`
- Installation log: `/tmp/watney-install.log`
- Service logs: `sudo journalctl -u watney -n 100`
