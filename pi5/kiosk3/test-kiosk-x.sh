#!/bin/bash

# Simple X-enabled Kiosk Test
# For quick testing when X server isn't running

echo "Testing kiosk with X server setup..."

# Ensure we're in the right directory
if [ -d "/home/pi/kiosk3" ]; then
    cd /home/pi/kiosk3
elif [ -d "~/kiosk3" ]; then
    cd ~/kiosk3
else
    echo "ERROR: Cannot find kiosk directory"
    exit 1
fi

# Method 1: Try to use existing X session
if [ ! -z "$DISPLAY" ] && xset q >/dev/null 2>&1; then
    echo "Using existing X session: $DISPLAY"
    python3 webview-app-simple.py
    exit
fi

# Method 2: Check if we're in a desktop environment
if [ ! -z "$XDG_CURRENT_DESKTOP" ] || [ ! -z "$DESKTOP_SESSION" ]; then
    echo "Desktop environment detected, starting kiosk directly..."
    export DISPLAY=:0
    python3 webview-app-simple.py
    exit
fi

# Method 3: Start our own X server
echo "Starting minimal X server for kiosk..."

# Create minimal X config
sudo mkdir -p /tmp/kiosk-x
cat > /tmp/kiosk-x/xinitrc << 'EOF'
#!/bin/bash
export DISPLAY=:0

# Basic X setup
xset s off
xset -dpms  
xset s noblank
xsetroot -solid black

# Start window manager
openbox-session &
sleep 1

# Start kiosk
cd ~/kiosk3 2>/dev/null || cd /home/pi/kiosk3
python3 webview-app-simple.py

# Keep session alive
wait
EOF

chmod +x /tmp/kiosk-x/xinitrc

# Start X with our config
echo "Launching X server..."
sudo X :0 vt7 &
sleep 3

# Set display and run kiosk
export DISPLAY=:0
/tmp/kiosk-x/xinitrc

# Cleanup
sudo pkill X 2>/dev/null