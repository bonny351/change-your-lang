#!/bin/bash
set -e

echo "=============================================="
echo "  Spa Music Kiosk – FULL Kali Linux Installer  "
echo "=============================================="
echo

# -----------------------------
# VARIABLES
# -----------------------------
KIOSK_USER="kali"
HOME_DIR="/home/$KIOSK_USER"
KIOSK_DIR="$HOME_DIR/kiosk"
AUTOSTART_DIR="$HOME_DIR/.config/autostart"

# -----------------------------
# SAFETY CHECK
# -----------------------------
if [ "$USER" != "$KIOSK_USER" ]; then
  echo "❌ Please run this script as user: $KIOSK_USER"
  exit 1
fi

# -----------------------------
# SYSTEM UPDATE
# -----------------------------
echo "[1/7] Updating system..."
sudo apt update -y
sudo apt upgrade -y

# -----------------------------
# INSTALL PACKAGES
# -----------------------------
echo "[2/7] Installing required packages..."
sudo apt install -y \
  chromium \
  unclutter \
  xfce4-power-manager \
  pavucontrol \
  x11-xserver-utils

# -----------------------------
# CREATE KIOSK DIRECTORY
# -----------------------------
echo "[3/7] Creating kiosk directory..."
mkdir -p "$KIOSK_DIR"

# -----------------------------
# CREATE START SCRIPT
# -----------------------------
echo "[4/7] Creating kiosk launch script..."

cat << 'EOF' > "$KIOSK_DIR/start-kiosk.sh"
#!/bin/bash

# Disable screen blanking & power saving
xset s off
xset s noblank
xset -dpms

# Hide mouse cursor
unclutter &

# Launch Chromium in kiosk mode
chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI \
  --autoplay-policy=no-user-gesture-required \
  file:///home/kali/kiosk/index.html
EOF

chmod +x "$KIOSK_DIR/start-kiosk.sh"

# -----------------------------
# AUTOSTART CONFIG
# -----------------------------
echo "[5/7] Setting up autostart..."

mkdir -p "$AUTOSTART_DIR"

cat << 'EOF' > "$AUTOSTART_DIR/kiosk.desktop"
[Desktop Entry]
Type=Application
Name=Spa Music Kiosk
Comment=Auto-start Chromium in kiosk mode
Exec=/home/kali/kiosk/start-kiosk.sh
X-GNOME-Autostart-enabled=true
EOF

# -----------------------------
# POWER SETTINGS (NO SLEEP)
# -----------------------------
echo "[6/7] Disabling screen sleep..."
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -s false || true

# -----------------------------
# DONE
# -----------------------------
echo "[7/7] Installation complete!"
echo
echo "=============================================="
echo " NEXT STEPS (IMPORTANT)"
echo "=============================================="
echo
echo "1️⃣ Copy your files into:"
echo "   $KIOSK_DIR/"
echo
echo "   Required files:"
echo "   - index.html"
echo "   - player.html"
echo
echo "2️⃣ Reboot the system:"
echo "   sudo reboot"
echo
echo "After reboot:"
echo "✔ Kali auto-logs in"
echo "✔ Chromium launches fullscreen"
echo "✔ Profile picker appears"
echo
echo "=============================================="
echo " INSTALL FINISHED SUCCESSFULLY"
echo "=============================================="
