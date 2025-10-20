# Watney Rover
[![](images/teaser_thumbnail.png)](https://www.youtube.com/watch?v=ayU9SmKKkow)
Watney is an open source, Raspberry Pi-enabled telepresence rover made of readily available parts.
Non-electronic parts of Watney are 3D printable.
Watney provides a low-latency HD video feed as well as bi-directional audio with echo cancellation.
Watney uses a charging dock with passthrough charging for continuous operation.

If you've enjoyed this project and want to buy me a beer (no pressure): [![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://paypal.me/nikvivanov)

# Components
Head over to [Bill of Materials](BOM.md) for a list of components you need to purchase to build your own Watney. You'll also need a 3D printer, some PETG / Tough PLA as well as TPU filament. Lastly, you'll need a soldering iron and some wires, though most connections are made using standard breadboard jumper wire.

# UPS Firmware Update
Before you start assembling your Watney, be sure to update the firmware of the UPS power supply. At the time of writing, the latest firmware is *v10* - all previous firmware versions suffered from occasional lockups. You can find [firmware update instructions here.](https://wiki.52pi.com/index.php/EP-0136#Method_2)

# Printing the parts
You can find all 3D printable parts in the [STLs folder](https://github.com/nikivanov/watney/tree/master/STLs). I recommend printing everything but the tires in PETG (I used eSun PETG) or at least Tough PLA. I find regular PLA to be too brittle but YMMV. Print the tires in TPU - Hatchbox TPU worked great for me, but others will almost certainly work just as well.

Print every part with 0.2mm layer height. No supports are needed. The base part includes tearaway lilypads to help with adhesion. Generally, the prints can take a long time but none of them are particularly challenging to print.


# Installation

Watney can be installed in multiple ways depending on your needs:

## Option 1: Pre-built SD Card Image (Recommended for New Builds)
Click on the [Releases](https://github.com/nikivanov/watney/releases) tab and download the [latest Watney SD card image](https://github.com/nikivanov/watney/releases/latest) - it's the large .zip file found under *Assets*. Use [balenaEtcher](https://www.balena.io/etcher/) or similar to write the .img file onto the SD card.

## Option 2: Automated Installation on Existing Pi (New!)
If you already have a Raspberry Pi with Raspberry Pi OS installed, you can use our automated installation script:

```bash
git clone https://github.com/nikivanov/watney.git
cd watney
chmod +x install.sh
sudo ./install.sh
```

The installation takes 45-60 minutes and handles everything automatically. See [INSTALL.md](INSTALL.md) for detailed instructions.

## Option 3: Manual Installation
For advanced users who want complete control, see the [Installation Guide](INSTALL.md) or [Upgrade Guide](UPGRADE_GUIDE.md) for step-by-step manual installation instructions.

# Assembly
You'll be working with Lithium Ion batteries - please be careful not to puncture or short them, as they can become a fire hazard if used improperly. **You assume all responsibility for damages that may be caused by your Watney, whether it's assembled correctly or otherwise.**

After installing the software using one of the methods above, follow the detailed assembly video below!

Wiring diagrams that you see in the video can also be [found here](https://github.com/nikivanov/watney/tree/master/images/wiring).

[![](images/detailed_assembly_thumbnail.png)](https://www.youtube.com/watch?v=wV26r6FtXRw)
 
# Configuration
Upon startup, Watney will detect if it's connected to a Wi-Fi hotspot. If not, it will host its own hotspot "Watney".
Once you connect to the hotspot, you can control it directly by going to https://192.168.4.1:5000, or connect it to a Wi-Fi
hotspot by going to http://192.168.4.1 Once you specify your WiFi credentials, Watney will take some time to reboot. Once you hear the startup sound, you're good to go!

Default SSH credentials for Watney are pi / watney5. Watney's mDNS name is watney.local, so if your OS supports mDNS you can simply access it at https://watney.local:5000

Watney's configuration can be found in ~/watney/rover.conf:
* If you want to use different GPIO pins, you can specify them here
* If you find motors on either side running in reverse (backwards when it's supposed to be rotating forward) simply swap ForwardPin 
and ReversePin
* Restart your Watney for configuration changes to take effect

    ## Off Charger re-docking
    Watney can detect when it is taken off the charger outside of its own movement and can attempt to re-dock by driving forward for one second. In my case, Watney occasionally gets knocked off the charger by my Roomba, so enabling this functionality ensures that Watney is always docked and charging. By default this functionality is disabled: I didn't want Watney to drive off someone's workbench while they are working on it. If you'd like to enable this functionality, set `Enabled=True` in the `OFFCHARGER` section of the config.
# Remote Access
Watney has no authentication / security. If you'd like to set it up for remote access, I recommend using [Zerotier](https://www.zerotier.com/). Adding Watney and your client computer to the same Zerotier network will make it appear as if they are on the same local network.

# Building your own Watney image
`packer-builder-arm` is used to build the Watney image. You can find the image build definition in [watney-image.json](packer/watney-image.json). [This article](https://linuxhit.com/build-a-raspberry-pi-image-packer-packer-builder-arm/#:~:text=Packer%2Dbuilder%2Darm%20is%20a,server%20or%20other%20x86%20hardware.) may help setting up `packer` and `packer-builder-arm` on your linux system.

# Upgrading from an Older Watney Image
If you have an existing Watney installation running on an older image (pre-Bookworm), see the [Upgrade Guide](UPGRADE_GUIDE.md) for detailed instructions on how to upgrade to the latest version with improved compatibility for newer Raspberry Pi models and camera modules.

# Raspberry Pi Compatibility
Watney has been updated to support newer Raspberry Pi models and OS versions:
* **Raspberry Pi 3A+** - Original design target, fully supported
* **Raspberry Pi 3B/3B+** - Fully compatible
* **Raspberry Pi 4B** - Confirmed working by [scifiguy000](https://github.com/scifiguy000) in [this thread](https://github.com/nikivanov/watney/issues/27)
* **Raspberry Pi Zero 2 W** - Should work with the updated image
* **Raspberry Pi 5** - May work but has not been tested yet

The updated image is built on **Raspberry Pi OS Bookworm (2024)** which includes:
* Modern `libcamera` camera system for compatibility with all camera modules (v1, v2, v3)
* Latest security updates and package versions
* Updated boot partition structure (`/boot/firmware`)
* Python 3.11+ support with PEP 668 compliance

# Camera Module Compatibility
Watney now uses the modern `libcamera-vid` system instead of the deprecated `raspivid`, providing full compatibility with all Raspberry Pi camera modules:
* **Camera Module v1** (OV5647) - Fully supported
* **Camera Module v2** (IMX219) - Fully supported
* **Camera Module v3** (IMX708) - Fully supported with the updated image
* **HQ Camera** (IMX477) - Should work but not extensively tested

If using Camera Module v3 with a custom housing, see [camrichmond's modified camera housing](https://github.com/camrichmond/watney_Pi_CameraV3).

**Note for users of older Watney images:** If you're still using a pre-Bookworm image with `raspivid`, you can manually update by changing the command in `video.sh` from `raspivid` to `libcamera-vid` format. See the current `video.sh` file for the exact syntax.

# Troubleshooting
* Watney works best with Chrome. Other browsers may not work well, or at all.
* Feel free to file an issue on GitHub if you have questions!

# Open Source Acknowledgements
The following open source projects were used in development of Watney:
* [Janus WebRTC Server](https://janus.conf.meetecho.com/)
* [GStreamer](https://gstreamer.freedesktop.org/)
* [Raspberry Pi Turnkey](https://github.com/schollz/raspberry-pi-turnkey) 

# Future Improvements
![Watneys](images/watneys.jpg)
There have been numerous hardware iterations of Watney, starting from a humble line-follower built for a hackday work project, to the telepresence rover it is today. I'm not planning on adding new hardware iterations, as the latest version accomplishes everything I've envisioned for this project. That being said, there are still some software improvements to be made:
* **Mobile-optimized control.** You'll be able to control your watney from your phone / tablet, especially in tandem with Remote Access.
* **Better browser compatibility.** There's no reason it can't work in all major browsers.
