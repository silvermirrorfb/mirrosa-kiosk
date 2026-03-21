#!/bin/bash
# âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
# SILVER SIDEWALK KIOSK â Raspberry Pi 5 Setup Script
# âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
#
# This script configures a fresh Raspberry Pi 5 as a dedicated
# kiosk that boots directly into the Mirrosa skin analysis app.
#
# BEFORE RUNNING THIS SCRIPT:
# 1. Flash Raspberry Pi OS (64-bit, Desktop) onto the SD card
#    using Raspberry Pi Imager (https://www.raspberrypi.com/software/)
# 2. During flashing, set:
#    - Hostname: silvermirror-kiosk
#    - Username: kiosk
#    - Password: (choose a strong password, write it down)
#    - WiFi: your studio's WiFi network name + password
#    - Enable SSH: yes
# 3. Insert SD card into Pi, connect HDMI to TV, plug in Brio via USB
# 4. Boot the Pi, open Terminal, and run this script:
#    curl -sL https://raw.githubusercontent.com/silvermirrorfb/mirrosa-kiosk/main/setup-pi.sh | bash
#
# âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ

set -e

echo "âââââââââââââââââââââââââââââââââââââââââââââââââ"
echo "â  SILVER SIDEWALK KIOSK â Pi Setup Starting    â"
echo "âââââââââââââââââââââââââââââââââââââââââââââââââ"
echo ""

# âââ STEP 1: System Updates âââ
echo "[1/8] Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# âââ STEP 2: Install required packages âââ
echo "[2/8] Installing required packages..."
sudo apt-get install -y -qq \
  chromium-browser \
  unclutter \
  xdotool \
  xscreensaver \
  sed

# âââ STEP 3: Disable screen blanking and power saving âââ
echo "[3/8] Disabling screen blanking and power saving..."

# Disable screen blanking in lightdm
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/01-kiosk.conf > /dev/null << 'EOF'
[Seat:*]
xserver-command=X -s 0 -dpms -nocursor
EOF

# Disable screensaver
if [ -f ~/.xscreensaver ]; then
  sed -i 's/mode:.*/mode: off/' ~/.xscreensaver
fi

# Disable DPMS (Display Power Management)
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/disable-dpms.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Disable DPMS
Exec=bash -c "xset s off; xset -dpms; xset s noblank"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# âââ STEP 4: Configure Chromium kiosk autostart âââ
echo "[4/8] Configuring Chromium kiosk mode..."

KIOSK_URL="https://mirrosa-kiosk.vercel.app"

# Create the kiosk launcher script
mkdir -p ~/kiosk
cat > ~/kiosk/start-kiosk.sh << KIOSKEOF
#!/bin/bash
# Silver Sidewalk Kiosk Launcher
# This script starts Chromium in kiosk mode

KIOSK_URL="${KIOSK_URL}"

# Wait for desktop to be ready
sleep 5

# Kill any existing Chromium instances
pkill -f chromium || true
sleep 2

# Clear Chromium crash flags (prevents "restore pages" dialog)
CHROMIUM_DIR=~/.config/chromium
if [ -d "\$CHROMIUM_DIR/Default" ]; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "\$CHROMIUM_DIR/Default/Preferences" 2>/dev/null || true
  sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "\$CHROMIUM_DIR/Default/Preferences" 2>/dev/null || true
fi

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after 3 seconds of inactivity
unclutter -idle 3 -root &

# Launch Chromium in kiosk mode
chromium-browser \\
  --kiosk \\
  --noerrdialogs \\
  --disable-infobars \\
  --disable-session-crashed-bubble \\
  --disable-component-update \\
  --disable-translate \\
  --disable-features=TranslateUI \\
  --disable-pinch \\
  --overscroll-history-navigation=0 \\
  --autoplay-policy=no-user-gesture-required \\
  --use-fake-ui-for-media-stream \\
  --enable-features=WebRTCPipeWireCapturer \\
  --check-for-update-interval=31536000 \\
  --disable-background-networking \\
  --no-first-run \\
  --start-fullscreen \\
  --start-maximized \\
  --window-size=1920,1080 \\
  --window-position=0,0 \\
  "\$KIOSK_URL" &

# Monitor Chromium and restart if it crashes
while true; do
  sleep 30
  if ! pgrep -f "chromium.*kiosk" > /dev/null; then
    echo "\$(date): Chromium crashed, restarting..." >> ~/kiosk/crash.log
    exec ~/kiosk/start-kiosk.sh
  fi
done
KIOSKEOF

chmod +x ~/kiosk/start-kiosk.sh

# âââ STEP 5: Set up autostart on boot âââ
echo "[5/8] Setting up autostart on boot..."

cat > ~/.config/autostart/kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Silver Sidewalk Kiosk
Comment=Mirrosa AI Skin Analysis Kiosk
Exec=/home/kiosk/kiosk/start-kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
EOF

# âââ STEP 6: Grant camera permissions âââ
echo "[6/8] Granting camera permissions for Chromium..."

