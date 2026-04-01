#!/usr/bin/env python3
"""
Kiosk WebView Application
Full-screen browser for displaying the school website
"""

import sys
import os
import logging
from PyQt5.QtWidgets import QApplication, QMainWindow
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEngineSettings
from PyQt5.QtCore import Qt, QUrl, QTimer
from PyQt5.QtGui import QCursor

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


class KioskWebView(QMainWindow):
    def __init__(self):
        super().__init__()
        self.init_ui()

    def init_ui(self):
        """Initialize the user interface"""
        # Set up the main window
        self.setWindowTitle("School Kiosk")
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint)

        # Create WebView
        self.webview = QWebEngineView()
        self.setCentralWidget(self.webview)

        # Configure WebEngine settings
        settings = QWebEngineSettings.globalSettings()
        settings.setAttribute(QWebEngineSettings.PluginsEnabled, True)
        settings.setAttribute(QWebEngineSettings.JavascriptEnabled, True)
        settings.setAttribute(QWebEngineSettings.LocalStorageEnabled, True)
        settings.setAttribute(QWebEngineSettings.AutoLoadImages, True)
        settings.setAttribute(QWebEngineSettings.PlaybackRequiresUserGesture, False)

        # Disable features that might interfere with kiosk mode
        settings.setAttribute(QWebEngineSettings.ShowScrollBars, False)

        # Connect signals
        self.webview.loadFinished.connect(self.on_load_finished)
        self.webview.loadStarted.connect(self.on_load_started)

        # Set up auto-refresh timer (refresh every 5 minutes)
        self.refresh_timer = QTimer()
        self.refresh_timer.timeout.connect(self.refresh_page)
        self.refresh_timer.start(5 * 60 * 1000)  # 5 minutes in milliseconds

        # Hide cursor after 10 seconds of inactivity
        self.cursor_timer = QTimer()
        self.cursor_timer.timeout.connect(self.hide_cursor)
        self.cursor_timer.setSingleShot(True)

        # Load the website
        self.load_website()

        # Go fullscreen
        self.showFullScreen()

        logger.info("Kiosk WebView initialized")

    def load_website(self):
        """Load the kiosk website"""
        try:
            url = QUrl(KIOSK_URL)
            self.webview.load(url)
            logger.info(f"Loading website: {KIOSK_URL}")
        except Exception as e:
            logger.error(f"Failed to load website: {e}")

    def on_load_started(self):
        """Called when page load starts"""
        logger.info("Page load started")

    def on_load_finished(self, success):
        """Called when page load finishes"""
        if success:
            logger.info("Page loaded successfully")
        else:
            logger.error("Page load failed")
            # Retry after 30 seconds
            QTimer.singleShot(30000, self.load_website)

    def refresh_page(self):
        """Refresh the current page"""
        logger.info("Auto-refreshing page")
        self.webview.reload()

    def hide_cursor(self):
        """Hide the mouse cursor"""
        self.setCursor(QCursor(Qt.BlankCursor))

    def mouseMoveEvent(self, event):
        """Show cursor on mouse movement"""
        self.setCursor(QCursor(Qt.ArrowCursor))
        self.cursor_timer.start(10000)  # Hide cursor after 10 seconds
        super().mouseMoveEvent(event)

    def keyPressEvent(self, event):
        """Handle key press events"""
        # Disable common key combinations that might exit kiosk mode
        key = event.key()
        modifiers = event.modifiers()

        # Allow F5 for refresh
        if key == Qt.Key_F5:
            self.refresh_page()
            return

        # Block other potentially problematic keys
        blocked_keys = [
            Qt.Key_Escape,
            Qt.Key_Alt,
            Qt.Key_Tab,
            Qt.Key_Meta,  # Windows/Cmd key
        ]

        blocked_combinations = [
            (Qt.ControlModifier, Qt.Key_C),
            (Qt.ControlModifier, Qt.Key_V),
            (Qt.ControlModifier, Qt.Key_A),
            (Qt.ControlModifier, Qt.Key_T),
            (Qt.ControlModifier, Qt.Key_N),
            (Qt.ControlModifier, Qt.Key_W),
            (Qt.ControlModifier, Qt.Key_Q),
            (Qt.AltModifier, Qt.Key_F4),
            (Qt.AltModifier, Qt.Key_Tab),
        ]

        # Check if key should be blocked
        if key in blocked_keys:
            logger.info(f"Blocked key press: {key}")
            return

        # Check if key combination should be blocked
        for mod, blocked_key in blocked_combinations:
            if modifiers & mod and key == blocked_key:
                logger.info(f"Blocked key combination: {modifiers} + {key}")
                return

        # Allow other keys to pass through
        super().keyPressEvent(event)

    def closeEvent(self, event):
        """Handle application close event"""
        logger.info("WebView application closing")
        event.accept()


def main():
    """Main application entry point"""
    # Set up Qt application
    app = QApplication(sys.argv)
    app.setApplicationName("School Kiosk")

    # Disable Qt's built-in screen saver
    app.setAttribute(Qt.AA_DisableWindowContextHelpButton, True)

    # Create and show the kiosk window
    kiosk = KioskWebView()

    # Set up signal handling for graceful shutdown
    import signal

    def signal_handler(signum, frame):
        logger.info(f"Received signal {signum}, shutting down...")
        app.quit()

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    logger.info("Starting kiosk WebView application")

    # Start the application
    try:
        sys.exit(app.exec_())
    except Exception as e:
        logger.error(f"Application error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
