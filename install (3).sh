#!/bin/bash
# ============================================================
# INSTALLER ONE-LINER - Script Premium St A1 Nyel
# Jalankan dengan: bash install.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Harus dijalankan sebagai root!${NC}"
    echo -e "${YELLOW}Gunakan: sudo bash install.sh${NC}"
    exit 1
fi

clear
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     INSTALLER SCRIPT PREMIUM ST A1 NYEL         ║${NC}"
echo -e "${CYAN}║              >> GRATIS KITA <<                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Salin menu.sh ke /usr/local/bin/menu agar bisa dipanggil dari mana saja
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_FILE="${SCRIPT_DIR}/menu.sh"

if [ ! -f "$MENU_FILE" ]; then
    echo -e "${RED}[ERROR] File menu.sh tidak ditemukan di direktori ini!${NC}"
    echo -e "${YELLOW}Pastikan menu.sh dan install.sh berada di folder yang sama.${NC}"
    exit 1
fi

echo -e "${YELLOW}[*] Menginstall script ke /usr/local/bin/menu...${NC}"
cp "$MENU_FILE" /usr/local/bin/menu
chmod +x /usr/local/bin/menu

echo -e "${YELLOW}[*] Juga menyimpan di /root/menu.sh...${NC}"
cp "$MENU_FILE" /root/menu.sh
chmod +x /root/menu.sh

# Tambahkan alias 'menu' ke .bashrc agar bisa dipanggil langsung
if ! grep -q "alias menu=" /root/.bashrc 2>/dev/null; then
    echo "alias menu='bash /usr/local/bin/menu'" >> /root/.bashrc
fi

# Buat shortcut di /etc/profile.d agar berlaku untuk semua user root
cat > /etc/profile.d/vps-menu.sh <<'EOF'
# VPS Menu Script - St A1 Nyel
alias menu='bash /usr/local/bin/menu'
EOF
chmod +x /etc/profile.d/vps-menu.sh

# Reset lock file agar auto-install berjalan di run pertama
rm -f /tmp/.st_a1_nyel_done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           INSTALASI BERHASIL!                   ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Cara menjalankan menu:                         ║${NC}"
echo -e "${GREEN}║   1. Ketik: menu                                ║${NC}"
echo -e "${GREEN}║   2. Ketik: bash /root/menu.sh                  ║${NC}"
echo -e "${GREEN}║   3. Ketik: bash /usr/local/bin/menu            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

echo -ne "${YELLOW}Jalankan menu sekarang? [y/n]: ${NC}"
read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
    bash /usr/local/bin/menu
fi
