# Installation Troubleshooting Guide

This guide helps resolve common issues when installing Watney.

## Quick Diagnostics

First, run the diagnostic script to identify issues:

```bash
cd watney
bash check-install.sh
```

Then run with sudo to see if permissions are the issue:

```bash
sudo bash check-install.sh
```

## Common Permission Errors

### Error: "Permission denied" when running install.sh

**Solutions to try (in order):**

#### 1. Use bash directly (most common fix)
```bash
sudo bash install.sh
```

#### 2. Check if you're in the right directory
```bash
pwd  # Should show /home/pi/watney or wherever you cloned
ls -la install.sh  # Should see the file
```

#### 3. Copy the script to /tmp and run from there
```bash
sudo cp install.sh /tmp/
cd /tmp
sudo bash install.sh
```

#### 4. Run commands inline instead
```bash
sudo bash -c 'bash install.sh'
```

#### 5. Check if filesystem is mounted read-only
```bash
mount | grep ' / '
# If you see 'ro' (read-only), remount as read-write:
sudo mount -o remount,rw /
```

### Error: "command not found" during installation

This usually means a required package isn't installed.

**Solution:**
```bash
sudo apt-get update
sudo apt-get install -y git bash
sudo bash install.sh
```

### Error: "Cannot create directory" or "No space left on device"

**Check disk space:**
```bash
df -h
```

**If low on space, clean up:**
```bash
sudo apt-get clean
sudo apt-get autoremove
sudo rm -rf /var/cache/apt/archives/*
```

### Error: SSH connection drops during installation

The installation takes 45-60 minutes. If your SSH session times out:

#### Option 1: Use screen or tmux (recommended)
```bash
# Install screen
sudo apt-get install screen

# Start screen session
screen -S watney-install

# Run installation
cd watney
sudo bash install.sh

# If disconnected, reconnect and resume:
ssh pi@watney.local
screen -r watney-install
```

#### Option 2: Run in background with nohup
```bash
cd watney
sudo nohup bash install.sh > /tmp/watney-install-output.log 2>&1 &

# Check progress
tail -f /tmp/watney-install-output.log

# Check if still running
ps aux | grep install.sh
```

#### Option 3: Keep SSH alive
Add to your local `~/.ssh/config`:
```
Host watney.local
    ServerAliveInterval 60
    ServerAliveCountMax 10
```

## Specific Error Messages

### "bash: ./install.sh: /bin/bash: bad interpreter: Permission denied"

The filesystem might be mounted with `noexec`.

**Check:**
```bash
mount | grep noexec
```

**Fix:**
```bash
# Remount without noexec
sudo mount -o remount,exec /
# Or run from /tmp which usually allows execution
sudo cp install.sh /tmp/ && cd /tmp && sudo bash install.sh
```

### "apt-get: command not found"

You're not on a Debian-based system or it's not in PATH.

**Fix:**
```bash
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:$PATH
sudo apt-get update
```

### "fatal: could not create work tree dir"

Git clone failing due to permissions.

**Fix:**
```bash
# Clone to a directory you have permissions for
cd ~
git clone https://github.com/nikivanov/watney.git
cd watney
sudo bash install.sh
```

### "E: Unable to locate package"

Package not available in your repositories.

**Fix:**
```bash
# Update package lists
sudo apt-get update

# If still fails, you might need to enable additional repos
sudo raspi-config
# Select: Advanced Options > Expand Filesystem
# Reboot and try again
```

## Still Having Issues?

### 1. Share Complete Error Output

Please provide:

```bash
# Run these and share the output:
bash check-install.sh > ~/diagnostic-output.txt 2>&1
sudo bash check-install.sh >> ~/diagnostic-output.txt 2>&1

# Try installation and capture full output:
cd watney
sudo bash install.sh 2>&1 | tee ~/install-error.txt

# Share these files:
cat ~/diagnostic-output.txt
cat ~/install-error.txt
cat /tmp/watney-install.log
```

### 2. Manual Installation

If the automated script continues to fail, try manual installation following the [Upgrade Guide](UPGRADE_GUIDE.md).

### 3. Pre-built Image

Download a pre-built image from [Releases](https://github.com/nikivanov/watney/releases) and flash it to your SD card.

## System-Specific Issues

### Raspberry Pi Zero/Zero W

The installation may take longer (2-3 hours) due to slower CPU.

```bash
# Consider reducing compilation jobs
export MAKEFLAGS="-j1"
sudo bash install.sh
```

### Custom OS Installation

If you're not using Raspberry Pi OS:

```bash
# You may need to manually install dependencies
sudo apt-get install raspberrypi-kernel-headers
```

### SSH Over WiFi Issues

If installation fails when WiFi drops:

1. Connect via ethernet cable
2. Or use screen/tmux as shown above
3. Or run installation locally with keyboard/monitor

## Getting More Help

When reporting issues on GitHub, include:

1. Output from `bash check-install.sh`
2. Output from `sudo bash check-install.sh`
3. Your Pi model: `cat /proc/device-tree/model`
4. OS version: `cat /etc/os-release`
5. The exact error message you're seeing
6. Contents of `/tmp/watney-install.log`

Create an issue at: https://github.com/nikivanov/watney/issues
