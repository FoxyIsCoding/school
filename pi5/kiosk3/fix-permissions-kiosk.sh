#!/bin/bash

# Permission-Fixed Kiosk Starter
# Handles console permission issues

echo "=== Permission-Fixed Kiosk Starter ==="

# Check if we're running from a desktop environment
if [ ! -z "$DISPLAY" ]; then
    echo "✓ Running in desktop environment, starting kiosk directly..."
    cd ~/kiosk3 2>/dev/null || cd /home/pi/kiosk3 2>/dev/null || cd /home/foxy/kiosk3
    python3 webview-app-simple.py
    exit
fi

# Method 1: Try to use existing X session on :0
echo "Trying to connect to existing X session..."
export DISPLAY=:0
if xset q >/dev/null 2>&1; then
    echo "✓ Found existing X session on :0"
    cd ~/kiosk3 2>/dev/null || cd /home/pi/kiosk3 2>/dev/null || cd /home/foxy/kiosk3
    python3 webview-app-simple.py
    exit
fi

# Method 2: Start X server without specifying console (let it choose)
echo "Starting X server with automatic console selection..."
cat > /tmp/kiosk-session.sh << 'EOF'
#!/bin/bash
export DISPLAY=:0

# Wait for X to be ready
sleep 3

# Configure X
xset s off 2>/dev/null
xset -dpms 2>/dev/null
xset s noblank 2>/dev/null

# Start window manager
openbox-session &
sleep 2

# Find and start kiosk
for dir in ~/kiosk3 /home/pi/kiosk3 /home/foxy/kiosk3; do
    if [ -d "$dir" ]; then
        cd "$dir"
        break
    fi
done

if [ -f "webview-app-simple.py" ]; then
    python3 webview-app-simple.py
else
    chromium --kiosk --no-sandbox --start-fullscreen https://sokolnice.neocities.org
fi
EOF

chmod +x /tmp/kiosk-session.sh

# Try starting X without specifying vt
echo "Method 2a: X server with auto-console..."
startx /tmp/kiosk-session.sh 2>/dev/null &
X_PID=$!
sleep 5

# Check if X started
if kill -0 $X_PID 2>/dev/null; then
    echo "✓ X server started successfully"
    wait $X_PID
    exit
else
    echo "✗ X server failed to start"
fi

# Method 3: Try with sudo for console access
echo "Method 3: Using sudo for console access..."
cat > /tmp/sudo-kiosk.sh << 'EOF'
#!/bin/bash

# Add user to video group if not already
usermod -a -G video,input,render foxy 2>/dev/null

# Start X server with proper permissions
sudo -u foxy startx /tmp/kiosk-session.sh -- :0 vt1 2>/dev/null &
X_PID=$!

echo "X server PID: $X_PID"
sleep 3

# Check if running
if ps -p $X_PID > /dev/null; then
    echo "X server running, waiting..."
    wait $X_PID
else
    echo "X server failed"
fi
EOF

chmod +x /tmp/sudo-kiosk.sh
sudo /tmp/sudo-kiosk.sh

# Method 4: Direct framebuffer approach (last resort)
echo "Method 4: Direct framebuffer kiosk..."
cat > /tmp/fb-kiosk.sh << 'EOF'
#!/bin/bash

# Try direct framebuffer chromium
echo "Starting framebuffer chromium..."
chromium --kiosk --no-sandbox --use-gl=egl --enable-features=VaapiVideoDecoder --disable-dev-shm-usage https://sokolnice.neocities.org 2>/dev/null &

CHROMIUM_PID=$!
echo "Chromium PID: $CHROMIUM_PID"

# Keep running until Ctrl+C
trap "kill $CHROMIUM_PID 2>/dev/null; exit" INT TERM
wait $CHROMIUM_PID
EOF

chmod +x /tmp/fb-kiosk.sh
/tmp/fb-kiosk.sh