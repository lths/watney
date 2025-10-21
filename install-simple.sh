#!/bin/bash
#
# Watney Telepresence Rover - Installation Script (Simple Version)
# This script installs Watney on an existing Raspberry Pi system
#
# Usage: sudo bash install-simple.sh
#

set -e  # Exit on any error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to use /tmp, fall back to home directory if permission denied
if touch /tmp/watney-install.log 2>/dev/null; then
    INSTALL_LOG="/tmp/watney-install.log"
else
    INSTALL_LOG="$HOME/watney-install.log"
fi

# Functions
log_info() {
    echo "[INFO] $1" | tee -a "$INSTALL_LOG"
}

log_success() {
    echo "[SUCCESS] $1" | tee -a "$INSTALL_LOG"
}

log_warning() {
    echo "[WARNING] $1" | tee -a "$INSTALL_LOG"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$INSTALL_LOG"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
        log_error "This script must be run on a Raspberry Pi"
        exit 1
    fi
    
    local model=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    log_info "Detected: $model"
}

check_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "OS: $PRETTY_NAME"
        
        if [[ "$VERSION_CODENAME" != "bookworm" ]] && [[ "$VERSION_CODENAME" != "bullseye" ]]; then
            log_warning "This script is optimized for Bookworm or Bullseye. Your OS ($VERSION_CODENAME) may have issues."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

check_camera() {
    log_info "Checking for camera module..."
    if command -v libcamera-hello &> /dev/null; then
        if libcamera-hello --list-cameras 2>&1 | grep -q "Available cameras"; then
            log_success "Camera module detected"
        else
            log_warning "Camera module not detected. Make sure it's connected and enabled."
        fi
    else
        log_warning "libcamera-apps not installed yet. Camera check will be performed after installation."
    fi
}

check_disk_space() {
    local available=$(df / | tail -1 | awk '{print $4}')
    local required=$((3 * 1024 * 1024))  # 3GB in KB
    
    if [ "$available" -lt "$required" ]; then
        log_error "Insufficient disk space. Need at least 3GB free, have $(($available / 1024 / 1024))GB"
        exit 1
    fi
    log_success "Sufficient disk space available"
}

enable_swap() {
    log_info "Checking swap space..."
    local current_swap=$(free -m | grep Swap | awk '{print $2}')
    
    log_info "Current swap: ${current_swap}MB"
    
    if [ "$current_swap" -lt 512 ]; then
        log_warning "Insufficient swap detected. Adding 1GB swap file..."
        local swap_file="/swapfile_watney"
        
        # Turn off any existing swap first
        swapoff -a 2>/dev/null || true
        
        # Remove old swap file if it exists
        rm -f "$swap_file"
        
        # Create new swap file
        log_info "Creating swap file (this takes a minute)..."
        dd if=/dev/zero of="$swap_file" bs=1M count=1024 status=progress 2>&1 | tee -a "$INSTALL_LOG"
        chmod 600 "$swap_file"
        
        log_info "Setting up swap..."
        mkswap "$swap_file" 2>&1 | tee -a "$INSTALL_LOG"
        
        log_info "Enabling swap..."
        swapon "$swap_file" 2>&1 | tee -a "$INSTALL_LOG"
        
        # Verify swap is now active
        sleep 2
        local new_swap=$(free -m | grep Swap | awk '{print $2}')
        if [ "$new_swap" -gt 512 ]; then
            log_success "Swap enabled: ${new_swap}MB now available"
            free -m | tee -a "$INSTALL_LOG"
        else
            log_error "Failed to enable swap! Installation may fail."
            free -m | tee -a "$INSTALL_LOG"
        fi
        
        echo "$swap_file" > /tmp/watney_swap_location
    else
        log_success "Sufficient swap already available ($current_swap MB)"
        free -m | tee -a "$INSTALL_LOG"
    fi
}

