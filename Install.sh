#!/bin/bash
set -e

echo "=============================================="
echo " Spa Music Kiosk – FINAL ONE-FILE INSTALLER "
echo "=============================================="
echo

# -----------------------------
# VARIABLES (FINAL)
# -----------------------------
USER_NAME="kali"
HOME_DIR="/home/$USER_NAME"
KIOSK_DIR="$HOME_DIR/kiosk"
AUTOSTART_DIR="$HOME_DIR/.config/autostart"

BT_MAC="FC:58:FA:4F:2E:7C"
MASTER_PASSWORD="20903"

# -----------------------------
# SAFETY CHECK
# -----------------------------
if [ "$USER" != "$USER_NAME" ]; then
  echo "❌ Run this as user: $USER_NAME"
  exit 1
fi

# -----------------------------
# INSTALL PACKAGES
# -----------------------------
echo "[1/7] Installing required packages..."
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
echo "[2/7] Creating kiosk directory..."
mkdir -p "$KIOSK_DIR"

# -----------------------------
# START-KIOSK SCRIPT
# -----------------------------
echo "[3/7] Creating kiosk startup script..."

cat << EOF > "$KIOSK_DIR/start-kiosk.sh"
#!/bin/bash

# Clear Chromium session every boot
rm -rf $HOME_DIR/.config/chromium
rm -rf $HOME_DIR/.cache/chromium

# Disable screen blanking
xset s off
xset s noblank
xset -dpms

# Hide desktop UI
xfdesktop --quit || true
pkill xfce4-panel || true

# Hide mouse after 5 seconds
unclutter -idle 5 &

# Start key bindings
xbindkeys &

# Bluetooth auto-connect
$KIOSK_DIR/bt-autoconnect.sh &

# Secret touch corner
$KIOSK_DIR/secret-corner.sh &

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
  file://$KIOSK_DIR/index.html
EOF

chmod +x "$KIOSK_DIR/start-kiosk.sh"

# -----------------------------
# BLUETOOTH AUTO-CONNECT
# -----------------------------
echo "[4/7] Creating Bluetooth auto-connect..."

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
# SECRET BLUETOOTH SETTINGS
# -----------------------------
echo "[5/7] Creating secret Bluetooth access..."

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
echo "[6/7] Enabling autostart..."

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
echo "Bluetooth MAC: $BT_MAC"
echo "ALL PASSWORDS: 20903"
echo
echo "Secret Bluetooth access:"
echo " - Ctrl + Alt + B"
echo " - OR hold top-left corner 5 seconds"
echo
echo "Put index.html + player.html in:"
echo " $KIOSK_DIR"
echo
echo "Reboot to start kiosk:"
echo " sudo reboot"
echo
echo "=============================================="
