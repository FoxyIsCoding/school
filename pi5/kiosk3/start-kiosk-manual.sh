#!/bin/bash

# Quick Kiosk Startup Script
# Simple manual start for troubleshooting

echo "Starting School Kiosk..."

# Go to kiosk directory
cd /home/pi/kiosk3 || {
    echo "ERROR: Cannot find kiosk directory"
    echo "Run the install script first"
    exit 1
}

# Make sure scripts are executable
chmod +x *.py *.sh

# Check what we have available
if [ -f "webview-app-simple.py" ]; then
    echo "Found simple webview app, starting..."
    python3 webview-app-simple.py
elif [ -f "webview-app.py" ]; then
    echo "Found full webview app, starting..."
    python3 webview-app.py  
elif command -v chromium >/dev/null; then
    echo "Using direct chromium approach..."
    
    # Set up basic X environment
    export DISPLAY=:0
    
    # Start X server in background if not running
    if ! pgrep Xorg >/dev/null; then
        startx &
        sleep 3
    fi
    
    # Start chromium in kiosk mode
    chromium --kiosk --no-sandbox --disable-infobars --start-fullscreen https://sokolnice.neocities.org &
    
    # Keep script running
    wait
else
    echo "ERROR: No kiosk methods available"
    echo "Missing: chromium, python webview apps"
fi