# Create Chromium policy to auto-grant camera access
sudo mkdir -p /etc/chromium/policies/managed
sudo tee /etc/chromium/policies/managed/kiosk-policy.json > /dev/null << 'EOF'
{
  "VideoCaptureAllowed": true,
  "VideoCaptureAllowedUrls": [
    "https://mirrosa-kiosk.vercel.app",
    "https://mirrosa-kiosk-silver-mirror-projects.vercel.app"
  ],
  "DefaultMediaStreamSetting": 1,
  "AudioCaptureAllowed": false,
  "DefaultNotificationsSetting": 2,
  "DefaultPopupsSetting": 2,
  "DefaultGeolocationSetting": 2,
  "RestoreOnStartup": 1,
  "HomepageLocation": "https://mirrosa-kiosk.vercel.app",
  "BookmarkBarEnabled": false,
  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "BrowserSignin": 0,
  "SyncDisabled": true,
  "MetricsReportingEnabled": false
}
EOF

# âââ STEP 7: WiFi auto-reconnect âââ
echo "[7/8] Configuring WiFi auto-reconnect..."

cat > ~/kiosk/wifi-watchdog.sh << 'WIFIEOF'
#!/bin/bash
# WiFi watchdog - checks connectivity every 60 seconds
# If WiFi drops, attempts to reconnect

while true; do
  sleep 60
  if ! ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    echo "$(date): WiFi down, attempting reconnect..." >> ~/kiosk/wifi.log
    sudo nmcli networking off
    sleep 5
    sudo nmcli networking on
    sleep 15
    
    # If still down after reconnect, reboot
    if ! ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
      echo "$(date): WiFi still down after reconnect, rebooting..." >> ~/kiosk/wifi.log
      sudo reboot
    else
      echo "$(date): WiFi reconnected successfully" >> ~/kiosk/wifi.log
    fi
  fi
done
WIFIEOF

chmod +x ~/kiosk/wifi-watchdog.sh

# Add WiFi watchdog to autostart
cat > ~/.config/autostart/wifi-watchdog.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=WiFi Watchdog
Exec=/home/kiosk/kiosk/wifi-watchdog.sh
Hidden=true
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# âââ STEP 8: Create management scripts âââ
echo "[8/8] Creating management scripts..."

# Script to update the kiosk URL
cat > ~/kiosk/set-url.sh << 'EOF'
#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./set-url.sh https://your-new-url.vercel.app"
  exit 1
fi
sed -i "s|KIOSK_URL=.*|KIOSK_URL=\"$1\"|" ~/kiosk/start-kiosk.sh
echo "Kiosk URL updated to: $1"
echo "Restart the kiosk with: ./restart-kiosk.sh"
EOF
chmod +x ~/kiosk/set-url.sh

# Script to restart kiosk without rebooting
cat > ~/kiosk/restart-kiosk.sh << 'EOF'
#!/bin/bash
echo "Restarting kiosk..."
pkill -f chromium || true
sleep 2
~/kiosk/start-kiosk.sh &
echo "Kiosk restarted."
EOF
chmod +x ~/kiosk/restart-kiosk.sh

# Script to exit kiosk mode (for maintenance)
cat > ~/kiosk/exit-kiosk.sh << 'EOF'
#!/bin/bash
echo "Exiting kiosk mode..."
pkill -f chromium || true
pkill -f unclutter || true
pkill -f wifi-watchdog || true
echo "Kiosk stopped. Desktop is now accessible."
echo "Run ./restart-kiosk.sh to resume, or reboot."
EOF
chmod +x ~/kiosk/exit-kiosk.sh

# Script to view logs
cat > ~/kiosk/view-logs.sh << 'EOF'
#!/bin/bash
echo "=== CRASH LOG ==="
tail -20 ~/kiosk/crash.log 2>/dev/null || echo "(no crashes)"
echo ""
echo "=== WIFI LOG ==="
tail -20 ~/kiosk/wifi.log 2>/dev/null || echo "(no wifi issues)"
EOF
chmod +x ~/kiosk/view-logs.sh

# âââ DONE âââ
echo ""
echo "âââââââââââââââââââââââââââââââââââââââââââââââââ"
echo "â  SETUP COMPLETE                               â"
echo "â                                               â"
echo "â  Kiosk URL: ${KIOSK_URL}"
echo "â                                               â"
echo "â  What happens on reboot:                      â"
echo "â  1. Pi boots into desktop                     â"
echo "â  2. Chromium launches in kiosk mode            â"
echo "â  3. Camera auto-granted (no popup)            â"
echo "â  4. Face detection starts watching             â"
echo "â  5. WiFi watchdog monitors connection          â"
echo "â                                               â"
echo "â  Management commands (via SSH):               â"
echo "â  ~/kiosk/restart-kiosk.sh  - restart app      â"
echo "â  ~/kiosk/exit-kiosk.sh     - stop for maint   â"
echo "â  ~/kiosk/set-url.sh [url]  - change URL       â"
echo "â  ~/kiosk/view-logs.sh      - check logs       â"
echo "â                                               â"
echo "â  Reboot now? (y/n)                            â"
echo "âââââââââââââââââââââââââââââââââââââââââââââââââ"
echo ""
read -p "Reboot now to start kiosk? (y/n): " choice
if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
  sudo reboot
fi
