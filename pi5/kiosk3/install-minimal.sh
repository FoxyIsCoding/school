#!/bin/bash

# Minimal Kiosk Installation Script
# Only installs verified available packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
LOGFILE="/var/log/kiosk-install.log"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOGFILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOGFILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOGFILE"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "Starting minimal kiosk installation..."

# Update package lists
log "Updating package lists..."
apt-get update

# Install only verified core packages
log "Installing verified core packages..."
apt-get install -y \
    python3 \
    python3-venv \
    python3-pip \
    chromium \
    xorg \
    openbox \
    unclutter \
    x11-xserver-utils \
    xinit \
    git \
    curl \
    wget \
    fonts-liberation \
    dbus-x11

# Install optional graphics packages individually
log "Installing optional graphics packages..."
for package in "libgl1" "libgl1-mesa-glx" "libgl1-mesa-dri"; do
    log "Attempting to install: $package"
    if apt-get install -y "$package"; then
        log "Successfully installed: $package"
    else
        warn "Failed to install: $package (continuing)"
    fi
done

# Create kiosk user
if ! id "pi" &>/dev/null; then
    log "Creating pi user..."
    useradd -m -s /bin/bash pi
    usermod -aG video,audio,input,render pi
fi

# Create kiosk directory
KIOSK_DIR="/home/pi/kiosk3"
log "Creating kiosk directory: $KIOSK_DIR"
mkdir -p "$KIOSK_DIR"

# Download kiosk files
log "Downloading kiosk files..."
cd /tmp
rm -rf school
git clone https://github.com/FoxyIsCoding/school.git
cp -r school/pi5/kiosk3/* "$KIOSK_DIR/"
rm -rf school
chown -R pi:pi "$KIOSK_DIR"
chmod +x "$KIOSK_DIR"/*.py "$KIOSK_DIR"/*.sh

# Create virtual environment
log "Creating Python virtual environment..."
sudo -u pi python3 -m venv "$KIOSK_DIR/venv"

# Install Python packages
log "Installing Python packages..."
if sudo -u pi "$KIOSK_DIR/venv/bin/pip" install PyQt5 PyQtWebEngine; then
    log "PyQt5 installed in virtual environment"
else
    warn "PyQt5 installation failed, will use Chromium fallback"
fi

# Install X server configuration
log "Installing X server configuration..."
cp "$KIOSK_DIR/xorg-kiosk.conf" /etc/X11/xorg.conf.d/99-kiosk.conf

# Install systemd services
log "Installing systemd services..."
cp "$KIOSK_DIR/kiosk-scheduler.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable kiosk-scheduler.service

log "Installation completed!"
log "Reboot the system to start the kiosk: sudo reboot"