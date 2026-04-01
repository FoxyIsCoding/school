#!/bin/bash

# Emergency Kiosk Debug Script
# Run this when you get the blank screen with cursor

echo "=== EMERGENCY KIOSK DEBUG ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "TTY: $(tty)"
echo

# Check if we're in the right place
echo "=== Current Status ==="
echo "Current directory: $(pwd)"
echo "Home directory: $HOME"
echo

# Check kiosk files
echo "=== Kiosk Files Check ==="
if [ -d "/home/pi/kiosk3" ]; then
    echo "✓ Kiosk directory exists"
    echo "Contents:"
    ls -la /home/pi/kiosk3/
    echo
    
    # Check if scripts are executable
    if [ -x "/home/pi/kiosk3/kiosk-scheduler.py" ]; then
        echo "✓ kiosk-scheduler.py is executable"
    else
        echo "❌ kiosk-scheduler.py not executable"
        chmod +x /home/pi/kiosk3/kiosk-scheduler.py 2>/dev/null
    fi
    
    if [ -x "/home/pi/kiosk3/python-wrapper.sh" ]; then
        echo "✓ python-wrapper.sh is executable"
    else
        echo "❌ python-wrapper.sh not executable"
        chmod +x /home/pi/kiosk3/python-wrapper.sh 2>/dev/null
    fi
else
    echo "❌ Kiosk directory /home/pi/kiosk3 does not exist!"
fi
echo

# Check Python environment
echo "=== Python Environment ==="
echo "System Python: $(which python3)"
if [ -f "/home/pi/kiosk3/venv/bin/python" ]; then
    echo "✓ Virtual environment exists"
    echo "Venv Python: /home/pi/kiosk3/venv/bin/python"
    
    # Test PyQt5 in venv
    if /home/pi/kiosk3/venv/bin/python -c "import PyQt5" 2>/dev/null; then
        echo "✓ PyQt5 available in venv"
    else
        echo "❌ PyQt5 NOT available in venv"
    fi
else
    echo "❌ Virtual environment does not exist"
fi

# Test system PyQt5
if python3 -c "import PyQt5" 2>/dev/null; then
    echo "✓ PyQt5 available in system Python"
else
    echo "❌ PyQt5 NOT available in system Python"
fi
echo

# Check X server capability
echo "=== Display/X Server Check ==="
echo "DISPLAY variable: $DISPLAY"

# Test if we can start X
if command -v startx >/dev/null; then
    echo "✓ startx command available"
else
    echo "❌ startx command not found"
fi

if command -v chromium >/dev/null; then
    echo "✓ chromium available"
else
    echo "❌ chromium not found"
fi
echo

# Check for error logs
echo "=== Error Logs ==="
if [ -f "/var/log/kiosk-scheduler.log" ]; then
    echo "Kiosk scheduler log (last 10 lines):"
    tail -10 /var/log/kiosk-scheduler.log
else
    echo "No kiosk scheduler log found"
fi
echo

if [ -f "/var/log/kiosk-webview.log" ]; then
    echo "Kiosk webview log (last 10 lines):"
    tail -10 /var/log/kiosk-webview.log
else
    echo "No kiosk webview log found"
fi
echo

echo "=== Quick Fixes to Try ==="
echo "1. Manual start kiosk:"
echo "   cd /home/pi/kiosk3 && python3 kiosk-scheduler.py"
echo
echo "2. Start simple chromium kiosk:"
echo "   startx /home/pi/kiosk3/start-chromium-kiosk.sh"
echo
echo "3. Test basic X server:"
echo "   startx"
echo
echo "4. Return to desktop mode:"
echo "   sudo systemctl set-default graphical.target && sudo reboot"
echo

# Try to auto-fix common issues
echo "=== Auto-fixing Common Issues ==="
cd /home/pi/kiosk3 2>/dev/null || {
    echo "❌ Cannot change to kiosk directory"
    exit 1
}

# Make scripts executable
chmod +x *.py *.sh 2>/dev/null && echo "✓ Made scripts executable"

# Check if we should try to start something
echo
echo "=== Attempting Auto-Start ==="
echo "Waiting 3 seconds, then trying to start kiosk..."
sleep 3

# Try the simplest approach first
if command -v chromium >/dev/null && command -v startx >/dev/null; then
    echo "Starting simple chromium kiosk..."
    exec startx /home/pi/kiosk3/start-chromium-kiosk.sh
else
    echo "Cannot start kiosk - missing dependencies"
fi