install_system_dependencies() {
    log_info "Installing system dependencies (this may take several minutes)..."
    log_info "Optimizing for low memory..."
    
    # Set apt cache sizes (need to be large enough for Trixie's package lists)
    export APT_CONFIG=/tmp/apt-low-mem.conf
    cat > /tmp/apt-low-mem.conf << 'EOF'
APT::Cache-Start "100000000";
APT::Cache-Grow "2000000";
APT::Cache-Limit "200000000";
Dir::Cache::pkgcache "";
Dir::Cache::srcpkgcache "";
EOF
    
    log_info "Running apt-get update..."
    apt-get update 2>&1 | tee -a "$INSTALL_LOG"
    
    # Core dependencies (without pigpio first)
    apt-get install -y \
        git python3-pip python3-venv python3-rpi.gpio python3-smbus \
        python3-numpy libcamera-apps gstreamer1.0-tools \
        gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
        gstreamer1.0-alsa python3-gst-1.0 dnsmasq hostapd \
        python3-flask python3-requests \
        >> "$INSTALL_LOG" 2>&1
    
    # Try to install pigpio from package, build from source if not available
    if apt-get install -y pigpio python3-pigpio >> "$INSTALL_LOG" 2>&1; then
        log_success "pigpio installed from package"
    else
        log_warning "pigpio package not available, building from source..."
        build_pigpio
    fi
    
    log_success "System dependencies installed"
}

build_pigpio() {
    log_info "Building pigpio from source..."
    
    # Install build dependencies
    apt-get install -y gcc make wget unzip >> "$INSTALL_LOG" 2>&1
    
    local build_dir="/tmp/pigpio-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Download and build pigpio
    wget https://github.com/joan2937/pigpio/archive/master.zip >> "$INSTALL_LOG" 2>&1
    unzip master.zip >> "$INSTALL_LOG" 2>&1
    cd pigpio-master
    make >> "$INSTALL_LOG" 2>&1
    make install >> "$INSTALL_LOG" 2>&1
    
    # Install Python bindings
    pip3 install --break-system-packages pigpio >> "$INSTALL_LOG" 2>&1
    
    # Create systemd service for pigpiod
    log_info "Creating pigpiod systemd service..."
    cat > /lib/systemd/system/pigpiod.service << 'EOF'
[Unit]
Description=Pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/pigpiod -l

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    cd "$SCRIPT_DIR"
    rm -rf "$build_dir"
    
    log_success "pigpio built and installed from source with systemd service"
}

install_janus_dependencies() {
    log_info "Installing Janus WebRTC dependencies..."
    
    apt-get install -y \
        libmicrohttpd-dev libjansson-dev libssl-dev libsrtp2-dev \
        libsofia-sip-ua-dev libglib2.0-dev libopus-dev libogg-dev \
        libcurl4-openssl-dev liblua5.3-dev libconfig-dev pkg-config \
        gengetopt libtool automake libnice-dev \
        >> "$INSTALL_LOG" 2>&1
    
    log_success "Janus dependencies installed"
}

build_janus() {
    log_info "Building Janus WebRTC Server (this will take 20-40 minutes)..."
    
    # Check if Janus is already installed
    if [ -d "/opt/janus" ]; then
        log_warning "Janus already exists at /opt/janus"
        read -p "Reinstall Janus? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping Janus installation"
            return 0
        fi
        rm -rf /opt/janus
    fi
    
    # Check current swap
    local current_swap=$(free -m | grep Swap | awk '{print $2}')
    log_info "Current swap: ${current_swap}MB"
    
    # Only add temp swap if we don't have enough
    local swap_file="/tmp/watney_swap"
    local added_swap=false
    if [ "$current_swap" -lt 2048 ]; then
        log_info "Adding temporary 1GB swap file for compilation..."
        dd if=/dev/zero of="$swap_file" bs=1M count=1024 >> "$INSTALL_LOG" 2>&1
        chmod 600 "$swap_file"
        mkswap "$swap_file" >> "$INSTALL_LOG" 2>&1
        swapon "$swap_file" >> "$INSTALL_LOG" 2>&1
        log_success "Temporary swap enabled"
        added_swap=true
    else
        log_info "Sufficient swap already available, skipping temp swap creation"
    fi
    
    local build_dir="/tmp/janus-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Clone Janus
    git clone https://github.com/meetecho/janus-gateway.git >> "$INSTALL_LOG" 2>&1
    cd janus-gateway
    git checkout 5ec8568709c483ae89b1aa77e127d14c3b59428c >> "$INSTALL_LOG" 2>&1
    
    # Build Janus with reduced parallelism to save memory
    sh autogen.sh >> "$INSTALL_LOG" 2>&1
    ./configure --prefix=/opt/janus --disable-aes-gcm >> "$INSTALL_LOG" 2>&1
    log_info "Compiling (using single-threaded build to conserve memory)..."
    make -j1 >> "$INSTALL_LOG" 2>&1
    make install >> "$INSTALL_LOG" 2>&1
    
    # Clean up temp swap only if we added it
    if [ "$added_swap" = true ]; then
        swapoff "$swap_file" >> "$INSTALL_LOG" 2>&1
        rm -f "$swap_file"
        log_info "Temporary swap removed"
    fi
    
    cd "$SCRIPT_DIR"
    rm -rf "$build_dir"
    
    log_success "Janus WebRTC Server built and installed"
}

