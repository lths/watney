# Watney Bookworm Update - Changelog

This document summarizes the changes made to update Watney for Raspberry Pi OS Bookworm and newer Raspberry Pi models.

## Date: October 18, 2025

## Summary
Updated Watney to support Raspberry Pi OS Bookworm (2024) with modern `libcamera` camera system, providing compatibility with newer Raspberry Pi models (3A+, 3B/3B+, 4B, Zero 2 W) and all camera modules (v1, v2, v3).

## Files Modified

### 1. `packer/watney-image.json`
**Purpose**: Updated base OS image and package installations

**Changes**:
- Updated base OS from Raspberry Pi OS Buster (2021-05-07) to Bookworm (2024-07-04)
- Changed download URL to use newer Bookworm image
- Changed file extension from `.zip` to `.xz` (new compression format)
- Removed deprecated `raspi-config nonint do_camera 0` command
- Updated boot partition paths:
  - `/boot/config.txt` → `/boot/firmware/config.txt`
  - `/boot/ssh` → `/boot/firmware/ssh`
- Added `libcamera-apps` package for camera support
- Added `python3-venv` for Python virtual environment support
- Changed `python-smbus` to `python3-smbus` (Python 2 removed in Bookworm)
- Added `--break-system-packages` flag to pip3 install (PEP 668 compliance)

### 2. `video.sh`
**Purpose**: Replaced deprecated camera command with modern alternative

**Changes**:
- Replaced `raspivid` with `libcamera-vid`
- Updated command parameters to use libcamera-vid syntax:
  - `-w 1280 -h 720` → `--width 1280 --height 720`
  - `--framerate 25` (syntax remains similar)
  - `--bitrate 2500000` (syntax remains similar)
  - `-ih` → `--inline`
  - Added `--codec h264` (explicit codec specification)
  - Changed output redirection syntax slightly

### 3. `README.md`
**Purpose**: Updated documentation with new compatibility information

**Changes**:
- Expanded "Raspberry Pi Compatibility" section with:
  - Explicit support list for Pi 3A+, 3B/3B+, 4B, Zero 2 W, 5
  - Description of Bookworm updates
  - Modern libcamera system benefits
- Completely rewrote "Camera Module Compatibility" section:
  - Listed all supported camera modules (v1, v2, v3, HQ)
  - Added migration notes for existing users
  - Referenced camrichmond's modified housing
- Added new "Upgrading from an Older Watney Image" section
  - Links to UPGRADE_GUIDE.md

### 4. `UPGRADE_GUIDE.md` (New File)
**Purpose**: Help existing users migrate to the new version

**Content**:
- What's new in the Bookworm update
- Two upgrade paths:
  - Option 1: Fresh installation (recommended)
  - Option 2: Manual in-place upgrade
- Verification steps after upgrade
- Troubleshooting section for common issues
- Compatibility matrix
- Rollback instructions

### 5. `CHANGELOG_BOOKWORM.md` (New File - This Document)
**Purpose**: Document all changes made in this update

## Technical Details

### Boot Partition Changes
Raspberry Pi OS Bookworm moved the boot partition mount point:
- Old: `/boot`
- New: `/boot/firmware`

This affects:
- Configuration files (`config.txt`)
- SSH enablement (`ssh` file)
- Firmware files

### Python Package Management (PEP 668)
Python 3.11+ in Bookworm enforces PEP 668, which prevents installing packages globally with pip to avoid conflicts with system packages. Solutions:
- Use `--break-system-packages` flag (used in our image build)
- Use virtual environments
- Use system packages when available

### Camera System Migration
| Old System (Buster) | New System (Bookworm) |
|---------------------|------------------------|
| `raspivid` | `libcamera-vid` |
| Hardware-specific commands | Unified libcamera interface |
| Limited to older cameras | Supports all camera modules |
| Deprecated | Actively maintained |

### Package Changes
- `python-smbus` removed (Python 2 only) → use `python3-smbus`
- `raspi-config` camera enable command deprecated
- `libcamera-apps` now required for camera functionality

## Testing Recommendations

Before deploying to a Watney in production:

1. **Build and test the new image** on a spare SD card
2. **Verify camera functionality** with your specific camera module
3. **Test all motor controls** (forward, backward, turning)
4. **Verify audio** (microphone, speaker, TTS)
5. **Test charging dock** functionality
6. **Check web interface** in your preferred browser
7. **Verify WiFi hotspot** mode if used

## Known Limitations

- Raspberry Pi 5 is untested
- Some third-party camera modules may need additional configuration
- Older Watney images cannot be automatically upgraded - manual steps required

## Future Work

Potential areas for future enhancement:
- Test and document Pi 5 compatibility
- Add automated testing for different Pi models
- Create automated backup/restore scripts
- Add support for newer camera features (e.g., HDR, autofocus on v3)

## Credits

- Original Watney project by Nik Ivanov
- Community contributions from scifiguy000, camrichmond, and others
- This update prepared by the Watney community to modernize the platform for current and future Raspberry Pi hardware
