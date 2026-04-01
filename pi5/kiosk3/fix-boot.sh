#!/bin/bash

# Kiosk Boot Fix Script
# Configures system to boot directly into kiosk mode

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Configuring System for Kiosk Boot ==="

# 1. Disable desktop environment auto-start
echo "Step 1: Disabling desktop environment..."
systemctl set-default multi-user.target
systemctl disable lightdm.service 2>/dev/null || true
systemctl disable gdm.service 2>/dev/null || true
systemctl disable sddm.service 2>/dev/null || true

# 2. Configure automatic login to pi user
echo "Step 2: Configuring automatic login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

# 3. Create user startup script that launches kiosk
echo "Step 3: Creating user kiosk startup..."
cat > /home/pi/.bashrc << 'EOF'
# Auto-start kiosk on login to tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    # Wait for system to be ready
    sleep 2
    
    # Start kiosk scheduler
    if [ -f "/home/pi/kiosk3/kiosk-scheduler.py" ]; then
        echo "Starting school kiosk..."
        cd /home/pi/kiosk3
        python3 kiosk-scheduler.py
    else
        echo "Kiosk files not found, starting basic kiosk..."
        # Fallback: start X server with chromium
        startx /home/pi/kiosk3/start-chromium-kiosk.sh 2>/dev/null &
    fi
fi
EOF

# 4. Create simple chromium kiosk startup script
echo "Step 4: Creating fallback chromium startup..."
cat > /home/pi/kiosk3/start-chromium-kiosk.sh << 'EOF'
#!/bin/bash
# Simple chromium kiosk startup

# Configure X
xset s off
xset -dpms
xset s noblank
unclutter -idle 0.5 -root &

# Start window manager
openbox-session &
sleep 2

# Start chromium in kiosk mode
chromium --kiosk --no-sandbox --disable-infobars --start-fullscreen https://sokolnice.neocities.org
EOF

chmod +x /home/pi/kiosk3/start-chromium-kiosk.sh

# 5. Ensure kiosk services are enabled but don't auto-start (we'll start manually)
echo "Step 5: Configuring kiosk services..."
systemctl disable kiosk-scheduler.service 2>/dev/null || true
systemctl disable kiosk-xserver.service 2>/dev/null || true

# 6. Set proper permissions
chown -R pi:pi /home/pi

echo "=== Boot Configuration Complete ==="
echo
echo "The system will now:"
echo "1. Boot to text mode (no desktop)"
echo "2. Auto-login as user 'pi'"
echo "3. Automatically start the kiosk display"
echo
echo "Reboot now to test: sudo reboot"