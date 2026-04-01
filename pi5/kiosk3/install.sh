#!/bin/bash

# School Kiosk Installation Script
# Automatically sets up a Raspberry Pi as a school break time kiosk display
# 
# Usage: curl -fsSL https://raw.githubusercontent.com/FoxyIsCoding/school/main/pi5/kiosk3/install.sh | sudo bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOGFILE="/var/log/kiosk-install.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    warn "This script is optimized for Raspberry Pi but will attempt to continue"
fi

log "Starting School Kiosk Installation..."
log "Installation log: $LOGFILE"

# Update system
log "Updating system packages..."
apt-get update

# Upgrade system with held packages handling
log "Upgrading system (handling held packages)..."
apt-get upgrade -y || {
    warn "Some packages were held back during upgrade, continuing..."
    apt-get dist-upgrade -y || warn "Dist-upgrade also had issues, continuing with installation..."
}

# Install required packages
log "Installing required packages..."

# Try to install chromium with fallback options
log "Detecting available chromium package..."
if apt-cache show chromium >/dev/null 2>&1; then
    CHROMIUM_PKG="chromium"
    log "Found chromium package"
elif apt-cache show chromium-browser >/dev/null 2>&1; then
    CHROMIUM_PKG="chromium-browser"
    log "Found chromium-browser package"
else
    warn "No chromium package found, will use PyQt5 WebEngine only"
    CHROMIUM_PKG=""
fi

# Install base packages
apt-get install -y \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-dev \
    python3-venv \
    python3-full \
    git \
    curl \
    wget \
    xorg \
    openbox \
    unclutter \
    x11-xserver-utils \
    xinit \
    fonts-liberation \
    fonts-dejavu-core \
    dbus-x11 \
    build-essential \
    libgl1-mesa-glx \
    libxkbcommon-x11-0

# Try to install PyQt5 packages from repositories
log "Installing PyQt5 system packages..."
PYQT5_PACKAGES=(
    "python3-pyqt5"
    "python3-pyqt5.qtwidgets" 
    "python3-pyqt5.qtcore"
    "python3-pyqt5.qtgui"
    "python3-pyqt5.qtwebengine"
    "python3-pyqt5-dev"
    "qtbase5-dev"
    "qtwebengine5-dev"
)

for package in "${PYQT5_PACKAGES[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
        log "Installing $package..."
        apt-get install -y "$package" || warn "Failed to install $package"
    else
        info "$package not available in repositories"
    fi
done

# Install chromium if available
if [ -n "$CHROMIUM_PKG" ]; then
    log "Installing $CHROMIUM_PKG..."
    apt-get install -y "$CHROMIUM_PKG" || warn "Failed to install $CHROMIUM_PKG"
fi

# Install Python packages
log "Installing Python packages..."

# Check if we're in an externally managed environment (PEP 668)
if python3 -m pip install --help | grep -q "break-system-packages"; then
    log "Detected externally managed Python environment"
    
    # Try system packages first, then pip with break-system-packages if needed
    PYQT5_INSTALLED=false
    
    # Check if system PyQt5 packages are sufficient
    if python3 -c "import PyQt5.QtWebEngineWidgets" 2>/dev/null; then
        log "PyQt5 WebEngine already available via system packages"
        PYQT5_INSTALLED=true
    elif apt-cache show python3-pyqt5.qtwebengine >/dev/null 2>&1; then
        log "Installing PyQt5 via system packages..."
        apt-get install -y python3-pyqt5.qtwebengine python3-pyqt5.qtwidgets python3-pyqt5.qtcore python3-pyqt5.qtgui
        PYQT5_INSTALLED=true
    fi
    
    # If system packages failed, use pip with break-system-packages
    if [ "$PYQT5_INSTALLED" = false ]; then
        warn "System PyQt5 packages not available, using pip with --break-system-packages"
        warn "This is needed for the kiosk system service to work properly"
        
        # Upgrade pip
        python3 -m pip install --upgrade pip --break-system-packages 2>/dev/null || warn "Failed to upgrade pip"
        
        # Install PyQt5 packages
        python3 -m pip install PyQt5 PyQtWebEngine --break-system-packages || {
            warn "Failed to install PyQt5 via pip, will rely on Chromium fallback"
        }
    fi
