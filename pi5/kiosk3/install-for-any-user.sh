#!/bin/bash

# User-Agnostic Kiosk Installation
# Works with any username

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Get the actual user who ran sudo
REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" = "root" ]; then
    echo "Please run this script with sudo from a normal user account"
    echo "Example: sudo $0"
    exit 1
fi

USER_HOME="/home/$REAL_USER"

echo "=== Installing Kiosk for User: $REAL_USER ==="
echo "User home directory: $USER_HOME"

# Update packages
apt-get update

# Install core packages
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
    fonts-liberation \
    dbus-x11

# Create kiosk directory
KIOSK_DIR="$USER_HOME/kiosk3"
echo "Creating kiosk directory: $KIOSK_DIR"
mkdir -p "$KIOSK_DIR"

# Download kiosk files
echo "Downloading kiosk files..."
cd /tmp
rm -rf school
git clone https://github.com/FoxyIsCoding/school.git
cp -r school/pi5/kiosk3/* "$KIOSK_DIR/"
rm -rf school

# Fix all file paths for the actual user
echo "Fixing file paths for user: $REAL_USER"
sed -i "s|/home/pi|$USER_HOME|g" "$KIOSK_DIR"/*.py
sed -i "s|/home/pi|$USER_HOME|g" "$KIOSK_DIR"/*.sh
sed -i "s|/home/pi|$USER_HOME|g" "$KIOSK_DIR"/*.service

# Set permissions
chown -R "$REAL_USER:$REAL_USER" "$KIOSK_DIR"
chmod +x "$KIOSK_DIR"/*.py "$KIOSK_DIR"/*.sh

# Create virtual environment
echo "Creating virtual environment..."
sudo -u "$REAL_USER" python3 -m venv "$KIOSK_DIR/venv"

# Install Python packages
echo "Installing Python packages..."
if sudo -u "$REAL_USER" "$KIOSK_DIR/venv/bin/pip" install PyQt5 PyQtWebEngine; then
    echo "PyQt5 installed successfully"
else
    echo "PyQt5 installation failed, will use Chromium fallback"
fi

# Create simple chromium kiosk script
cat > "$KIOSK_DIR/start-simple-kiosk.sh" << EOF
#!/bin/bash
# Simple Chromium Kiosk

# Configure display
export DISPLAY=:0

# Start X server if not running
if ! pgrep Xorg >/dev/null; then
    startx &
    sleep 5
fi

# Configure X settings
xset s off
xset -dpms  
xset s noblank
unclutter -idle 1 -root &

# Start window manager
openbox-session &
sleep 2

# Start chromium in kiosk mode
chromium --kiosk --no-sandbox --disable-infobars --start-fullscreen https://sokolnice.neocities.org
EOF

chmod +x "$KIOSK_DIR/start-simple-kiosk.sh"
chown "$REAL_USER:$REAL_USER" "$KIOSK_DIR/start-simple-kiosk.sh"

echo "=== Installation Complete ==="
echo "Kiosk installed in: $KIOSK_DIR"
echo "User: $REAL_USER"
echo
echo "To test the kiosk manually:"
echo "  cd $KIOSK_DIR"
echo "  ./start-simple-kiosk.sh"
echo
echo "To configure auto-boot:"
echo "  sudo $KIOSK_DIR/fix-boot.sh"