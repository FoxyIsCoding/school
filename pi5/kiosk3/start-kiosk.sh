#!/bin/bash

# Kiosk X Server Startup Script
# This script configures and starts the minimal kiosk environment

# Set environment variables
export DISPLAY=:0
export HOME=/home/pi

# Configure X server settings
xset s off         # Disable screen saver
xset -dpms         # Disable DPMS (Display Power Management Signaling)
xset s noblank     # Don't blank the video device

# Hide cursor
unclutter -idle 0.5 -root &

# Set background to black
xsetroot -solid black

# Disable various X11 features that might interfere
xset r off  # Disable key repeat

# Start window manager (minimal)
openbox-session &

# Wait a moment for everything to initialize
sleep 2

# Keep the script running
wait