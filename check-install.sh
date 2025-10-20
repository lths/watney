#!/bin/bash
#
# Watney Installation Diagnostic Script
# Run this to check your system before installation
#

echo "=================================="
echo "Watney Installation Diagnostics"
echo "=================================="
echo ""

echo "1. Current User:"
whoami
echo ""

echo "2. Current Directory:"
pwd
echo ""

echo "3. Directory Permissions:"
ls -la install.sh 2>/dev/null || echo "install.sh not found in current directory"
echo ""

echo "4. Checking if running as root:"
if [ "$EUID" -eq 0 ]; then
    echo "✓ Running as root"
else
    echo "✗ NOT running as root (EUID: $EUID)"
fi
echo ""

echo "5. Raspberry Pi Check:"
if grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "✓ Running on Raspberry Pi"
    cat /proc/device-tree/model 2>/dev/null || echo "Model: Unknown"
else
    echo "✗ NOT running on Raspberry Pi"
fi
echo ""

echo "6. OS Version:"
cat /etc/os-release | grep PRETTY_NAME
echo ""

echo "7. Available Disk Space:"
df -h / | tail -1
echo ""

echo "8. Checking required commands:"
for cmd in git apt-get systemctl raspi-config; do
    if command -v $cmd &> /dev/null; then
        echo "✓ $cmd found"
    else
        echo "✗ $cmd NOT found"
    fi
done
echo ""

echo "9. Checking write permissions:"
touch /tmp/watney-test-write 2>/dev/null && rm /tmp/watney-test-write && echo "✓ Can write to /tmp" || echo "✗ Cannot write to /tmp"
touch /home/pi/watney-test-write 2>/dev/null && rm /home/pi/watney-test-write && echo "✓ Can write to /home/pi" || echo "✗ Cannot write to /home/pi"
echo ""

echo "10. Checking if script directory is accessible:"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Script directory: $SCRIPT_DIR"
if [ -r "$SCRIPT_DIR/install.sh" ]; then
    echo "✓ install.sh is readable"
else
    echo "✗ install.sh is NOT readable"
fi
echo ""

echo "=================================="
echo "If you see any ✗ marks above, those are likely the cause of your issues."
echo ""
echo "To run the installation, try:"
echo "  cd $SCRIPT_DIR"
echo "  sudo bash install.sh"
echo "=================================="
