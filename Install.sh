#!/bin/bash
set -e

echo "=============================================="
echo " Spa Music Kiosk – FINAL INSTALLER "
echo "=============================================="
echo

# -----------------------------
# AUTO-DETECTED VARIABLES
# -----------------------------
USER_NAME="$(whoami)"
HOME_DIR="$HOME"
KIOSK_DIR="$HOME_DIR/kiosk"
AUTOSTART_DIR="$HOME_DIR/.config/autostart"

BT_MAC="FC:58:FA:4F:2E:7C"
MASTER_PASSWORD="20903"

# -----------------------------
# SAFETY CHECK (NOT ROOT)
# -----------------------------
if [ "$EUID" -eq 0 ]; then
  echo "❌ Do NOT run this as root"
  exit 1
fi

# -----------------------------
# INSTALL PACKAGES
# -----------------------------
echo "[1/5] Installing required packages..."
sudo apt update -y
sudo apt install -y \
  chromium \
  unclutter \
  xbindkeys \
  xdotool \
  zenity \
  blueman \
  xfce4-power-manager \
  x11-xserver-utils

# -----------------------------
# CREATE KIOSK DIRECTORY
# -----------------------------
echo "[2/5] Creating kiosk directory..."
mkdir -p "$KIOSK_DIR"

# -----------------------------
# CREATE START SCRIPT
# -----------------------------
echo "[3/5] Creating kiosk startup script..."

cat << EOF > "$KIOSK_DIR/start-kiosk.sh"
#!/bin/bash

# Clear Chromium session every boot
rm -rf "$HOME/.config/chromium"
rm -rf "$HOME/.cache/chromium"

# Disable screen blanking
xset s off
xset s noblank
xset -dpms

# Hide desktop UI
xfdesktop --quit || true
pkill xfce4-panel || true

# Hide mouse after 5 seconds
unclutter -idle 5 &

# Start key listener
xbindkeys &

# Bluetooth auto-connect
"$KIOSK_DIR/bt-autoconnect.sh" &

# Secret access corner
"$KIOSK_DIR/secret-corner.sh" &

sleep 5

# Launch Chromium kiosk
chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI \
  --autoplay-policy=no-user-gesture-required \
  file://"$KIOSK_DIR/index.html"
EOF

chmod +x "$KIOSK_DIR/start-kiosk.sh"

# -----------------------------
# BLUETOOTH AUTO-CONNECT
# -----------------------------
echo "[4/5] Creating Bluetooth auto-connect..."

cat << EOF > "$KIOSK_DIR/bt-autoconnect.sh"
#!/bin/bash
sleep 8
bluetoothctl << EOB
power on
connect $BT_MAC
EOB
EOF

chmod +x "$KIOSK_DIR/bt-autoconnect.sh"

# -----------------------------
# SECRET BLUETOOTH ACCESS
# -----------------------------
cat << EOF > "$KIOSK_DIR/secret-bluetooth.sh"
#!/bin/bash
INPUT=\$(zenity --password --title="Bluetooth Access")
if [ "\$INPUT" = "$MASTER_PASSWORD" ]; then
  xfce4-panel &
  blueman-manager &
else
  notify-send "Access denied"
fi
EOF

chmod +x "$KIOSK_DIR/secret-bluetooth.sh"

# -----------------------------
# SECRET TOUCH CORNER
# -----------------------------
cat << EOF > "$KIOSK_DIR/secret-corner.sh"
#!/bin/bash
while true; do
  eval \$(xdotool getmouselocation --shell)
  if [ "\$X" -lt 20 ] && [ "\$Y" -lt 20 ]; then
    sleep 5
    eval \$(xdotool getmouselocation --shell)
    if [ "\$X" -lt 20 ] && [ "\$Y" -lt 20 ]; then
      INPUT=\$(zenity --password --title="Bluetooth Access")
      if [ "\$INPUT" = "$MASTER_PASSWORD" ]; then
        xfce4-panel &
        blueman-manager &
      fi
    fi
  fi
  sleep 1
done
EOF

chmod +x "$KIOSK_DIR/secret-corner.sh"

# -----------------------------
# SECRET KEY COMBO (Ctrl+Alt+B)
# -----------------------------
cat << EOF > "$HOME_DIR/.xbindkeysrc"
"$KIOSK_DIR/secret-bluetooth.sh"
  Control+Alt+b
EOF

# -----------------------------
# AUTOSTART
# -----------------------------
echo "[5/5] Enabling autostart..."

mkdir -p "$AUTOSTART_DIR"

cat << EOF > "$AUTOSTART_DIR/kiosk.desktop"
[Desktop Entry]
Type=Application
Name=Spa Music Kiosk
Exec=$KIOSK_DIR/start-kiosk.sh
X-GNOME-Autostart-enabled=true
EOF

echo
echo "=============================================="
echo " INSTALL COMPLETE"
echo "=============================================="
echo
echo "NEXT STEPS:"
echo
echo "1️⃣ Copy your files into:"
echo "   $KIOSK_DIR/"
echo
echo "   Required:"
echo "   - index.html"
echo "   - player.html"
echo "   - your .mp3 files"
echo
echo "2️⃣ Reboot:"
echo "   sudo reboot"
echo
echo "That’s it."
echo "=============================================="