install_mimic_tts() {
    log_info "Installing Mimic TTS (this will take 15-20 minutes)..."
    
    # Check if mimic is already installed
    if command -v mimic &> /dev/null; then
        log_info "Mimic TTS already installed, skipping"
        return 0
    fi
    
    apt-get install -y gcc make pkg-config automake libtool \
        libicu-dev libpcre2-dev libasound2-dev >> "$INSTALL_LOG" 2>&1
    
    local build_dir="/tmp/mimic-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Use shallow clone to reduce memory usage, with retry logic
    log_info "Cloning Mimic repository (using shallow clone to save memory)..."
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        log_info "Clone attempt $attempt of $max_attempts..."
        if git clone --depth 1 --single-branch https://github.com/MycroftAI/mimic.git >> "$INSTALL_LOG" 2>&1; then
            log_success "Clone successful"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "Failed to clone mimic after $max_attempts attempts"
                log_warning "Skipping Mimic TTS installation - you can install it manually later"
                cd "$SCRIPT_DIR"
                rm -rf "$build_dir"
                return 0
            fi
            log_warning "Clone failed, retrying..."
            rm -rf mimic
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    cd mimic
    # Fetch the specific commit we need
    git fetch --depth 1 origin 255213684c9cb877c8b7017a8dc0cedcf9cf695b >> "$INSTALL_LOG" 2>&1 || true
    git checkout 255213684c9cb877c8b7017a8dc0cedcf9cf695b >> "$INSTALL_LOG" 2>&1 || log_warning "Using HEAD instead of specific commit"
    
    ./autogen.sh >> "$INSTALL_LOG" 2>&1
    ./configure --prefix="/usr/local" >> "$INSTALL_LOG" 2>&1
    make >> "$INSTALL_LOG" 2>&1
    make install >> "$INSTALL_LOG" 2>&1
    
    cd "$SCRIPT_DIR"
    rm -rf "$build_dir"
    
    log_success "Mimic TTS installed"
}

