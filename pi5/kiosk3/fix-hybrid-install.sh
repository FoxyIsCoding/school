#!/bin/bash

# Hybrid Kiosk Fix Script
# Uses normal install.sh for 'pi' user setup but runs under 'foxy' user login

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Hybrid Kiosk Installation Fix ==="
echo "This will:"
echo "1. Create 'pi' user if needed"
echo "2. Run normal install.sh for 'pi' user setup"  
echo "3. Configure 'foxy' user to auto-login and start kiosk"
echo

# Step 1: Create pi user if it doesn't exist
if ! id "pi" &>/dev/null; then
    echo "Creating 'pi' user..."
    useradd -m -s /bin/bash pi
    usermod -aG video,audio,input,render,sudo pi
    echo "pi:raspberry" | chpasswd  # Set default password
    echo "✓ Created 'pi' user with password 'raspberry'"
else
    echo "✓ User 'pi' already exists"
fi

# Step 2: Run the fast install script (no venv) for pi user
echo "Running fast kiosk installation for 'pi' user (skipping virtual environment)..."
curl -fsSL https://raw.githubusercontent.com/FoxyIsCoding/school/main/pi5/kiosk3/install-fast.sh | bash

# Check if installation succeeded
if [ ! -d "/home/pi/kiosk3" ]; then
    echo "❌ Installation failed - /home/pi/kiosk3 not found"
    exit 1
fi

echo "✓ Kiosk installed in /home/pi/kiosk3"

# Step 3: Configure 'foxy' user auto-login but run pi's kiosk
echo "Configuring 'foxy' user to auto-login and start kiosk..."

# Set up auto-login for foxy user
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin foxy --noclear %I \$TERM
EOF

# Create kiosk startup script for foxy user
cat > /home/foxy/start-kiosk.sh << 'EOF'
#!/bin/bash
# Kiosk startup script for foxy user - runs pi's kiosk

echo "Starting School Kiosk (from pi user installation)..."

# Check if kiosk should be active (during school hours)
CURRENT_TIME=$(date +%H:%M)

# Active periods - same as in the main scheduler
ACTIVE_PERIODS=(
    "07:30-08:00"
    "08:45-08:55" 
    "09:40-10:00"
    "10:45-10:55"
    "11:40-11:50"
    "12:35-12:45"
    "13:30-13:35"
    "14:20-14:25"
    "15:10-16:00"
)

# Function to check if current time is in any active period
is_active_time() {
    local current_time="$1"
    local current_minutes=$(echo "$current_time" | awk -F: '{print $1*60 + $2}')
    
    for period in "${ACTIVE_PERIODS[@]}"; do
        local start_time=$(echo "$period" | cut -d- -f1)
        local end_time=$(echo "$period" | cut -d- -f2)
        
        local start_minutes=$(echo "$start_time" | awk -F: '{print $1*60 + $2}')
        local end_minutes=$(echo "$end_time" | awk -F: '{print $1*60 + $2}')
        
        if [ $current_minutes -ge $start_minutes ] && [ $current_minutes -le $end_minutes ]; then
            return 0  # Active time
        fi
    done
    return 1  # Not active time
}

# Check if we should show kiosk now
if is_active_time "$CURRENT_TIME"; then
    echo "Current time $CURRENT_TIME is in active period - starting kiosk"
    
    # Try different kiosk methods in order of preference
    if [ -f "/home/pi/kiosk3/webview-app-simple.py" ]; then
        echo "Starting simple webview app..."
        cd /home/pi/kiosk3
        sudo -u pi python3 webview-app-simple.py
    elif [ -f "/home/pi/kiosk3/start-simple-kiosk.sh" ]; then
        echo "Starting simple kiosk script..."
        sudo -u pi /home/pi/kiosk3/start-simple-kiosk.sh
    elif command -v chromium >/dev/null; then
        echo "Starting direct chromium kiosk..."
        # Start X server
        sudo -u pi startx &
        sleep 5
        # Start chromium
        sudo -u pi DISPLAY=:0 chromium --kiosk --no-sandbox --start-fullscreen https://sokolnice.neocities.org
    else
        echo "No kiosk method available"
    fi
else
    echo "Current time $CURRENT_TIME is outside active periods"
    echo "Active periods: ${ACTIVE_PERIODS[*]}"
    echo "Kiosk will not start. Dropping to shell."
fi
EOF

chmod +x /home/foxy/start-kiosk.sh
chown foxy:foxy /home/foxy/start-kiosk.sh

# Add kiosk startup to foxy's .bashrc
cp /home/foxy/.bashrc /home/foxy/.bashrc.backup 2>/dev/null
cat >> /home/foxy/.bashrc << 'EOF'

# Auto-start kiosk on login to tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    /home/foxy/start-kiosk.sh
fi
EOF

# Step 4: Configure system for kiosk boot
echo "Configuring system boot settings..."

# Disable desktop environment
systemctl set-default multi-user.target
systemctl disable lightdm.service 2>/dev/null || true
systemctl disable gdm.service 2>/dev/null || true

# Disable kiosk systemd services (we'll start manually)
systemctl disable kiosk-scheduler.service 2>/dev/null || true
systemctl disable kiosk-xserver.service 2>/dev/null || true

# Reload systemd
systemctl daemon-reload

echo "=== Installation Complete ==="
echo
echo "✓ Created 'pi' user (password: raspberry)"
echo "✓ Installed kiosk in /home/pi/kiosk3"
echo "✓ Configured 'foxy' user auto-login" 
echo "✓ Set up time-based kiosk startup"
echo "✓ Disabled desktop environment"
echo
echo "The system will now:"
echo "1. Auto-login as 'foxy' user"
echo "2. Check if current time is in school break periods"
echo "3. Start kiosk if in active time, or drop to shell if not"
echo "4. Run kiosk from /home/pi/kiosk3 with proper permissions"
echo
echo "Active time periods:"
echo "  07:30-08:00 (Before school)"
echo "  08:45-08:55 (Break 1)"
echo "  09:40-10:00 (Break 2)"
echo "  10:45-10:55 (Break 3)"
echo "  11:40-11:50 (Break 4)"
echo "  12:35-12:45 (Break 5)"
echo "  13:30-13:35 (Break 6)"
echo "  14:20-14:25 (Break 7)"
echo "  15:10-16:00 (After school)"
echo
echo "Test manually: /home/foxy/start-kiosk.sh"
echo "Reboot to test auto-boot: sudo reboot"