#!/usr/bin/env python3
"""
Kiosk WebView Application
Full-screen browser for displaying the school website
Supports both PyQt5 WebEngine and Chromium fallback
"""

import sys
import os
import logging
import subprocess
import signal
import time
from pathlib import Path

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


class ChromiumKiosk:
    """Chromium-based fallback kiosk implementation"""

    def __init__(self):
        self.process = None

    def start(self):
        """Start Chromium in kiosk mode"""
        try:
            # Find chromium executable
            chromium_cmd = None
            for cmd in ["chromium", "chromium-browser", "google-chrome"]:
                if subprocess.run(["which", cmd], capture_output=True).returncode == 0:
                    chromium_cmd = cmd
                    break

            if not chromium_cmd:
                logger.error("No chromium executable found")
                return False

            # Chromium kiosk arguments
            args = [
                chromium_cmd,
                "--kiosk",
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-gpu-sandbox",
                "--disable-software-rasterizer",
                "--disable-background-timer-throttling",
                "--disable-backgrounding-occluded-windows",
                "--disable-renderer-backgrounding",
                "--disable-features=TranslateUI",
                "--disable-extensions",
                "--disable-plugins",
                "--no-first-run",
                "--disable-infobars",
                "--disable-session-crashed-bubble",
                "--disable-restore-session-state",
                "--autoplay-policy=no-user-gesture-required",
                "--window-position=0,0",
                "--start-fullscreen",
                KIOSK_URL,
            ]

            logger.info(f"Starting Chromium kiosk: {chromium_cmd}")
            self.process = subprocess.Popen(
                args,
                env={**os.environ, "DISPLAY": ":0"},
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

            return True

        except Exception as e:
            logger.error(f"Failed to start Chromium: {e}")
            return False

    def stop(self):
        """Stop Chromium"""
        if self.process:
            try:
                self.process.terminate()
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
            except Exception as e:
                logger.error(f"Error stopping Chromium: {e}")

    def is_running(self):
        """Check if Chromium is running"""
        return self.process and self.process.poll() is None


class PyQt5Kiosk:
    """PyQt5 WebEngine kiosk implementation"""

    def __init__(self):
        self.app = None
        self.window = None

    def start(self):
        """Start PyQt5 WebEngine kiosk"""
        try:
            from PyQt5.QtWidgets import QApplication, QMainWindow
            from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEngineSettings
            from PyQt5.QtCore import Qt, QUrl, QTimer
            from PyQt5.QtGui import QCursor

            # Set up Qt application
            self.app = QApplication(sys.argv)
            self.app.setApplicationName("School Kiosk")

            # Create main window
            self.window = QMainWindow()
            self.window.setWindowTitle("School Kiosk")
            self.window.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)

            # Create WebView
            webview = QWebEngineView()
            self.window.setCentralWidget(webview)

            # Configure WebEngine settings
            settings = QWebEngineSettings.globalSettings()
            settings.setAttribute(QWebEngineSettings.PluginsEnabled, True)
            settings.setAttribute(QWebEngineSettings.JavascriptEnabled, True)
            settings.setAttribute(QWebEngineSettings.LocalStorageEnabled, True)
            settings.setAttribute(QWebEngineSettings.AutoLoadImages, True)
            settings.setAttribute(QWebEngineSettings.PlaybackRequiresUserGesture, False)
            settings.setAttribute(QWebEngineSettings.ShowScrollBars, False)

            # Load the website
            webview.load(QUrl(KIOSK_URL))

            # Auto-refresh timer (every 5 minutes)
            refresh_timer = QTimer()
            refresh_timer.timeout.connect(webview.reload)
            refresh_timer.start(5 * 60 * 1000)

            # Show fullscreen
            self.window.showFullScreen()

            # Hide cursor after 10 seconds
            cursor_timer = QTimer()
            cursor_timer.timeout.connect(
                lambda: self.window.setCursor(QCursor(Qt.BlankCursor))
            )
            cursor_timer.setSingleShot(True)
            cursor_timer.start(10000)

            logger.info("PyQt5 WebEngine kiosk started")
            return True

        except ImportError as e:
            logger.error(f"PyQt5 not available: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to start PyQt5 kiosk: {e}")
            return False

    def run(self):
        """Run the PyQt5 application"""
        if self.app:
            return self.app.exec_()
        return 1

    def stop(self):
        """Stop PyQt5 application"""
        if self.app:
            self.app.quit()


class KioskManager:
    """Manages kiosk display with fallback options"""

    def __init__(self):
        self.kiosk = None
        self.using_pyqt5 = False

    def start(self):
        """Start kiosk with best available method"""
        logger.info("Starting kiosk display...")

        # Try PyQt5 first
        pyqt5_kiosk = PyQt5Kiosk()
        if pyqt5_kiosk.start():
            self.kiosk = pyqt5_kiosk
            self.using_pyqt5 = True
            logger.info("Using PyQt5 WebEngine")
            return self.kiosk.run()

        # Fallback to Chromium
        logger.info("Falling back to Chromium...")
        chromium_kiosk = ChromiumKiosk()
        if chromium_kiosk.start():
            self.kiosk = chromium_kiosk
            self.using_pyqt5 = False
            logger.info("Using Chromium kiosk mode")

            # Keep the script running while Chromium is active
            try:
                while chromium_kiosk.is_running():
                    time.sleep(1)
                return 0
            except KeyboardInterrupt:
                logger.info("Received interrupt signal")
                return 0

        logger.error("No suitable kiosk method available")
        return 1

    def stop(self):
        """Stop the kiosk"""
        if self.kiosk:
            logger.info("Stopping kiosk display")
            self.kiosk.stop()


def signal_handler(signum, frame):
    """Handle termination signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    if hasattr(signal_handler, "manager"):
        signal_handler.manager.stop()
    sys.exit(0)


def main():
    """Main application entry point"""
    logger.info("Starting kiosk WebView application")

    # Set up signal handling
    manager = KioskManager()
    signal_handler.manager = manager

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    try:
        return manager.start()
    except Exception as e:
        logger.error(f"Application error: {e}")
        return 1
    finally:
        manager.stop()


if __name__ == "__main__":
    sys.exit(main())
