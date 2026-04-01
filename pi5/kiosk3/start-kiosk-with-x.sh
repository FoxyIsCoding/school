#!/bin/bash

# X Server Kiosk Starter
# Ensures X server is running before starting kiosk

echo "=== Starting Kiosk with X Server ==="

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    if [ ! -z "$KIOSK_PID" ]; then
        kill $KIOSK_PID 2>/dev/null
    fi
    if [ ! -z "$X_PID" ]; then
        kill $X_PID 2>/dev/null
    fi
}

trap cleanup EXIT INT TERM

# Check if we're already in X (like when run from desktop)
if [ ! -z "$DISPLAY" ] && xset q >/dev/null 2>&1; then
    echo "✓ X server already running on $DISPLAY"
    
    # Start kiosk directly
    echo "Starting kiosk on existing X session..."
    cd ~/kiosk3 2>/dev/null || cd /home/pi/kiosk3
    python3 webview-app-simple.py
    exit
fi

# We need to start X server ourselves
echo "No X server detected, starting new X session..."

# Kill any existing X servers
sudo pkill Xorg 2>/dev/null
sleep 2

# Create simple X startup script
cat > /tmp/start-kiosk-x.sh << 'EOF'
#!/bin/bash

# Configure X environment
export DISPLAY=:0
xset s off
xset -dpms
xset s noblank
xsetroot -solid black

# Hide cursor
unclutter -idle 1 -root &

# Start window manager
openbox-session &
sleep 2

# Start kiosk application
cd ~/kiosk3 2>/dev/null || cd /home/pi/kiosk3
if [ -f "webview-app-simple.py" ]; then
    python3 webview-app-simple.py
else
    # Fallback to direct chromium
    chromium --kiosk --no-sandbox --start-fullscreen https://sokolnice.neocities.org
fi
EOF

chmod +x /tmp/start-kiosk-x.sh

# Start X server with our kiosk session
echo "Starting X server with kiosk..."
startx /tmp/start-kiosk-x.sh -- :0 vt7 2>/dev/null &
X_PID=$!

echo "X server started (PID: $X_PID)"
echo "Press Ctrl+C to stop the kiosk"

# Wait for X server to finish
wait $X_PID

echo "Kiosk session ended"