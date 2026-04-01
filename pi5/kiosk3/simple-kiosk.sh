#!/bin/bash

# Simple Desktop Kiosk Launcher
# Works from desktop environment or existing X session

echo "=== Simple Desktop Kiosk ==="

# Find kiosk directory
KIOSK_DIR=""
for dir in ~/kiosk3 /home/pi/kiosk3 /home/foxy/kiosk3; do
    if [ -d "$dir" ]; then
        KIOSK_DIR="$dir"
        echo "✓ Found kiosk directory: $KIOSK_DIR"
        break
    fi
done

if [ -z "$KIOSK_DIR" ]; then
    echo "❌ No kiosk directory found"
    exit 1
fi

cd "$KIOSK_DIR"

# Method 1: If we're in a desktop environment, just run directly
if [ ! -z "$DISPLAY" ] || [ ! -z "$XDG_CURRENT_DESKTOP" ]; then
    echo "✓ Desktop environment detected"
    echo "Starting kiosk in desktop mode..."
    
    # Hide other windows and go fullscreen
    python3 webview-app-simple.py &
    KIOSK_PID=$!
    
    echo "Kiosk started (PID: $KIOSK_PID)"
    echo "Press Ctrl+C to stop"
    
    trap "kill $KIOSK_PID 2>/dev/null; echo 'Kiosk stopped'; exit" INT TERM
    wait $KIOSK_PID
    
    exit
fi

# Method 2: Console mode - start X session
echo "Console mode detected, starting X session..."

# Check user permissions
groups | grep -q video || {
    echo "Adding user to video group..."
    sudo usermod -a -G video,input,render $(whoami)
    echo "Please log out and back in for group changes to take effect"
    echo "Then run this script again"
    exit 1
}

# Start simple X session
export DISPLAY=:0

# Kill any existing X
sudo pkill Xorg 2>/dev/null
sleep 2

echo "Starting X server..."
sudo X :0 &
X_PID=$!
sleep 5

if ! kill -0 $X_PID 2>/dev/null; then
    echo "❌ Failed to start X server"
    exit 1
fi

echo "✓ X server started"

# Configure and start kiosk
xset s off 2>/dev/null
openbox-session &
sleep 2

echo "Starting kiosk application..."
python3 webview-app-simple.py &
KIOSK_PID=$!

echo "Kiosk running (X PID: $X_PID, Kiosk PID: $KIOSK_PID)"
echo "Press Ctrl+C to stop"

cleanup() {
    echo "Stopping kiosk..."
    kill $KIOSK_PID 2>/dev/null
    kill $X_PID 2>/dev/null
    sudo pkill Xorg 2>/dev/null
    exit
}

trap cleanup INT TERM
wait $KIOSK_PID