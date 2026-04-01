# School Kiosk Display System

An automated kiosk system for Raspberry Pi that displays a website during specific school break times and turns off the display when not in use.

## Features

- **Time-based activation**: Automatically turns on during school break periods
- **Power management**: Turns off display when not in use to save energy
- **Full-screen WebView**: Displays https://sokolnice.neocities.org in kiosk mode
- **Auto-start**: Boots directly into kiosk mode
- **Minimal X server**: Lightweight display server without desktop environment
- **Robust scheduling**: Python-based scheduler with logging and error handling

## Active Time Periods

The kiosk activates during these times:
- 07:30-08:00 (Before school)
- 08:45-08:55 (Break 1)
- 09:40-10:00 (Break 2)
- 10:45-10:55 (Break 3)
- 11:40-11:50 (Break 4)
- 12:35-12:45 (Break 5)
- 13:30-13:35 (Break 6)
- 14:20-14:25 (Break 7)
- 15:10-16:00 (After school)

## Quick Install

Run this command on your Raspberry Pi:

```bash
curl -fsSL https://raw.githubusercontent.com/FoxyIsCoding/school/main/pi5/kiosk3/install.sh | sudo bash
```

After installation, reboot the system:

```bash
sudo reboot
```

## What the Install Script Does

1. **System Updates**: Updates all packages
2. **Package Installation**: Installs Python, PyQt5, X server, and dependencies
3. **User Setup**: Configures the `pi` user for kiosk operation
4. **Service Installation**: Sets up systemd services for auto-start
5. **Display Configuration**: Configures X server for kiosk mode
6. **Boot Optimization**: Optimizes boot settings for faster startup
7. **Log Management**: Sets up log rotation and monitoring

## Manual Installation

If you prefer to install manually:

```bash
# Clone the repository
git clone https://github.com/FoxyIsCoding/school.git
cd school/pi5/kiosk3

# Run the install script
sudo ./install.sh
```

## System Requirements

- Raspberry Pi (3B+ or newer recommended)
- Raspberry Pi OS (Bullseye or newer)
- Internet connection for initial setup
- HDMI display

## File Structure

```
/home/pi/kiosk3/
├── kiosk-scheduler.py      # Main scheduler script
├── webview-app.py          # WebView application
├── start-kiosk.sh          # X server startup script
├── display-power.sh        # Display power management
├── install.sh              # Installation script
├── status.sh               # Status check script
├── uninstall.sh            # Uninstall script
├── xorg-kiosk.conf         # X server configuration
├── kiosk-scheduler.service # Systemd service for scheduler
└── kiosk-xserver.service   # Systemd service for X server
```

## Management Commands

### Check Status
```bash
/home/pi/kiosk3/status.sh
```

### View Logs
```bash
# Scheduler logs
sudo tail -f /var/log/kiosk-scheduler.log

# WebView logs
sudo tail -f /var/log/kiosk-webview.log

# Installation log
sudo cat /var/log/kiosk-install.log
```

### Manual Control
```bash
# Start/stop services
sudo systemctl start kiosk-scheduler
sudo systemctl stop kiosk-scheduler

# Enable/disable auto-start
sudo systemctl enable kiosk-scheduler
sudo systemctl disable kiosk-scheduler

# Display power control
/home/pi/kiosk3/display-power.sh on
/home/pi/kiosk3/display-power.sh off
/home/pi/kiosk3/display-power.sh status
```

## Customization

### Change Website URL
Edit `/home/pi/kiosk3/webview-app.py` and modify the `KIOSK_URL` variable:

```python
KIOSK_URL = "https://your-website.com"
```

### Modify Time Periods
Edit `/home/pi/kiosk3/kiosk-scheduler.py` and update the `ACTIVE_PERIODS` list:

```python
ACTIVE_PERIODS = [
    ("07:30", "08:00", "Before school"),
    # Add or modify time periods here
]
```

### Change Refresh Interval
Edit the refresh timer in `/home/pi/kiosk3/webview-app.py`:

```python
self.refresh_timer.start(5 * 60 * 1000)  # 5 minutes
```

## Troubleshooting

### Kiosk Not Starting
```bash
# Check service status
sudo systemctl status kiosk-scheduler
sudo systemctl status kiosk-xserver

# Check logs
sudo journalctl -u kiosk-scheduler -f
```

### Display Issues
```bash
# Check X server
ps aux | grep Xorg

# Test display power
/home/pi/kiosk3/display-power.sh status
```

### Network Issues
```bash
# Test internet connectivity
ping -c 4 google.com

# Check if website is accessible
curl -I https://sokolnice.neocities.org
```

## Uninstall

To completely remove the kiosk system:

```bash
sudo /home/pi/kiosk3/uninstall.sh
sudo reboot
```

## Security Features

- Disabled keyboard shortcuts that could exit kiosk mode
- No access to desktop environment or file browser
- Automatic cursor hiding
- Blocked common escape key combinations
- Read-only operation during kiosk mode

## Performance Optimization

- Minimal X server configuration
- Disabled unnecessary services
- Optimized boot parameters
- Automatic log rotation
- Memory-efficient WebView settings

## License

MIT License - see LICENSE file for details

## Support

For issues and support, please check the logs first and then create an issue in this repository with:
- Raspberry Pi model and OS version
- Error messages from logs
- Steps to reproduce the problem