install_watney_software() {
    log_info "Installing Watney software..."
    
    # Determine actual user (not root)
    local ACTUAL_USER="${SUDO_USER:-$USER}"
    if [ "$ACTUAL_USER" = "root" ]; then
        ACTUAL_USER="pi"  # fallback to pi if we can't determine
    fi
    local USER_HOME=$(eval echo "~$ACTUAL_USER")
    
    log_info "Installing for user: $ACTUAL_USER (home: $USER_HOME)"
    
    # Install Python dependencies
    pip3 install --break-system-packages aiohttp apa102-pi psutil pyalsaaudio smbus >> "$INSTALL_LOG" 2>&1
    
    # Set up Watney files
    local watney_dir="$USER_HOME/watney"
    if [ "$SCRIPT_DIR" != "$watney_dir" ]; then
        log_info "Copying Watney files to $watney_dir..."
        mkdir -p "$watney_dir"
        cp -r "$SCRIPT_DIR"/* "$watney_dir"/
        chown -R "$ACTUAL_USER:$ACTUAL_USER" "$watney_dir"
    fi
    
    # Copy SSL certificates
    cp "$watney_dir/cert.pem" "$USER_HOME/" 2>/dev/null || log_warning "cert.pem not found"
    cp "$watney_dir/key.pem" "$USER_HOME/" 2>/dev/null || log_warning "key.pem not found"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/cert.pem" "$USER_HOME/key.pem" 2>/dev/null || true
    
    # Copy Janus configuration
    if [ -d "$watney_dir/janus" ]; then
        cp -r "$watney_dir/janus"/* /opt/janus/etc/janus/
        
        # Replace USER_PLACEHOLDER with actual username in Janus configs
        log_info "Configuring Janus certificate paths for user: $ACTUAL_USER"
        sed -i "s|USER_PLACEHOLDER|$ACTUAL_USER|g" /opt/janus/etc/janus/janus.jcfg
        sed -i "s|USER_PLACEHOLDER|$ACTUAL_USER|g" /opt/janus/etc/janus/janus.transport.http.jcfg
        
        chown -R "$ACTUAL_USER:$ACTUAL_USER" /opt/janus
    fi
    
    log_success "Watney software installed"
}

configure_system() {
    log_info "Configuring system settings..."
    
    # Check if pigpiod service exists, create it if not
    if ! systemctl list-unit-files | grep -q pigpiod.service; then
        log_warning "pigpiod service not found, creating it..."
        
        # Determine where pigpiod is installed
        local pigpiod_path=$(which pigpiod || echo "/usr/local/bin/pigpiod")
        
        cat > /lib/systemd/system/pigpiod.service << EOF
[Unit]
Description=Pigpio daemon
After=network.target

[Service]
Type=forking
ExecStart=$pigpiod_path -l

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        log_success "pigpiod service created"
    fi
    
    # Enable pigpio
    systemctl enable pigpiod >> "$INSTALL_LOG" 2>&1
    systemctl start pigpiod >> "$INSTALL_LOG" 2>&1
    
    # Configure pigpio for timing (try both possible locations)
    sed -i 's:^ExecStart=.*/pigpiod -l:ExecStart='$(which pigpiod || echo "/usr/local/bin/pigpiod")' -l -t 0:g' \
        /lib/systemd/system/pigpiod.service 2>/dev/null || true
    systemctl daemon-reload
    
    # Enable SPI and I2C
    raspi-config nonint do_spi 0 >> "$INSTALL_LOG" 2>&1
    raspi-config nonint do_i2c 0 >> "$INSTALL_LOG" 2>&1
    
    # Determine boot path
    if [ -d "/boot/firmware" ]; then
        BOOT_PATH="/boot/firmware"
    else
        BOOT_PATH="/boot"
    fi
    
    log_info "Using boot path: $BOOT_PATH"
    
    # Configure boot settings
    if ! grep -q "disable_camera_led=1" "$BOOT_PATH/config.txt"; then
        echo "disable_camera_led=1" >> "$BOOT_PATH/config.txt"
    fi
    
    if ! grep -q "dtoverlay=googlevoicehat-soundcard" "$BOOT_PATH/config.txt"; then
        echo "dtoverlay=googlevoicehat-soundcard" >> "$BOOT_PATH/config.txt"
    fi
    
    if ! grep -q "dtoverlay=i2s-mmap" "$BOOT_PATH/config.txt"; then
        echo "dtoverlay=i2s-mmap" >> "$BOOT_PATH/config.txt"
    fi
    
    # Configure GPIO pins
    for pin in 13 25 24 17 27; do
        if ! grep -q "gpio=$pin=op,dl" "$BOOT_PATH/config.txt"; then
            echo "gpio=$pin=op,dl" >> "$BOOT_PATH/config.txt"
        fi
    done
    
    # Disable default audio
    sed -i 's/^dtparam=audio=on/#dtparam=audio=on/g' "$BOOT_PATH/config.txt" 2>/dev/null || true
    
    log_success "System configured"
}

install_systemd_service() {
    log_info "Installing Watney systemd service..."
    
    cp "$SCRIPT_DIR/packer/watney.service" /etc/systemd/system/ 2>/dev/null || \
        log_warning "watney.service not found"
    
    systemctl daemon-reload
    systemctl enable watney >> "$INSTALL_LOG" 2>&1
    
    log_success "Watney service installed and enabled"
}

