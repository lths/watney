# Watney Upgrade Guide

This guide helps existing Watney users upgrade to the newer Raspberry Pi OS Bookworm-based image with improved compatibility for newer Raspberry Pi models and camera modules.

## What's New

The updated Watney image includes:
- **Raspberry Pi OS Bookworm (2024)** - Latest stable OS with modern packages
- **libcamera support** - Compatible with all camera modules including v3
- **Improved Pi compatibility** - Works with Pi 3A+, 3B/3B+, 4B, Zero 2 W
- **Latest security updates** - Up-to-date packages and security patches
- **Python 3.11+** - Modern Python with PEP 668 compliance

## Upgrade Options

### Option 1: Fresh Image Installation (Recommended)

The cleanest upgrade path is to build and flash a new image:

1. **Backup your configuration**
   ```bash
   # SSH into your current Watney
   ssh pi@watney.local
   
   # Backup your rover.conf if you've customized it
   cp ~/watney/rover.conf ~/rover.conf.backup
   ```

2. **Build the new image** using the updated `packer/watney-image.json` configuration, or download from the [Releases page](https://github.com/nikivanov/watney/releases) when available

3. **Flash the new image** to your SD card using [balenaEtcher](https://www.balena.io/etcher/)

4. **Restore your configuration** by copying your backed-up `rover.conf` settings to the new installation

### Option 2: Manual Update (Advanced Users)

If you prefer to update your existing installation, follow these steps carefully:

1. **Update the OS to Bookworm**
   ```bash
   sudo apt update
   sudo apt full-upgrade
   sudo apt install raspi-config
   sudo raspi-config
   # Use raspi-config to upgrade to Bookworm if not already on it
   sudo reboot
   ```

2. **Install libcamera-apps**
   ```bash
   sudo apt install libcamera-apps
   ```

3. **Update video.sh**
   ```bash
   cd ~/watney
   nano video.sh
   ```
   
   Replace the content with:
   ```bash
   libcamera-vid -n -t 0 --width 1280 --height 720 --framerate 25 --bitrate 2500000 --inline --profile baseline --intra 25 --codec h264 --flush -o - | gst-launch-1.0 fdsrc do-timestamp=true ! h264parse ! rtph264pay config-interval=1 pt=96 ! udpsink host=127.0.0.1 port=8004
   ```

4. **Update Python packages** (if needed)
   ```bash
   pip3 install --break-system-packages --upgrade aiohttp apa102-pi psutil pyalsaaudio smbus
   ```

5. **Reboot and test**
   ```bash
   sudo reboot
   ```

## Verification Steps

After upgrading, verify everything works:

1. **Check camera feed**
   - Connect to https://watney.local:5000
   - Verify video stream is working

2. **Test motor control**
   - Use the web interface to drive forward/backward
   - Test turning left/right
   - Verify servo camera tilt works

3. **Check audio**
   - Test microphone input
   - Verify speaker output
   - Ensure TTS greeting plays on startup

4. **Verify charging**
   - Test docking station charging
   - Check battery status display

## Troubleshooting

### Video stream not working
- Ensure camera is properly connected
- Check camera is enabled: `libcamera-hello` should show preview
- Verify GStreamer is installed: `gst-launch-1.0 --version`
- Check Janus logs: `journalctl -u watney -f`

### Motors not responding
- Verify pigpiod is running: `sudo systemctl status pigpiod`
- Check GPIO pin assignments in `~/watney/rover.conf`
- Test GPIO access: `sudo pigpiod` and `pigs t`

### Camera module v3 specific issues
- Ensure you're using libcamera-vid (not raspivid)
- Try different camera parameters if needed
- Consider using modified camera housing from [camrichmond](https://github.com/camrichmond/watney_Pi_CameraV3)

### Boot partition issues (Bookworm)
- Boot config is now at `/boot/firmware/config.txt` (not `/boot/config.txt`)
- SSH enable file goes in `/boot/firmware/ssh` (not `/boot/ssh`)

## Compatibility Notes

### Working Configurations
- ✅ Pi 3A+ with Camera v1/v2/v3
- ✅ Pi 3B/3B+ with Camera v1/v2/v3
- ✅ Pi 4B with Camera v1/v2/v3
- ✅ Pi Zero 2 W (should work, untested)

### Known Issues
- Pi 5 support is untested
- Some third-party camera modules may require additional configuration

## Getting Help

If you encounter issues:
1. Check the [GitHub Issues](https://github.com/nikivanov/watney/issues)
2. Review existing issue threads for similar problems
3. File a new issue with:
   - Raspberry Pi model
   - Camera module version
   - OS version: `cat /etc/os-release`
   - Error logs: `journalctl -u watney -n 100`

## Rollback

If the upgrade causes problems, you can always flash your old image backup or revert to a previous release from the [Releases page](https://github.com/nikivanov/watney/releases).