else
    # Old pip behavior - no PEP 668 restrictions
    log "Installing PyQt5 via pip (legacy system)"
    pip3 install --upgrade pip || warn "Failed to upgrade pip"
    pip3 install PyQt5 PyQtWebEngine || warn "Failed to install PyQt5 via pip"
fi

# Create kiosk user if doesn't exist
if ! id "pi" &>/dev/null; then
    log "Creating pi user for kiosk..."
    useradd -m -s /bin/bash pi
    usermod -aG video,audio,input,render pi
else
    log "User 'pi' already exists"
fi

# Create kiosk directory
KIOSK_DIR="/home/pi/kiosk3"
log "Creating kiosk directory: $KIOSK_DIR"
mkdir -p "$KIOSK_DIR"

# Download kiosk files from GitHub
log "Downloading kiosk files from GitHub..."
cd /tmp
if [ -d "school" ]; then
    rm -rf school
fi

git clone https://github.com/FoxyIsCoding/school.git || error "Failed to clone repository"
cp -r school/pi5/kiosk3/* "$KIOSK_DIR/"
rm -rf school  # Cleanup
chown -R pi:pi "$KIOSK_DIR"

# Make scripts executable
log "Setting script permissions..."
chmod +x "$KIOSK_DIR"/*.py
chmod +x "$KIOSK_DIR"/*.sh

# Install X server configuration
log "Installing X server configuration..."
cp "$KIOSK_DIR/xorg-kiosk.conf" /etc/X11/xorg.conf.d/99-kiosk.conf

# Install systemd services
log "Installing systemd services..."
cp "$KIOSK_DIR/kiosk-scheduler.service" /etc/systemd/system/
cp "$KIOSK_DIR/kiosk-xserver.service" /etc/systemd/system/

# Reload systemd and enable services
log "Enabling systemd services..."
systemctl daemon-reload
systemctl enable kiosk-scheduler.service
systemctl enable kiosk-xserver.service

# Configure boot settings for Raspberry Pi
if [ -f /boot/config.txt ]; then
    log "Configuring Raspberry Pi boot settings..."
    
    # Backup original config
    cp /boot/config.txt /boot/config.txt.backup
    
    # Add/update display settings
    cat >> /boot/config.txt << EOF

# Kiosk Display Settings
hdmi_force_hotplug=1
hdmi_drive=2
disable_overscan=1
gpu_mem=128

# Performance settings
over_voltage=2
arm_freq=1000
gpu_freq=500
sdram_freq=500
EOF
fi

# Configure cmdline.txt for faster boot
if [ -f /boot/cmdline.txt ]; then
    log "Optimizing boot parameters..."
    cp /boot/cmdline.txt /boot/cmdline.txt.backup
    
    # Add quiet boot and disable splash
    sed -i 's/$/ quiet splash plymouth.ignore-serial-consoles logo.nologo vt.global_cursor_default=0/' /boot/cmdline.txt
fi

# Disable unnecessary services for faster boot
log "Disabling unnecessary services..."
systemctl disable triggerhappy.service 2>/dev/null || true
systemctl disable hciuart.service 2>/dev/null || true
systemctl disable bluetooth.service 2>/dev/null || true
systemctl disable avahi-daemon.service 2>/dev/null || true
systemctl disable dphys-swapfile.service 2>/dev/null || true

# Configure automatic login
log "Configuring automatic login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

# Set up log rotation
log "Setting up log rotation..."
cat > /etc/logrotate.d/kiosk << EOF
/var/log/kiosk*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 pi pi
}
EOF

# Create startup script for user session
log "Creating user startup script..."
mkdir -p /home/pi/.config/autostart
cat > /home/pi/.config/autostart/kiosk.desktop << EOF
[Desktop Entry]
Type=Application
Name=School Kiosk
Comment=Start school kiosk display
Exec=/home/pi/kiosk3/kiosk-scheduler.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown pi:pi /home/pi/.config/autostart/kiosk.desktop

# Set up cron job as backup
log "Setting up cron job backup..."
crontab -u pi -l 2>/dev/null | grep -v "kiosk-scheduler" > /tmp/cron.tmp || true
echo "@reboot sleep 30 && /usr/bin/python3 /home/pi/kiosk3/kiosk-scheduler.py" >> /tmp/cron.tmp
crontab -u pi /tmp/cron.tmp
rm /tmp/cron.tmp

# Create uninstall script
log "Creating uninstall script..."
cat > "$KIOSK_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
# Kiosk Uninstall Script

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "Uninstalling School Kiosk..."

# Stop and disable services
systemctl stop kiosk-scheduler.service 2>/dev/null || true
systemctl stop kiosk-xserver.service 2>/dev/null || true
systemctl disable kiosk-scheduler.service 2>/dev/null || true
systemctl disable kiosk-xserver.service 2>/dev/null || true

# Remove service files
rm -f /etc/systemd/system/kiosk-scheduler.service
rm -f /etc/systemd/system/kiosk-xserver.service
systemctl daemon-reload

# Remove X config
rm -f /etc/X11/xorg.conf.d/99-kiosk.conf

# Remove autostart
rm -f /home/pi/.config/autostart/kiosk.desktop

# Remove cron job
crontab -u pi -l 2>/dev/null | grep -v "kiosk-scheduler" | crontab -u pi - 2>/dev/null || true

# Restore boot configs
if [ -f /boot/config.txt.backup ]; then
    mv /boot/config.txt.backup /boot/config.txt
fi
if [ -f /boot/cmdline.txt.backup ]; then
    mv /boot/cmdline.txt.backup /boot/cmdline.txt
fi

echo "Kiosk uninstalled. Reboot recommended."
EOF

chmod +x "$KIOSK_DIR/uninstall.sh"
chown pi:pi "$KIOSK_DIR/uninstall.sh"

# Final permissions fix
log "Setting final permissions..."
chown -R pi:pi /home/pi
chmod -R 755 "$KIOSK_DIR"

# Create status check script
cat > "$KIOSK_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "=== School Kiosk Status ==="
echo "Date: $(date)"
echo
echo "Services:"
systemctl is-active kiosk-scheduler.service || echo "kiosk-scheduler: inactive"
systemctl is-active kiosk-xserver.service || echo "kiosk-xserver: inactive"
echo
echo "Processes:"
pgrep -f "kiosk-scheduler.py" >/dev/null && echo "Scheduler: running" || echo "Scheduler: not running"
pgrep -f "webview-app.py" >/dev/null && echo "WebView: running" || echo "WebView: not running"
pgrep "Xorg" >/dev/null && echo "X Server: running" || echo "X Server: not running"
echo
echo "Display:"
if command -v xset >/dev/null 2>&1; then
    DISPLAY=:0 xset q | grep -A 5 "DPMS" 2>/dev/null || echo "DPMS info not available"
fi
echo
echo "Logs (last 10 lines):"
tail -n 10 /var/log/kiosk-scheduler.log 2>/dev/null || echo "No scheduler logs found"
EOF

chmod +x "$KIOSK_DIR/status.sh"
chown pi:pi "$KIOSK_DIR/status.sh"

# Installation complete
log "Installation completed successfully!"
info ""
info "=== Installation Summary ==="
info "Kiosk directory: $KIOSK_DIR"
info "Services installed: kiosk-scheduler, kiosk-xserver"
info "Log files: /var/log/kiosk-*.log"
info "Status check: $KIOSK_DIR/status.sh"
info "Uninstall: sudo $KIOSK_DIR/uninstall.sh"
info ""
info "Active periods configured:"
info "  07:30-08:00 (Before school)"
info "  08:45-08:55 (Break 1)"
info "  09:40-10:00 (Break 2)"
info "  10:45-10:55 (Break 3)"
info "  11:40-11:50 (Break 4)"
info "  12:35-12:45 (Break 5)"
info "  13:30-13:35 (Break 6)"
info "  14:20-14:25 (Break 7)"
info "  15:10-16:00 (After school)"
info ""
warn "IMPORTANT: Please reboot the system to complete the installation:"
warn "sudo reboot"
info ""
log "Installation log saved to: $LOGFILE"