# Watney Quick Reference Card

## Installation

```bash
# Clone and install
git clone https://github.com/nikivanov/watney.git
cd watney
chmod +x install.sh
sudo ./install.sh
```

## Access

- **Web Interface**: https://watney.local:5000
- **WiFi Setup**: http://192.168.4.1 (when in hotspot mode)
- **SSH**: `ssh pi@watney.local` (password: watney5)

## Service Management

```bash
# Check status
sudo systemctl status watney
sudo systemctl status pigpiod

# Start/Stop/Restart
sudo systemctl start watney
sudo systemctl stop watney
sudo systemctl restart watney

# View logs
sudo journalctl -u watney -f
sudo journalctl -u watney -n 100
```

## Configuration

```bash
# Edit main config
nano ~/watney/rover.conf

# Restart after changes
sudo systemctl restart watney
```

## Keyboard Controls (Web Interface)

- **Arrow Keys**: Movement (↑↓←→)
- **A/Z**: Camera tilt up/down
- **Shift**: Slow mode
- **L**: Toggle lights
- **S**: Text-to-speech
- **V**: Push-to-talk
- **+/-**: Volume control

## Troubleshooting

```bash
# Test camera
libcamera-hello --list-cameras

# Check camera stream
cat ~/watney/video.log

# Check GPIO access
sudo pigpiod
pigs t

# View installation log
cat /tmp/watney-install.log

# Check WiFi status
ip addr show wlan0
iwconfig

# Unblock WiFi
sudo rfkill unblock wifi
```

## File Locations

- **Watney Code**: `/home/pi/watney/`
- **Configuration**: `/home/pi/watney/rover.conf`
- **Janus**: `/opt/janus/`
- **Service File**: `/etc/systemd/system/watney.service`
- **Boot Config**: `/boot/firmware/config.txt` (or `/boot/config.txt`)
- **SSL Certificates**: `/home/pi/cert.pem`, `/home/pi/key.pem`

## Common Issues

### No Video
```bash
ps aux | grep janus
ls -la ~/watney/video.sh
sudo systemctl restart watney
```

### Motors Not Responding
```bash
sudo systemctl status pigpiod
sudo systemctl restart pigpiod
```

### WiFi Hotspot Issues
```bash
sudo systemctl status hostapd
sudo systemctl restart hostapd
rfkill list
```

### Camera Not Detected
```bash
libcamera-hello --list-cameras
vcgencmd get_camera
```

## System Info

```bash
# OS version
cat /etc/os-release

# Pi model
cat /proc/device-tree/model

# Disk space
df -h

# Memory usage
free -h

# CPU temperature
vcgencmd measure_temp
```

## Updates

```bash
# Update OS packages
sudo apt update
sudo apt upgrade

# Update Watney code
cd ~/watney
git pull origin master
sudo systemctl restart watney
```

## Network Configuration

```bash
# Check connection
ping -c 4 8.8.8.8

# View WiFi networks
sudo iwlist wlan0 scan | grep ESSID

# Restart networking
sudo systemctl restart dhcpcd
```

## Backup Configuration

```bash
# Backup config
cp ~/watney/rover.conf ~/rover.conf.backup

# Backup entire installation
sudo tar -czf ~/watney-backup.tar.gz /home/pi/watney
```

## Performance Monitoring

```bash
# CPU usage
top
htop  # if installed

# Service resource usage
sudo systemctl status watney

# Network stats
iftop  # if installed
```

## GPIO Pin Reference (Default)

From `rover.conf`:
- **Enable**: GPIO 13
- **Left Motor**: Forward=25, Reverse=24
- **Right Motor**: Forward=17, Reverse=27
- **Servo**: PWM=5

## Links

- **Documentation**: [INSTALL.md](INSTALL.md), [README.md](README.md)
- **Upgrade Guide**: [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md)
- **Issues**: https://github.com/nikivanov/watney/issues
- **Bill of Materials**: [BOM.md](BOM.md)