setup_turnkey() {
    log_info "Setting up WiFi configuration (Turnkey)..."
    
    # Determine actual user
    local ACTUAL_USER="${SUDO_USER:-$USER}"
    if [ "$ACTUAL_USER" = "root" ]; then
        ACTUAL_USER="pi"
    fi
    local USER_HOME=$(eval echo "~$ACTUAL_USER")
    
    if [ -d "$USER_HOME/raspberry-pi-turnkey" ]; then
        log_info "Turnkey already installed, skipping"
        return 0
    fi
    
    cd "$USER_HOME"
    git clone https://github.com/nikivanov/raspberry-pi-turnkey.git >> "$INSTALL_LOG" 2>&1
    
    pip3 install --break-system-packages wpasupplicantconf >> "$INSTALL_LOG" 2>&1
    
    cd raspberry-pi-turnkey
    cp config/hostapd /etc/default/hostapd
    cp config/dhcpcd.conf /etc/dhcpcd.conf
    cp config/dnsmasq.conf /etc/dnsmasq.conf
    cp config/hostapd.conf /etc/hostapd/hostapd.conf
    
    # Configure hostapd to unblock wifi
    if [ -f "$SCRIPT_DIR/packer/unblock_wifi.sh" ]; then
        cp "$SCRIPT_DIR/packer/unblock_wifi.sh" "$USER_HOME/"
        chmod +x "$USER_HOME/unblock_wifi.sh"
        sed -i '/^ExecStart=.*/a ExecStartPre=/bin/bash '"$USER_HOME"'/unblock_wifi.sh' \
            /usr/lib/systemd/system/hostapd.service 2>/dev/null || true
    fi
    
    systemctl enable hostapd >> "$INSTALL_LOG" 2>&1
    
    echo '{"status": "hostapd"}' > status.json
    cp turnkey.service /etc/systemd/system/
    systemctl enable turnkey >> "$INSTALL_LOG" 2>&1
    
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/raspberry-pi-turnkey"
    
    cd "$SCRIPT_DIR"
    
    log_success "Turnkey WiFi configuration installed"
}

copy_audio_configs() {
    log_info "Configuring audio..."
    
    if [ -f "$SCRIPT_DIR/packer/asound.conf" ]; then
        cp "$SCRIPT_DIR/packer/asound.conf" /etc/asound.conf
        chown root:root /etc/asound.conf
        chmod 644 /etc/asound.conf
    fi
    
    if [ -f "$SCRIPT_DIR/packer/asound.state" ]; then
        mkdir -p /var/lib/alsa
        cp "$SCRIPT_DIR/packer/asound.state" /var/lib/alsa/asound.state
        chown root:root /var/lib/alsa/asound.state
        chmod 644 /var/lib/alsa/asound.state
    fi
    
    log_success "Audio configured"
}

print_summary() {
    # Determine actual user
    local ACTUAL_USER="${SUDO_USER:-$USER}"
    if [ "$ACTUAL_USER" = "root" ]; then
        ACTUAL_USER="pi"
    fi
    local USER_HOME=$(eval echo "~$ACTUAL_USER")
    
    echo ""
    echo "=========================================================="
    log_success "Watney installation completed successfully!"
    echo "=========================================================="
    echo ""
    log_info "Next steps:"
    echo "  1. Review the configuration in $USER_HOME/watney/rover.conf"
    echo "  2. Reboot your Raspberry Pi: sudo reboot"
    echo "  3. After reboot, Watney will start automatically"
    echo "  4. Access the web interface at: https://$(hostname).local:5000"
    echo "  5. SSH user: $ACTUAL_USER"
    echo ""
    log_info "WiFi Configuration:"
    echo "  - If not connected to WiFi, Watney will host 'Watney' hotspot"
    echo "  - Connect to hotspot and configure WiFi at: http://192.168.4.1"
    echo ""
    log_info "Installation log: $INSTALL_LOG"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo "=========================================================="
    echo "   Watney Telepresence Rover Installation"
    echo "=========================================================="
    echo ""
    
    # Clear log
    > "$INSTALL_LOG"
    
    log_info "Log file: $INSTALL_LOG"
    echo ""
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    check_root
    check_raspberry_pi
    check_os_version
    check_disk_space
    check_camera
    
    echo ""
    log_warning "This installation will take 45-60 minutes and will:"
    log_warning "  - Install system dependencies"
    log_warning "  - Build Janus WebRTC Server (~30 min)"
    log_warning "  - Build Mimic TTS (~15 min)"
    log_warning "  - Configure system settings"
    log_warning "  - Set up WiFi hotspot capability"
    echo ""
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Starting installation..."
    log_info "You can monitor progress in another terminal with: tail -f $INSTALL_LOG"
    echo ""
    
    # Enable swap early to prevent out-of-memory issues
    enable_swap
    
    # Installation steps
    install_system_dependencies
    install_janus_dependencies
    build_janus
    install_mimic_tts
    install_watney_software
    configure_system
    copy_audio_configs
    install_systemd_service
    setup_turnkey
    
    # Summary
    print_summary
}

# Run main installation
main "$@"
