#!/usr/bin/env python3
"""
School Kiosk Scheduler
Manages display activation during specific school break times
"""

import datetime
import subprocess
import time
import logging
import os
import sys

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/kiosk-scheduler.log"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

# School break time periods (24-hour format)
ACTIVE_PERIODS = [
    ("07:30", "08:00", "Before school"),
    ("08:45", "08:55", "Break 1"),
    ("09:40", "10:00", "Break 2"),
    ("10:45", "10:55", "Break 3"),
    ("11:40", "11:50", "Break 4"),
    ("12:35", "12:45", "Break 5"),
    ("13:30", "13:35", "Break 6"),
    ("14:20", "14:25", "Break 7"),
    ("15:10", "16:00", "After school"),
]


class KioskScheduler:
    def __init__(self):
        self.display_on = False
        self.webview_process = None
        self.x_server_process = None

    def is_time_in_period(self, current_time, start_time, end_time):
        """Check if current time is within the specified period"""
        current = datetime.datetime.strptime(current_time, "%H:%M").time()
        start = datetime.datetime.strptime(start_time, "%H:%M").time()
        end = datetime.datetime.strptime(end_time, "%H:%M").time()

        return start <= current <= end

    def should_be_active(self):
        """Check if kiosk should be active based on current time"""
        now = datetime.datetime.now().strftime("%H:%M")

        for start_time, end_time, period_name in ACTIVE_PERIODS:
            if self.is_time_in_period(now, start_time, end_time):
                return True, period_name

        return False, None

    def turn_on_display(self):
        """Turn on the display"""
        try:
            # Turn on display using DPMS
            subprocess.run(
                ["xset", "dpms", "force", "on"], env={"DISPLAY": ":0"}, check=True
            )
            logger.info("Display turned ON")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to turn on display: {e}")
            return False

    def turn_off_display(self):
        """Turn off the display"""
        try:
            # Turn off display using DPMS
            subprocess.run(
                ["xset", "dpms", "force", "off"], env={"DISPLAY": ":0"}, check=True
            )
            logger.info("Display turned OFF")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to turn off display: {e}")
            return False

    def start_x_server(self):
        """Start minimal X server if not running"""
        try:
            # Check if X server is already running
            result = subprocess.run(["pgrep", "Xorg"], capture_output=True)
            if result.returncode == 0:
                logger.info("X server already running")
                return True

            # Start X server
            self.x_server_process = subprocess.Popen(
                ["startx", "/home/pi/kiosk3/start-kiosk.sh", "--", ":0", "vt1"]
            )
            time.sleep(3)  # Wait for X server to start
            logger.info("X server started")
            return True
        except Exception as e:
            logger.error(f"Failed to start X server: {e}")
            return False

    def start_webview(self):
        """Start the WebView application"""
        try:
            if self.webview_process and self.webview_process.poll() is None:
                logger.info("WebView already running")
                return True

            # Start WebView application
            self.webview_process = subprocess.Popen(
                ["python3", "/home/pi/kiosk3/webview-app.py"], env={"DISPLAY": ":0"}
            )

            logger.info("WebView application started")
            return True
        except Exception as e:
            logger.error(f"Failed to start WebView: {e}")
            return False

    def stop_webview(self):
        """Stop the WebView application"""
        try:
            if self.webview_process and self.webview_process.poll() is None:
                self.webview_process.terminate()
                self.webview_process.wait(timeout=5)
                logger.info("WebView application stopped")
        except Exception as e:
            logger.error(f"Failed to stop WebView: {e}")

    def activate_kiosk(self, period_name):
        """Activate the kiosk display"""
        if self.display_on:
            return

        logger.info(f"Activating kiosk for period: {period_name}")

        # Start X server if needed
        if not self.start_x_server():
            return

        # Turn on display
        if not self.turn_on_display():
            return

        # Start WebView
        if not self.start_webview():
            return

        self.display_on = True
        logger.info("Kiosk activated successfully")

    def deactivate_kiosk(self):
        """Deactivate the kiosk display"""
        if not self.display_on:
            return

        logger.info("Deactivating kiosk")

        # Stop WebView
        self.stop_webview()

        # Turn off display
        self.turn_off_display()

        self.display_on = False
        logger.info("Kiosk deactivated")

    def run(self):
        """Main scheduler loop"""
        logger.info("Kiosk scheduler started")

        while True:
            try:
                should_be_active, period_name = self.should_be_active()

                if should_be_active and not self.display_on:
                    self.activate_kiosk(period_name)
                elif not should_be_active and self.display_on:
                    self.deactivate_kiosk()

                # Check every 30 seconds
                time.sleep(30)

            except KeyboardInterrupt:
                logger.info("Scheduler stopped by user")
                break
            except Exception as e:
                logger.error(f"Scheduler error: {e}")
                time.sleep(60)  # Wait longer on error

        # Cleanup on exit
        self.deactivate_kiosk()


if __name__ == "__main__":
    scheduler = KioskScheduler()
    scheduler.run()
