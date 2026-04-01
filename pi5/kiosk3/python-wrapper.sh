#!/bin/bash

# Kiosk Python Wrapper
# This script ensures Python applications use the virtual environment

KIOSK_DIR="/home/pi/kiosk3"
VENV_DIR="$KIOSK_DIR/venv"

# Check if virtual environment exists and has PyQt5
if [ -f "$VENV_DIR/bin/python" ] && [ -f "$VENV_DIR/bin/pip" ]; then
    # Test if PyQt5 is available in venv
    if "$VENV_DIR/bin/python" -c "import PyQt5.QtWebEngineWidgets" 2>/dev/null; then
        echo "Using virtual environment Python with PyQt5"
        exec "$VENV_DIR/bin/python" "$@"
    fi
fi

# Fallback to system Python
echo "Using system Python (virtual environment not available or no PyQt5)"
exec python3 "$@"