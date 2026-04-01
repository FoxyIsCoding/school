#!/bin/bash

# Display Power Management Utility
# Provides functions to control display power state

LOGFILE="/var/log/display-power.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Function to turn display on
display_on() {
    log_message "Turning display ON"
    
    # Method 1: Use xset (most common)
    if command -v xset >/dev/null 2>&1; then
        DISPLAY=:0 xset dpms force on
        DISPLAY=:0 xset -dpms
        DISPLAY=:0 xset s off
        log_message "Display turned on via xset"
        return 0
    fi
    
    # Method 2: Use vcgencmd (Raspberry Pi specific)
    if command -v vcgencmd >/dev/null 2>&1; then
        vcgencmd display_power 1
        log_message "Display turned on via vcgencmd"
        return 0
    fi
    
    # Method 3: Use tvservice (Raspberry Pi specific)
    if command -v tvservice >/dev/null 2>&1; then
        tvservice -p
        # Re-initialize framebuffer
        fbset -depth 8 && fbset -depth 16
        log_message "Display turned on via tvservice"
        return 0
    fi
    
    log_message "ERROR: No display control method available"
    return 1
}

# Function to turn display off
display_off() {
    log_message "Turning display OFF"
    
    # Method 1: Use xset (most common)
    if command -v xset >/dev/null 2>&1; then
        DISPLAY=:0 xset dpms force off
        log_message "Display turned off via xset"
        return 0
    fi
    
    # Method 2: Use vcgencmd (Raspberry Pi specific)
    if command -v vcgencmd >/dev/null 2>&1; then
        vcgencmd display_power 0
        log_message "Display turned off via vcgencmd"
        return 0
    fi
    
    # Method 3: Use tvservice (Raspberry Pi specific)
    if command -v tvservice >/dev/null 2>&1; then
        tvservice -o
        log_message "Display turned off via tvservice"
        return 0
    fi
    
    log_message "ERROR: No display control method available"
    return 1
}

# Function to check display status
display_status() {
    # Check if X server is running
    if pgrep Xorg >/dev/null 2>&1; then
        log_message "X server is running"
        
        # Check DPMS status if xset is available
        if command -v xset >/dev/null 2>&1; then
            DISPLAY=:0 xset q | grep -A 5 "DPMS"
        fi
    else
        log_message "X server is not running"
    fi
    
    # Check Raspberry Pi specific display status
    if command -v vcgencmd >/dev/null 2>&1; then
        POWER_STATUS=$(vcgencmd display_power)
        log_message "Display power status: $POWER_STATUS"
    fi
}

# Function to setup display power management
setup_display_power() {
    log_message "Setting up display power management"
    
    # Create systemd service for display management
    cat > /tmp/display-power.service << EOF
[Unit]
Description=Display Power Management Service
After=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$0 setup
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    # Install the service
    if [ -w /etc/systemd/system/ ]; then
        cp /tmp/display-power.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable display-power.service
        log_message "Display power management service installed"
    else
        log_message "ERROR: Cannot install systemd service (insufficient permissions)"
    fi
}

# Main script logic
case "$1" in
    "on")
        display_on
        ;;
    "off")
        display_off
        ;;
    "status")
        display_status
        ;;
    "setup")
        setup_display_power
        ;;
    *)
        echo "Usage: $0 {on|off|status|setup}"
        echo "  on     - Turn display on"
        echo "  off    - Turn display off"
        echo "  status - Show display status"
        echo "  setup  - Setup display power management service"
        exit 1
        ;;
esac

exit $?