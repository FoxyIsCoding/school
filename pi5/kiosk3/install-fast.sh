#!/bin/bash

# Fast Kiosk Installation - No Virtual Environment
# Skips PyQt5 venv installation since it's already available system-wide

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

log "Starting FAST kiosk installation (no virtual environment)..."

# Update packages
log "Updating package lists..."
apt-get update

# Install core packages
log "Installing core packages..."
apt-get install -y \
    python3 \
    python3-pip \
    chromium \
    xorg \
    openbox \
    unclutter \
    x11-xserver-utils \
    xinit \
    git \
    curl \
    fonts-liberation \
    dbus-x11

# Install system PyQt5 packages
log "Installing system PyQt5 packages..."
apt-get install -y \
    python3-pyqt5 \
    python3-pyqt5.qtwidgets \
    python3-pyqt5.qtcore \
    python3-pyqt5.qtgui \
    python3-pyqt5.qtwebengine || warn "Some PyQt5 packages not available"

# Create pi user if needed
if ! id "pi" &>/dev/null; then
    log "Creating pi user..."
    useradd -m -s /bin/bash pi
    usermod -aG video,audio,input,render pi
fi

# Create kiosk directory
KIOSK_DIR="/home/pi/kiosk3"
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

# SKIP VIRTUAL ENVIRONMENT ENTIRELY
log "Skipping virtual environment creation (using system PyQt5)"

# Update python wrapper to use system python
cat > "$KIOSK_DIR/python-wrapper.sh" << 'EOF'
#!/bin/bash
# Python Wrapper - System Python Only (No VEnv)

echo "Using system Python (virtual environment skipped)"
exec python3 "$@"
EOF

chmod +x "$KIOSK_DIR/python-wrapper.sh"
chown pi:pi "$KIOSK_DIR/python-wrapper.sh"

# Test PyQt5 availability
log "Testing PyQt5 availability..."
if python3 -c "import PyQt5.QtWebEngineWidgets" 2>/dev/null; then
    log "✓ PyQt5 WebEngine available via system packages"
elif python3 -c "import PyQt5.QtWidgets" 2>/dev/null; then
    log "✓ PyQt5 (without WebEngine) available - will use Chromium fallback"
else
    warn "PyQt5 not available - will use Chromium fallback only"
fi

# Install X server configuration
log "Installing X server configuration..."
cp "$KIOSK_DIR/xorg-kiosk.conf" /etc/X11/xorg.conf.d/99-kiosk.conf

# Install systemd services
log "Installing systemd services..."
cp "$KIOSK_DIR/kiosk-scheduler.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable kiosk-scheduler.service

# Create simple status script
cat > "$KIOSK_DIR/status.sh" << 'EOF'
#!/bin/bash
echo "=== School Kiosk Status ==="
echo "Date: $(date)"
echo
echo "Python Environment: System Python (no venv)"
if python3 -c "import PyQt5.QtWebEngineWidgets" 2>/dev/null; then
    echo "PyQt5 WebEngine: ✓ available"
else
    echo "PyQt5 WebEngine: ❌ not available"
fi
echo
echo "Services:"
systemctl is-active kiosk-scheduler.service || echo "kiosk-scheduler: inactive"
echo
echo "Processes:"
pgrep -f "kiosk-scheduler.py" >/dev/null && echo "Scheduler: running" || echo "Scheduler: not running"
pgrep -f "webview-app.py" >/dev/null && echo "WebView: running" || echo "WebView: not running"
pgrep "Xorg" >/dev/null && echo "X Server: running" || echo "X Server: not running"
EOF

chmod +x "$KIOSK_DIR/status.sh"
chown pi:pi "$KIOSK_DIR/status.sh"

log "Installation completed successfully!"
log "✓ Skipped virtual environment (using system PyQt5)"
log "✓ Kiosk directory: $KIOSK_DIR"
log "✓ Status check: $KIOSK_DIR/status.sh"
log ""
log "Active periods configured:"
log "  07:30-08:00 (Before school)"
log "  08:45-08:55 (Break 1)"
log "  09:40-10:00 (Break 2)"
log "  10:45-10:55 (Break 3)"
log "  11:40-11:50 (Break 4)"
log "  12:35-12:45 (Break 5)"
log "  13:30-13:35 (Break 6)"
log "  14:20-14:25 (Break 7)"
log "  15:10-16:00 (After school)"
log ""
log "Reboot to start kiosk: sudo reboot"