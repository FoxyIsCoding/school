#!/usr/bin/env python3
"""
Simple Kiosk WebView Application
Chromium-based kiosk for maximum compatibility
"""

import sys
import os
import logging
import subprocess
import signal
import time
import shlex

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/kiosk-webview.log"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

# Website URL to display
KIOSK_URL = "https://sokolnice.neocities.org"


class SimpleChromiumKiosk:
    """Simple Chromium-based kiosk implementation"""

    def __init__(self):
        self.process = None

    def find_chromium(self):
        """Find available chromium executable"""
        commands = [
            "chromium",
            "chromium-browser",
            "google-chrome",
            "google-chrome-stable",
            "/usr/bin/chromium",
            "/usr/bin/chromium-browser",
        ]

        for cmd in commands:
            try:
                result = subprocess.run(["which", cmd], capture_output=True, text=True)
                if result.returncode == 0:
                    logger.info(f"Found chromium at: {cmd}")
                    return cmd
            except:
                continue

        # Try direct path check
        for cmd in commands:
            if os.path.isfile(cmd) and os.access(cmd, os.X_OK):
                logger.info(f"Found chromium executable: {cmd}")
                return cmd

        return None

    def start(self):
        """Start Chromium in kiosk mode"""
        try:
            chromium_cmd = self.find_chromium()
            if not chromium_cmd:
                logger.error("No chromium executable found")
                return False

            # Create user data directory
            user_data_dir = "/tmp/kiosk-chromium-data"
            os.makedirs(user_data_dir, exist_ok=True)

            # Chromium kiosk arguments - simplified for maximum compatibility
            args = [
                chromium_cmd,
                "--kiosk",
                "--no-sandbox",
                "--disable-web-security",
                "--disable-extensions",
                "--disable-plugins",
                "--disable-infobars",
                "--disable-session-crashed-bubble",
                "--disable-restore-session-state",
                "--no-first-run",
                "--autoplay-policy=no-user-gesture-required",
                "--window-position=0,0",
                "--start-fullscreen",
                "--disable-dev-shm-usage",
                f"--user-data-dir={user_data_dir}",
                KIOSK_URL,
            ]

            logger.info(f"Starting Chromium kiosk with command: {' '.join(args)}")

            env = os.environ.copy()
            env["DISPLAY"] = ":0"

            self.process = subprocess.Popen(
                args,
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid,  # Create new process group
            )

            # Wait a moment to see if it started successfully
            time.sleep(2)
            if self.process.poll() is not None:
                # Process exited early, check stderr
                stderr_output = self.process.stderr.read().decode(
                    "utf-8", errors="ignore"
                )
                logger.error(f"Chromium exited early. Stderr: {stderr_output}")
                return False

            logger.info("Chromium kiosk started successfully")
            return True

        except Exception as e:
            logger.error(f"Failed to start Chromium: {e}")
            return False

    def stop(self):
        """Stop Chromium"""
        if self.process:
            try:
                # Kill entire process group
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
                self.process.wait(timeout=5)
                logger.info("Chromium stopped successfully")
            except subprocess.TimeoutExpired:
                logger.warn("Chromium did not stop gracefully, killing...")
                os.killpg(os.getpgid(self.process.pid), signal.SIGKILL)
            except Exception as e:
                logger.error(f"Error stopping Chromium: {e}")
                try:
                    self.process.kill()
                except:
                    pass

    def is_running(self):
        """Check if Chromium is running"""
        return self.process and self.process.poll() is None

    def wait(self):
        """Wait for Chromium to exit"""
        if self.process:
            return self.process.wait()
        return 0


class KioskManager:
    """Manages the kiosk display"""

    def __init__(self):
        self.kiosk = None

    def start(self):
        """Start kiosk display"""
        logger.info("Starting kiosk display...")

        self.kiosk = SimpleChromiumKiosk()
        if not self.kiosk.start():
            logger.error("Failed to start kiosk display")
            return 1

        try:
            # Keep running while kiosk is active
            while self.kiosk.is_running():
                time.sleep(1)

            logger.info("Kiosk display exited")
            return 0

        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
            return 0

    def stop(self):
        """Stop the kiosk"""
        if self.kiosk:
            logger.info("Stopping kiosk display")
            self.kiosk.stop()


# Global manager for signal handling
manager = None


def signal_handler(signum, frame):
    """Handle termination signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    if manager:
        manager.stop()
    sys.exit(0)


def main():
    """Main application entry point"""
    global manager

    logger.info("Starting simple kiosk WebView application")

    # Set up signal handling
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    manager = KioskManager()

    try:
        return manager.start()
    except Exception as e:
        logger.error(f"Application error: {e}")
        return 1
    finally:
        if manager:
            manager.stop()


if __name__ == "__main__":
    sys.exit(main())
