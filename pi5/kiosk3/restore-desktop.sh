#!/bin/bash

# Recovery Script - Return to Normal Desktop Boot
# Run this if you need to get back to the normal Pi desktop

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Restoring Normal Desktop Boot ==="

# 1. Re-enable desktop environment
echo "Re-enabling desktop environment..."
systemctl set-default graphical.target
systemctl enable lightdm.service 2>/dev/null || systemctl enable gdm.service 2>/dev/null

# 2. Remove auto-login configuration
echo "Removing auto-login..."
rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
rmdir /etc/systemd/system/getty@tty1.service.d 2>/dev/null

# 3. Clean up user bashrc
echo "Cleaning up user startup..."
cp /home/pi/.bashrc /home/pi/.bashrc.backup 2>/dev/null
cat > /home/pi/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 and umask are already set in /etc/profile. You should not
# need this unless you want different defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

# You may uncomment the following lines if you want `ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "`dircolors`"
# alias ls='ls $LS_OPTIONS'
# alias ll='ls $LS_OPTIONS -l'
# alias l='ls $LS_OPTIONS -lA'

# Some more alias to avoid making mistakes:
# alias rm='rm -i'
# alias cp='cp -i'
# alias mv='mv -i'
EOF

chown pi:pi /home/pi/.bashrc

# 4. Reload systemd
systemctl daemon-reload

echo "=== Recovery Complete ==="
echo "The system will now boot to the normal Pi OS desktop."
echo "Reboot now: sudo reboot"