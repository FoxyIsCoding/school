#!/bin/bash

# Quick package availability test for Raspberry Pi
echo "=== Package Availability Test ==="

# Core packages needed for kiosk
CORE_PACKAGES=(
    "python3"
    "python3-venv" 
    "chromium"
    "xorg"
    "openbox"
)

echo "Testing core packages:"
for package in "${CORE_PACKAGES[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
        echo "✓ $package - available"
    else
        echo "✗ $package - NOT available"
    fi
done

echo
echo "Testing OpenGL packages:"

# Test different OpenGL options
OPENGL_PACKAGES=(
    "libgl1"
    "libgl1-mesa-glx"
    "libgl1-mesa-dri"
    "libegl1-mesa"
    "libgles2-mesa"
)

for package in "${OPENGL_PACKAGES[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
        echo "✓ $package - available"
    else
        echo "✗ $package - not available"
    fi
done

echo
echo "System info:"
echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "Architecture: $(uname -m)"
if grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "Hardware: Raspberry Pi detected"
else
    echo "Hardware: Generic Linux system"
fi