#!/usr/bin/env bash
# ============================================================
#  MOWIS DE — Arch/CachyOS Install Script
#  Quick installer — wraps pacman + applies MOWIS config
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}sudo bash install-arch.sh${NC}"; exit 1; }

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

echo -e "${CYAN}[MOWIS] Cài đặt UKUI engine...${NC}"
pacman -S --noconfirm --needed ukui \
    picom rofi dunst feh kvantum qt5ct \
    papirus-icon-theme noto-fonts noto-fonts-emoji \
    python-psutil python-gobject python-cairo \
    libnotify xorg-xrandr xorg-xsetroot \
    lightdm ukui-greeter network-manager-applet \
    blueman pasystray scrot

echo -e "${CYAN}[MOWIS] Cài GSchema override...${NC}"
install -Dm644 "$(dirname "$0")/debian/mowis.gschema.override" \
    /usr/share/glib-2.0/schemas/50_mowis.gschema.override
glib-compile-schemas /usr/share/glib-2.0/schemas/

echo -e "${CYAN}[MOWIS] Enable LightDM + ukui-greeter...${NC}"
systemctl disable sddm.service 2>/dev/null || true
systemctl enable lightdm.service

echo -e "${CYAN}[MOWIS] Tạo MOWIS-UKUI session entry...${NC}"
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/mowis.desktop << 'SESS'
[Desktop Entry]
Name=MOWIS Desktop
Comment=Mobile-Optimized Workspace Interface Shell
Exec=/usr/local/bin/mowis-ukui-session
TryExec=/usr/local/bin/mowis-ukui-session
Type=XSession
DesktopNames=UKUI
SESS

cat > /usr/local/bin/mowis-ukui-session << 'SESSSH'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/sbin"
export XDG_CURRENT_DESKTOP=UKUI
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORMTHEME=ukui
export QT_STYLE_OVERRIDE=kvantum-dark
export GTK2_RC_FILES="$HOME/.gtkrc-2.0"
[ -z "$DBUS_SESSION_BUS_ADDRESS" ] && eval $(dbus-launch --sh-syntax --exit-with-session)
xrandr --dpi 96 2>/dev/null || true
xsetroot -cursor_name left_ptr 2>/dev/null || true
xset dpms 600 900 1200 2>/dev/null || true
picom --backend glx -b 2>/dev/null || picom --backend xrender -b 2>/dev/null || true
[ -f "$HOME/.mowis/wallpapers/default.jpg" ] && \
    feh --bg-fill "$HOME/.mowis/wallpapers/default.jpg" 2>/dev/null || true
exec ukui-session
SESSSH
chmod +x /usr/local/bin/mowis-ukui-session

echo -e "${GREEN}[MOWIS] Done! Reboot và chọn 'MOWIS Desktop' ở LightDM.${NC}"
echo -e "${GREEN}        sudo reboot${NC}"
