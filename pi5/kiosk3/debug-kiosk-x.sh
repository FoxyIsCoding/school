#!/bin/bash

# Debug X Server Kiosk Starter
# Shows detailed output about what's happening

echo "=== DEBUG: Starting Kiosk with X Server ==="

# Function to cleanup on exit
cleanup() {
    echo "DEBUG: Cleanup called..."
    if [ ! -z "$KIOSK_PID" ]; then
        echo "DEBUG: Killing kiosk PID $KIOSK_PID"
        kill $KIOSK_PID 2>/dev/null
    fi
    if [ ! -z "$X_PID" ]; then
        echo "DEBUG: Killing X server PID $X_PID"
        kill $X_PID 2>/dev/null
    fi
}

trap cleanup EXIT INT TERM

# Check current environment
echo "DEBUG: Current user: $(whoami)"
echo "DEBUG: Current directory: $(pwd)"
echo "DEBUG: DISPLAY variable: $DISPLAY"

# Check if we're already in X
if [ ! -z "$DISPLAY" ] && xset q >/dev/null 2>&1; then
    echo "DEBUG: X server already running on $DISPLAY"
    
    # Find kiosk directory
    if [ -d "~/kiosk3" ]; then
        KIOSK_DIR="~/kiosk3"
    elif [ -d "/home/pi/kiosk3" ]; then
        KIOSK_DIR="/home/pi/kiosk3"
    elif [ -d "/home/foxy/kiosk3" ]; then
        KIOSK_DIR="/home/foxy/kiosk3"
    else
        echo "ERROR: Cannot find kiosk directory"
        exit 1
    fi
    
    echo "DEBUG: Using kiosk directory: $KIOSK_DIR"
    cd "$KIOSK_DIR"
    echo "DEBUG: Starting kiosk on existing X session..."
    python3 webview-app-simple.py
    exit
fi

# We need to start X server ourselves
echo "DEBUG: No X server detected, need to start new X session..."

# Kill any existing X servers
echo "DEBUG: Killing any existing X servers..."
sudo pkill Xorg 2>/dev/null
sleep 2

# Find kiosk directory
if [ -d "/home/pi/kiosk3" ]; then
    KIOSK_DIR="/home/pi/kiosk3"
elif [ -d "/home/foxy/kiosk3" ]; then
    KIOSK_DIR="/home/foxy/kiosk3"
elif [ -d "$(pwd)/kiosk3" ]; then
    KIOSK_DIR="$(pwd)/kiosk3"
else
    echo "ERROR: Cannot find kiosk directory"
    echo "DEBUG: Checked directories:"
    echo "  - /home/pi/kiosk3"
    echo "  - /home/foxy/kiosk3"
    echo "  - $(pwd)/kiosk3"
    exit 1
fi

echo "DEBUG: Found kiosk directory: $KIOSK_DIR"

# Create detailed X startup script
cat > /tmp/start-kiosk-x-debug.sh << EOF
#!/bin/bash

echo "DEBUG: X startup script running..."
echo "DEBUG: User in X session: \$(whoami)"
echo "DEBUG: Display: \$DISPLAY"
echo "DEBUG: Kiosk directory: $KIOSK_DIR"

# Configure X environment
export DISPLAY=:0
echo "DEBUG: Set DISPLAY to :0"

# Test X server
if xset q >/dev/null 2>&1; then
    echo "DEBUG: X server responding"
else
    echo "ERROR: X server not responding"
    exit 1
fi

# Configure X settings
echo "DEBUG: Configuring X settings..."
xset s off
xset -dpms
xset s noblank
xsetroot -solid black

# Hide cursor
echo "DEBUG: Starting unclutter..."
unclutter -idle 1 -root &

# Start window manager
echo "DEBUG: Starting openbox..."
openbox-session &
sleep 3

# Test if openbox started
if pgrep openbox >/dev/null; then
    echo "DEBUG: Openbox started successfully"
else
    echo "WARNING: Openbox may not have started"
fi

# Change to kiosk directory
echo "DEBUG: Changing to kiosk directory: $KIOSK_DIR"
cd "$KIOSK_DIR" || {
    echo "ERROR: Cannot change to kiosk directory"
    exit 1
}

# List files in kiosk directory
echo "DEBUG: Files in kiosk directory:"
ls -la

# Check if kiosk app exists
if [ -f "webview-app-simple.py" ]; then
    echo "DEBUG: Found webview-app-simple.py, starting..."
    python3 webview-app-simple.py
    echo "DEBUG: webview-app-simple.py exited with code: \$?"
else
    echo "ERROR: webview-app-simple.py not found"
    echo "DEBUG: Available Python files:"
    ls -la *.py
    
    # Fallback to direct chromium
    echo "DEBUG: Trying direct chromium fallback..."
    chromium --kiosk --no-sandbox --start-fullscreen https://sokolnice.neocities.org &
    CHROMIUM_PID=\$!
    echo "DEBUG: Chromium started with PID: \$CHROMIUM_PID"
    wait \$CHROMIUM_PID
    echo "DEBUG: Chromium exited with code: \$?"
fi

echo "DEBUG: X startup script ending..."
EOF

chmod +x /tmp/start-kiosk-x-debug.sh

# Start X server with our kiosk session
echo "DEBUG: Starting X server with debug kiosk session..."
echo "DEBUG: Command: startx /tmp/start-kiosk-x-debug.sh -- :0 vt7"

# Redirect X server output to see errors
startx /tmp/start-kiosk-x-debug.sh -- :0 vt7 > /tmp/xserver.log 2>&1 &
X_PID=$!

echo "DEBUG: X server started with PID: $X_PID"
echo "DEBUG: X server log will be in /tmp/xserver.log"
echo "DEBUG: Press Ctrl+C to stop the kiosk"

# Wait for X server to finish
wait $X_PID
X_EXIT_CODE=$?

echo "DEBUG: X server exited with code: $X_EXIT_CODE"

# Show logs
echo "=== X SERVER LOG ==="
cat /tmp/xserver.log 2>/dev/null || echo "No X server log found"

echo "DEBUG: Kiosk session ended"