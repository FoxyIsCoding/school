#!/bin/bash

# Kiosk Boot Diagnostic Script
echo "=== Kiosk Boot Diagnostic ==="
echo "Date: $(date)"
echo

echo "=== Service Status ==="
echo "Kiosk Scheduler Service:"
systemctl status kiosk-scheduler.service --no-pager || echo "Service not found"
echo

echo "Kiosk X Server Service:"
systemctl status kiosk-xserver.service --no-pager || echo "Service not found"
echo

echo "=== Auto-login Configuration ==="
echo "Getty override for auto-login:"
if [ -f "/etc/systemd/system/getty@tty1.service.d/override.conf" ]; then
    echo "Found auto-login configuration:"
    cat /etc/systemd/system/getty@tty1.service.d/override.conf
else
    echo "❌ Auto-login NOT configured"
fi
echo

echo "=== Desktop Manager Status ==="
echo "Desktop manager services:"
systemctl list-units --type=service | grep -E "(desktop|display|lightdm|gdm)" || echo "No desktop managers found"
echo

echo "=== Boot Target ==="
echo "Current systemd target:"
systemctl get-default
echo

echo "=== Kiosk Files ==="
echo "Kiosk directory contents:"
ls -la /home/pi/kiosk3/ 2>/dev/null || echo "❌ Kiosk directory not found"
echo

echo "=== X11 Configuration ==="
echo "Kiosk X11 config:"
if [ -f "/etc/X11/xorg.conf.d/99-kiosk.conf" ]; then
    echo "✓ Kiosk X11 config found"
else
    echo "❌ Kiosk X11 config missing"
fi
echo

echo "=== Process Check ==="
echo "Running kiosk processes:"
pgrep -f "kiosk" || echo "No kiosk processes running"
echo

echo "=== Boot Mode Recommendations ==="
if systemctl is-enabled kiosk-scheduler.service >/dev/null 2>&1; then
    echo "✓ Kiosk scheduler service is enabled"
else
    echo "❌ Kiosk scheduler service is NOT enabled"
    echo "   Fix: sudo systemctl enable kiosk-scheduler.service"
fi

if [ -f "/etc/systemd/system/getty@tty1.service.d/override.conf" ]; then
    echo "✓ Auto-login is configured"
else
    echo "❌ Auto-login is NOT configured"
    echo "   Fix: Need to disable desktop and enable auto-login"
fi

if systemctl get-default | grep -q "graphical.target"; then
    echo "❌ System targets graphical desktop mode"
    echo "   Fix: sudo systemctl set-default multi-user.target"
else
    echo "✓ System uses text mode target"
fi