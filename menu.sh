#!/bin/bash
# ============================================================
#   Script Premium St A1 Nyel - VPS Management Menu
#   Versi: GRATIS KITA
#
#   GitHub Bin yang digunakan:
#   [1] Xray-core   → github.com/XTLS/Xray-core
#   [2] NoobzVPN    → github.com/noobz-id/noobzvpns
#   [3] UDP Custom  → github.com/Haris131/UDP-Custom  (ePro Dev)
#   [4] Gotop       → github.com/xxxserxxx/gotop
#   [5] Speedtest   → github.com/sivel/speedtest-cli
# ============================================================

# ===== WARNA =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_RED='\033[41m'
BG_BLUE='\033[44m'
BOLD='\033[1m'
NC='\033[0m'

# ===== CEK ROOT =====
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Script harus dijalankan sebagai root!"
    echo -e "${YELLOW}Gunakan: sudo bash menu.sh${NC}"
    exit 1
fi

# ===================================================
#  AUTO INSTALL DEPENDENCIES DARI GITHUB
# ===================================================
auto_install_deps() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Auto Install Dependencies dari GitHub...  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

    # Deteksi arsitektur
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_TAG="amd64";  ARCH_XRAY="64";        ARCH_NOOBZ="amd64" ;;
        aarch64) ARCH_TAG="arm64";  ARCH_XRAY="arm64-v8a"; ARCH_NOOBZ="arm64" ;;
        armv7*)  ARCH_TAG="armv7";  ARCH_XRAY="arm32-v7a"; ARCH_NOOBZ="arm64" ;;
        *)       ARCH_TAG="amd64";  ARCH_XRAY="64";        ARCH_NOOBZ="amd64" ;;
    esac

    apt-get update -qq 2>/dev/null

    # Paket dasar
    for pkg in curl wget unzip jq openssl net-tools vnstat cron python3-pip; do
        dpkg -l "$pkg" &>/dev/null || apt-get install -y "$pkg" -qq 2>/dev/null && \
            echo -e " ${GREEN}[✓]${NC} $pkg" || true
    done

    for pkg in openssh-server dropbear nginx haproxy certbot; do
        command -v "${pkg%%-*}" &>/dev/null || dpkg -l "$pkg" &>/dev/null || {
            echo -e " ${YELLOW}[+]${NC} Installing $pkg..."
            apt-get install -y "$pkg" -qq 2>/dev/null
        }
    done

    # ------------------------------------------------
    # [BIN 1] XRAY-CORE
    # Sumber: github.com/XTLS/Xray-core
    # ------------------------------------------------
    if [ ! -f /usr/local/bin/xray ]; then
        echo -e "\n ${YELLOW}[+]${NC} Downloading Xray-core (XTLS/Xray-core)..."
        XRAY_VER=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" \
            | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null)
        [ -z "$XRAY_VER" ] && XRAY_VER="v1.8.24"
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-${ARCH_XRAY}.zip"
        if wget -q --show-progress "$XRAY_URL" -O /tmp/xray.zip 2>/dev/null; then
            unzip -qo /tmp/xray.zip xray -d /usr/local/bin/ 2>/dev/null
            chmod +x /usr/local/bin/xray && rm -f /tmp/xray.zip
            echo -e " ${GREEN}[✓]${NC} Xray-core ${XRAY_VER} terinstall"
        else
            echo -e " ${RED}[✗]${NC} Xray-core gagal didownload"
        fi
        mkdir -p /etc/xray /var/log/xray
    else
        echo -e " ${GREEN}[✓]${NC} Xray-core sudah ada"
    fi

    # ------------------------------------------------
    # [BIN 2] NOOBZVPN SERVER
    # Sumber: github.com/noobz-id/noobzvpns
    # Installer resmi: wget -q https://github.com/noobz-id/noobzvpns/raw/main/install.sh
    # ------------------------------------------------
    if [ ! -f /usr/local/bin/noobzvpns ] && ! command -v noobzvpns &>/dev/null; then
        echo -e "\n ${YELLOW}[+]${NC} Downloading NoobzVPN (noobz-id/noobzvpns)..."
        NOOBZ_INSTALL="https://github.com/noobz-id/noobzvpns/raw/main/install.sh"
        if wget -q --timeout=15 "$NOOBZ_INSTALL" -O /tmp/noobz_install.sh 2>/dev/null && \
           [ -s /tmp/noobz_install.sh ]; then
            bash /tmp/noobz_install.sh 2>/dev/null \
                && echo -e " ${GREEN}[✓]${NC} NoobzVPN terinstall via installer resmi" \
                || echo -e " ${YELLOW}[~]${NC} NoobzVPN installer selesai (cek manual)"
            rm -f /tmp/noobz_install.sh
        else
            echo -e " ${RED}[✗]${NC} NoobzVPN gagal (opsional)"
        fi
        mkdir -p /etc/noobzvpns
    else
        echo -e " ${GREEN}[✓]${NC} NoobzVPN sudah ada"
    fi

    # ------------------------------------------------
    # [BIN 3] UDP CUSTOM (ePro Dev)
    # Sumber: github.com/Haris131/UDP-Custom
    # Binary: udp-custom-linux-amd64
    # Config: config.json
    # ------------------------------------------------
    if [ ! -f /root/udp/udp-custom ]; then
        echo -e "\n ${YELLOW}[+]${NC} Downloading UDP Custom (Haris131/UDP-Custom)..."
        mkdir -p /root/udp
        UDP_BIN="https://github.com/Haris131/UDP-Custom/raw/main/udp-custom-linux-amd64"
        UDP_CFG="https://raw.githubusercontent.com/Haris131/UDP-Custom/main/config.json"
        if wget -q --show-progress "$UDP_BIN" -O /root/udp/udp-custom 2>/dev/null && \
           [ -s /root/udp/udp-custom ]; then
            chmod +x /root/udp/udp-custom
            wget -q "$UDP_CFG" -O /root/udp/config.json 2>/dev/null || \
                echo '{"listen":":36712","stream_buffer":16777216,"receive_buffer":16777216,"auth":{"mode":"passwords","passwords":[]}}' \
                > /root/udp/config.json
            cat > /etc/systemd/system/udp-custom.service <<'EOF'
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target
[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s
[Install]
WantedBy=default.target
EOF
            systemctl daemon-reload
            systemctl enable udp-custom --now &>/dev/null
            echo -e " ${GREEN}[✓]${NC} UDP Custom terinstall"
        else
            rm -f /root/udp/udp-custom
            echo -e " ${RED}[✗]${NC} UDP Custom gagal didownload"
        fi
    else
        echo -e " ${GREEN}[✓]${NC} UDP Custom sudah ada"
    fi

    # ------------------------------------------------
    # [BIN 4] GOTOP
    # Sumber: github.com/xxxserxxx/gotop
    # Format: gotop_vX.X.X_linux_amd64.tgz
    # ------------------------------------------------
    if ! command -v gotop &>/dev/null; then
        echo -e "\n ${YELLOW}[+]${NC} Downloading gotop (xxxserxxx/gotop)..."
        GOTOP_VER=$(curl -sL "https://api.github.com/repos/xxxserxxx/gotop/releases/latest" \
            | grep tag_name | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
        [ -z "$GOTOP_VER" ] && GOTOP_VER="4.2.0"
        GURL="https://github.com/xxxserxxx/gotop/releases/download/v${GOTOP_VER}/gotop_v${GOTOP_VER}_linux_${ARCH_TAG}.tgz"
        if wget -q --show-progress "$GURL" -O /tmp/gotop.tgz 2>/dev/null; then
            tar -xzf /tmp/gotop.tgz -C /usr/local/bin/ 2>/dev/null
            chmod +x /usr/local/bin/gotop && rm -f /tmp/gotop.tgz
            echo -e " ${GREEN}[✓]${NC} Gotop v${GOTOP_VER} terinstall"
        else
            apt-get install -y htop -qq 2>/dev/null
            echo -e " ${YELLOW}[~]${NC} Gotop gagal, htop dipasang sebagai fallback"
        fi
    else
        echo -e " ${GREEN}[✓]${NC} Gotop sudah ada"
    fi

    # ------------------------------------------------
    # [BIN 5] SPEEDTEST-CLI
    # Sumber: github.com/sivel/speedtest-cli
    # File: speedtest.py (Python script)
    # ------------------------------------------------
    if ! command -v speedtest-cli &>/dev/null && ! command -v speedtest &>/dev/null; then
        echo -e "\n ${YELLOW}[+]${NC} Downloading speedtest-cli (sivel/speedtest-cli)..."
        SPURL="https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py"
        if wget -q "$SPURL" -O /usr/local/bin/speedtest-cli 2>/dev/null; then
            chmod +x /usr/local/bin/speedtest-cli
            echo -e " ${GREEN}[✓]${NC} Speedtest-cli terinstall"
        else
            echo -e " ${RED}[✗]${NC} Speedtest-cli gagal"
        fi
    else
        echo -e " ${GREEN}[✓]${NC} Speedtest sudah ada"
    fi

    # Buat direktori data akun
    mkdir -p /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/ssh/users 2>/dev/null

    # Start services
    for svc in nginx haproxy ssh dropbear; do
        systemctl enable "$svc" --now &>/dev/null 2>&1
    done

    echo -e "\n${GREEN}╔══════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Semua dependencies siap!  ✓    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════╝${NC}"
    sleep 2
}

# ===================================================
#  AMBIL INFO SISTEM
# ===================================================
get_system_info() {
    if curl -s --max-time 2 http://169.254.169.254/metadata/v1/id &>/dev/null; then
        SERVER_VPS="DigitalOcean, LLC"
    elif curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        SERVER_VPS="Amazon AWS"
    elif curl -s --max-time 2 -H "Metadata-Flavor: Google" \
         http://metadata.google.internal/computeMetadata/v1/ &>/dev/null; then
        SERVER_VPS="Google Cloud"
    else
        VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
        case "$VENDOR" in
            *Vultr*)   SERVER_VPS="Vultr, LLC" ;;
            *Hetzner*) SERVER_VPS="Hetzner Online" ;;
            *Linode*)  SERVER_VPS="Akamai/Linode" ;;
            *)         SERVER_VPS=$(hostname) ;;
        esac
    fi

    SYSTEM_OS=$(lsb_release -d 2>/dev/null | awk -F'\t' '{print $2}' \
             || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 \
             || echo "Linux")
    SYSTEM_CORE=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
    RAM_TOTAL=$(free -m | awk '/^Mem/{print $2}')
    RAM_USED=$(free -m  | awk '/^Mem/{print $3}')
    SERVER_RAM="${RAM_TOTAL} / ${RAM_USED} MB"
    LOADCPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.0f", $2}')
    [ -z "$LOADCPU" ] && LOADCPU="0"
    LOADCPU="${LOADCPU} %"
    DATE=$(date +%d-%m-%Y)
    TIME=$(date +%H-%M-%S)
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "Unknown")
    IP_VPS=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
          || curl -s --max-time 5 https://icanhazip.com 2>/dev/null \
          || hostname -I | awk '{print $1}')
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "yourdomain.com")

    COUNT_SSH=$(awk -F: '$7~/false|nologin/{print $1}' /etc/passwd 2>/dev/null | wc -l)
    COUNT_VMESS=$([ -f /etc/vmess/akun.txt ]       && wc -l < /etc/vmess/akun.txt       || echo "0")
    COUNT_VLESS=$([ -f /etc/vless/akun.txt ]        && wc -l < /etc/vless/akun.txt        || echo "0")
    COUNT_TROJAN=$([ -f /etc/trojan/akun.txt ]      && wc -l < /etc/trojan/akun.txt       || echo "0")
    COUNT_SHADOW=$([ -f /etc/shadowsocks/akun.txt ] && wc -l < /etc/shadowsocks/akun.txt  || echo "0")
}

# Status service
svc_s() {
    systemctl is-active "$1" &>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}"
}
check_services() {
    SSH_S=$(svc_s ssh)
    NOOBZ_S=$(svc_s noobzvpns)
    NGINX_S=$(svc_s nginx)
    HAPROXY_S=$(svc_s haproxy)
    WSEPRO_S=$(svc_s ws-epro)
    UDPCUSTOM_S=$(svc_s udp-custom)
    XRAY_S=$(svc_s xray)
    DROPBEAR_S=$(svc_s dropbear)
}

# ===================================================
#  HEADER
# ===================================================
show_header() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_RED}${WHITE}${BOLD}         Welcome To Script Premium St A1 Nyel               ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}SERVER VPS  ${NC} = ${WHITE}${SERVER_VPS}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}SYSTEM OS   ${NC} = ${WHITE}${SYSTEM_OS}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}SYSTEM CORE ${NC} = ${WHITE}${SYSTEM_CORE}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}SERVER RAM  ${NC} = ${WHITE}${SERVER_RAM}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}LOADCPU     ${NC} = ${WHITE}${LOADCPU}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}DATE        ${NC} = ${WHITE}${DATE}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}TIME        ${NC} = ${WHITE}${TIME}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}UPTIME      ${NC} = ${WHITE}${UPTIME}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}IP VPS      ${NC} = ${WHITE}${IP_VPS}${NC}"
    echo -e "${CYAN}│${NC} ${RED}•${NC} ${CYAN}DOMAIN      ${NC} = ${WHITE}${DOMAIN}${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${WHITE}${BOLD}               >>> INFORMATION ACCOUNT <<<                  ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC}       ${YELLOW}SSH/OPENVPN/UDP ${NC} = ${WHITE}${COUNT_SSH}${NC}"
    echo -e "${CYAN}│${NC}       ${YELLOW}VMESS/WS/GRPC   ${NC} = ${WHITE}${COUNT_VMESS}${NC}"
    echo -e "${CYAN}│${NC}       ${YELLOW}VLESS/WS/GRPC   ${NC} = ${WHITE}${COUNT_VLESS}${NC}"
    echo -e "${CYAN}│${NC}       ${YELLOW}TROJAN/WS/GRPC  ${NC} = ${WHITE}${COUNT_TROJAN}${NC}"
    echo -e "${CYAN}│${NC}       ${YELLOW}SHADOW/WS/GRPC  ${NC} = ${WHITE}${COUNT_SHADOW}${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${WHITE}${BOLD}             >>> Dekengane Pusat Blitar <<<                  ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${WHITE}SSH${NC}     ${SSH_S}   ${WHITE}NOOBZVPN${NC}  ${NOOBZ_S}   ${WHITE}NGINX${NC}  ${NGINX_S}   ${WHITE}HAPROXY${NC}  ${HAPROXY_S}"
    echo -e "${CYAN}│${NC} ${WHITE}WS-ePro${NC} ${WSEPRO_S} ${WHITE}UDP CUSTOM${NC} ${UDPCUSTOM_S} ${WHITE}XRAY${NC}   ${XRAY_S}   ${WHITE}DROPBEAR${NC} ${DROPBEAR_S}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ===================================================
#  MENU UTAMA
# ===================================================
show_menu() {
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[01]${NC} SSH MENU        ${CYAN}│${NC} ${GREEN}[08]${NC} BCKP/RSTR       ${CYAN}│${NC} ${GREEN}[15]${NC} MENU BOT        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[02]${NC} VMESS MENU      ${CYAN}│${NC} ${GREEN}[09]${NC} GOTOP X RAM     ${CYAN}│${NC} ${GREEN}[16]${NC} CHANGE DOMAIN   ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[03]${NC} VLESS MENU      ${CYAN}│${NC} ${GREEN}[10]${NC} RESTART ALL     ${CYAN}│${NC} ${GREEN}[17]${NC} FIX CRT DOMAIN  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[04]${NC} TROJAN MENU     ${CYAN}│${NC} ${GREEN}[11]${NC} TELE BOT        ${CYAN}│${NC} ${GREEN}[18]${NC} CANGE BANNER    ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[05]${NC} AKUN NOOBZVPN   ${CYAN}│${NC} ${GREEN}[12]${NC} UPDATE MENU     ${CYAN}│${NC} ${GREEN}[19]${NC} RESTART BANNER  ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[06]${NC} SS - LIBEV      ${CYAN}│${NC} ${GREEN}[13]${NC} RUNNING         ${CYAN}│${NC} ${GREEN}[20]${NC} SPEEDTEST        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[07]${NC} INSTALL UDP     ${CYAN}│${NC} ${GREEN}[14]${NC} INFO PORT       ${CYAN}│${NC} ${GREEN}[21]${NC} EKSTRAK MENU    ${CYAN}│${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC} ${YELLOW}Script Version = GRATIS KITA${NC}                               ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -ne " Options ${CYAN}[ 1 - 21 ]${NC} ${YELLOW}>>>${NC} "
}

# ===================================================
#  [01] SSH MENU
# ===================================================
menu_ssh() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}                    SSH / OPENVPN MENU                      ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah Akun SSH                                         ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[2]${NC} Hapus Akun SSH                                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[3]${NC} Perpanjang Akun SSH                                     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[4]${NC} Cek User Login SSH                                      ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[5]${NC} Cek Akun Expired                                        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[6]${NC} List Akun SSH                                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[7]${NC} Lock Akun SSH                                           ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[8]${NC} Unlock Akun SSH                                         ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[0]${NC} Kembali ke Menu Utama                                   ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-8]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear
            echo -e "${CYAN}=== TAMBAH AKUN SSH ===${NC}"
            echo -ne " Username   : "; read -r username
            echo -ne " Password   : "; read -r password
            echo -ne " Masa aktif : "; read -r days
            [[ -z "$username" || -z "$password" || -z "$days" ]] && {
                echo -e "${RED}[!] Input tidak boleh kosong!${NC}"; sleep 2; menu_ssh; return
            }
            exp=$(date -d "+${days} days" +"%Y-%m-%d")
            useradd -e "$exp" -s /bin/false -M "$username" 2>/dev/null
            echo -e "$password\n$password" | passwd "$username" &>/dev/null
            echo -e "\n${GREEN}[✓] Akun SSH Berhasil Dibuat!${NC}"
            echo -e "────────────────────────────────"
            echo -e " Username  : ${WHITE}$username${NC}"
            echo -e " Password  : ${WHITE}$password${NC}"
            echo -e " Expired   : ${WHITE}$exp${NC}"
            echo -e " Host/IP   : ${WHITE}$IP_VPS${NC}"
            echo -e " Port SSH  : ${WHITE}22${NC}"
            echo -e "────────────────────────────────"
            ;;
        2)
            clear; echo -ne " Username: "; read -r u
            id "$u" &>/dev/null && { userdel -f "$u" 2>/dev/null; echo -e "${GREEN}[✓] $u dihapus!${NC}"; } \
                || echo -e "${RED}[!] User tidak ditemukan!${NC}"
            ;;
        3)
            clear; echo -ne " Username: "; read -r u; echo -ne " Tambah hari: "; read -r d
            if id "$u" &>/dev/null; then
                curr=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
                if [[ "$curr" == "never" || -z "$curr" ]]; then
                    new_exp=$(date -d "+${d} days" +"%Y-%m-%d")
                else
                    new_exp=$(date -d "$curr +${d} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${d} days" +"%Y-%m-%d")
                fi
                chage -E "$new_exp" "$u"
                echo -e "${GREEN}[✓] $u diperpanjang s/d $new_exp${NC}"
            else echo -e "${RED}[!] User tidak ditemukan!${NC}"; fi
            ;;
        4)
            clear; echo -e "${CYAN}=== User Login SSH Aktif ===${NC}"
            who | awk '{print $1}' | sort | uniq -c | while read -r cnt usr; do
                echo -e " ${WHITE}$usr${NC} - ${GREEN}$cnt session${NC}"; done
            ;;
        5)
            clear; echo -e "${CYAN}=== Akun SSH Expired ===${NC}"
            awk -F: '$7~/false|nologin/{print $1}' /etc/passwd | while read -r u; do
                exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
                [[ "$exp" != "never" && -n "$exp" ]] && echo -e " ${WHITE}$u${NC} → ${RED}$exp${NC}"
            done ;;
        6)
            clear; echo -e "${CYAN}=== List Akun SSH ===${NC}"
            printf "%-20s %s\n" "USERNAME" "EXPIRED"
            echo "────────────────────────────────"
            awk -F: '$7~/false|nologin/{print $1}' /etc/passwd | while read -r u; do
                exp=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
                printf "%-20s %s\n" "$u" "$exp"; done
            ;;
        7)
            clear; echo -ne " Username: "; read -r u
            id "$u" &>/dev/null && { passwd -l "$u" &>/dev/null; echo -e "${GREEN}[✓] $u dikunci!${NC}"; } \
                || echo -e "${RED}[!] User tidak ditemukan!${NC}"
            ;;
        8)
            clear; echo -ne " Username: "; read -r u
            id "$u" &>/dev/null && { passwd -u "$u" &>/dev/null; echo -e "${GREEN}[✓] $u dibuka!${NC}"; } \
                || echo -e "${RED}[!] User tidak ditemukan!${NC}"
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_ssh
}

# ===================================================
#  [02] VMESS MENU
# ===================================================
menu_vmess() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}                  VMESS / WS / GRPC MENU                   ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah Akun Vmess         ${GREEN}[4]${NC} List Akun Vmess          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[2]${NC} Hapus Akun Vmess          ${GREEN}[5]${NC} Cek Expired Vmess        ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[3]${NC} Perpanjang Akun Vmess     ${GREEN}[0]${NC} Kembali Menu Utama       ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-5]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear; echo -e "${CYAN}=== TAMBAH AKUN VMESS ===${NC}"
            echo -ne " Username   : "; read -r u
            echo -ne " Masa aktif : "; read -r d
            UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null \
                || openssl rand -hex 16 | sed 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
            exp=$(date -d "+${d} days" +"%Y-%m-%d")
            echo "${u}|${UUID}|${exp}" >> /etc/vmess/akun.txt
            JSON_V="{\"v\":\"2\",\"ps\":\"${u}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\"}"
            LINK="vmess://$(echo -n "$JSON_V" | base64 -w 0)"
            echo -e "\n${GREEN}[✓] Akun Vmess Dibuat!${NC}"
            echo -e "────────────────────────────────"
            echo -e " Username  : ${WHITE}$u${NC}"
            echo -e " UUID      : ${WHITE}$UUID${NC}"
            echo -e " Expired   : ${WHITE}$exp${NC}"
            echo -e " Domain    : ${WHITE}$DOMAIN${NC}"
            echo -e " Port      : ${WHITE}443${NC}"
            echo -e " Path      : ${WHITE}/vmess${NC}"
            echo -e " Network   : ${WHITE}ws / grpc${NC}"
            echo -e " Security  : ${WHITE}tls${NC}"
            echo -e "────────────────────────────────"
            echo -e " Link Vmess:\n ${YELLOW}$LINK${NC}"
            ;;
        2)
            clear; echo -ne " Username: "; read -r u
            sed -i "/^${u}|/d" /etc/vmess/akun.txt 2>/dev/null
            echo -e "${GREEN}[✓] Akun $u dihapus!${NC}"
            ;;
        3)
            clear; echo -ne " Username: "; read -r u; echo -ne " Tambah hari: "; read -r d
            if grep -q "^${u}|" /etc/vmess/akun.txt 2>/dev/null; then
                ce=$(grep "^${u}|" /etc/vmess/akun.txt | cut -d'|' -f3)
                UU=$(grep "^${u}|" /etc/vmess/akun.txt | cut -d'|' -f2)
                ne=$(date -d "$ce +${d} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${d} days" +"%Y-%m-%d")
                sed -i "/^${u}|/c\\${u}|${UU}|${ne}" /etc/vmess/akun.txt
                echo -e "${GREEN}[✓] $u diperpanjang s/d $ne${NC}"
            else echo -e "${RED}[!] User tidak ditemukan!${NC}"; fi
            ;;
        4)
            clear; echo -e "${CYAN}=== List Akun Vmess ===${NC}"
            printf "%-20s %-38s %s\n" "USERNAME" "UUID" "EXPIRED"
            echo "──────────────────────────────────────────────────────────────────"
            [ -f /etc/vmess/akun.txt ] && while IFS='|' read -r u uid exp; do
                printf "%-20s %-38s %s\n" "$u" "$uid" "$exp"; done < /etc/vmess/akun.txt \
                || echo "Belum ada akun."
            ;;
        5)
            clear; echo -e "${CYAN}=== Akun Vmess Expired ===${NC}"
            today=$(date +%Y-%m-%d)
            [ -f /etc/vmess/akun.txt ] && while IFS='|' read -r u uid exp; do
                [[ "$exp" < "$today" ]] && echo -e " ${WHITE}$u${NC} → ${RED}EXPIRED: $exp${NC}"
            done < /etc/vmess/akun.txt || echo "Belum ada akun."
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_vmess
}

# ===================================================
#  [03] VLESS MENU
# ===================================================
menu_vless() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}                  VLESS / WS / GRPC MENU                   ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah  ${GREEN}[2]${NC} Hapus  ${GREEN}[3]${NC} Perpanjang  ${GREEN}[4]${NC} List  ${GREEN}[0]${NC} Kembali ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-4]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear; echo -ne " Username: "; read -r u; echo -ne " Masa aktif: "; read -r d
            UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
            exp=$(date -d "+${d} days" +"%Y-%m-%d")
            echo "${u}|${UUID}|${exp}" >> /etc/vless/akun.txt
            LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=%2Fvless#${u}"
            echo -e "${GREEN}[✓] Akun Vless Dibuat!${NC}"
            echo -e " UUID: ${WHITE}$UUID${NC} | Expired: ${WHITE}$exp${NC}"
            echo -e " Link:\n ${YELLOW}$LINK${NC}"
            ;;
        2)
            clear; echo -ne " Username: "; read -r u
            sed -i "/^${u}|/d" /etc/vless/akun.txt 2>/dev/null
            echo -e "${GREEN}[✓] $u dihapus!${NC}"
            ;;
        3)
            clear; echo -ne " Username: "; read -r u; echo -ne " Tambah hari: "; read -r d
            if grep -q "^${u}|" /etc/vless/akun.txt 2>/dev/null; then
                ce=$(grep "^${u}|" /etc/vless/akun.txt | cut -d'|' -f3)
                UU=$(grep "^${u}|" /etc/vless/akun.txt | cut -d'|' -f2)
                ne=$(date -d "$ce +${d} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${d} days" +"%Y-%m-%d")
                sed -i "/^${u}|/c\\${u}|${UU}|${ne}" /etc/vless/akun.txt
                echo -e "${GREEN}[✓] $u diperpanjang s/d $ne${NC}"
            else echo -e "${RED}[!] User tidak ditemukan!${NC}"; fi
            ;;
        4)
            clear; echo -e "${CYAN}=== List Akun Vless ===${NC}"
            [ -f /etc/vless/akun.txt ] && while IFS='|' read -r u uid exp; do
                echo -e " ${WHITE}$u${NC} | ${YELLOW}$exp${NC}"; done < /etc/vless/akun.txt \
                || echo "Belum ada akun."
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_vless
}

# ===================================================
#  [04] TROJAN MENU
# ===================================================
menu_trojan() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}                 TROJAN / WS / GRPC MENU                   ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah  ${GREEN}[2]${NC} Hapus  ${GREEN}[3]${NC} Perpanjang  ${GREEN}[4]${NC} List  ${GREEN}[0]${NC} Kembali ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-4]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear; echo -ne " Username: "; read -r u
            echo -ne " Password: "; read -r p; echo -ne " Masa aktif: "; read -r d
            exp=$(date -d "+${d} days" +"%Y-%m-%d")
            echo "${u}|${p}|${exp}" >> /etc/trojan/akun.txt
            LINK="trojan://${p}@${DOMAIN}:443?security=tls&type=ws&host=${DOMAIN}&path=%2Ftrojan#${u}"
            echo -e "${GREEN}[✓] Akun Trojan Dibuat!${NC}"
            echo -e " Pass: ${WHITE}$p${NC} | Expired: ${WHITE}$exp${NC}"
            echo -e " Link:\n ${YELLOW}$LINK${NC}"
            ;;
        2)
            clear; echo -ne " Username: "; read -r u
            sed -i "/^${u}|/d" /etc/trojan/akun.txt 2>/dev/null
            echo -e "${GREEN}[✓] $u dihapus!${NC}"
            ;;
        3)
            clear; echo -ne " Username: "; read -r u; echo -ne " Tambah hari: "; read -r d
            if grep -q "^${u}|" /etc/trojan/akun.txt 2>/dev/null; then
                ce=$(grep "^${u}|" /etc/trojan/akun.txt | cut -d'|' -f3)
                pw=$(grep "^${u}|" /etc/trojan/akun.txt | cut -d'|' -f2)
                ne=$(date -d "$ce +${d} days" +"%Y-%m-%d" 2>/dev/null || date -d "+${d} days" +"%Y-%m-%d")
                sed -i "/^${u}|/c\\${u}|${pw}|${ne}" /etc/trojan/akun.txt
                echo -e "${GREEN}[✓] $u diperpanjang s/d $ne${NC}"
            else echo -e "${RED}[!] User tidak ditemukan!${NC}"; fi
            ;;
        4)
            clear; echo -e "${CYAN}=== List Akun Trojan ===${NC}"
            [ -f /etc/trojan/akun.txt ] && while IFS='|' read -r u pw exp; do
                echo -e " ${WHITE}$u${NC} | ${YELLOW}$exp${NC}"; done < /etc/trojan/akun.txt \
                || echo "Belum ada akun."
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_trojan
}

# ===================================================
#  [05] NOOBZVPN MENU
# ===================================================
menu_noobzvpn() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}                    AKUN NOOBZVPN MENU                     ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}Sumber: github.com/noobz-id/noobzvpns${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah Akun    ${GREEN}[3]${NC} List Akun                          ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[2]${NC} Hapus Akun     ${GREEN}[4]${NC} Status Service   ${GREEN}[0]${NC} Kembali  ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-4]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear; echo -ne " Username: "; read -r u
            echo -ne " Password: "; read -r p; echo -ne " Masa aktif (hari): "; read -r d
            if command -v noobzvpns &>/dev/null; then
                noobzvpns --add-user "$u" "$p" --expired-user "$u" "$d" 2>/dev/null \
                    && echo -e "${GREEN}[✓] Akun NoobzVPN $u dibuat!${NC}" \
                    || echo -e "${RED}[!] Gagal membuat akun NoobzVPN!${NC}"
            else
                echo -e "${RED}[!] NoobzVPN belum terinstall.${NC}"
                echo -e "${YELLOW}Hint: Jalankan auto-install atau install manual:${NC}"
                echo -e " wget -q https://github.com/noobz-id/noobzvpns/raw/main/install.sh && bash install.sh"
            fi ;;
        2)
            clear; echo -ne " Username: "; read -r u
            command -v noobzvpns &>/dev/null && \
                noobzvpns --del-user "$u" 2>/dev/null && \
                echo -e "${GREEN}[✓] $u dihapus!${NC}" || \
                echo -e "${RED}[!] Gagal atau NoobzVPN belum install!${NC}"
            ;;
        3)
            clear; echo -e "${CYAN}=== List Akun NoobzVPN ===${NC}"
            command -v noobzvpns &>/dev/null && noobzvpns --list-user 2>/dev/null \
                || echo -e "${RED}[!] NoobzVPN belum terinstall!${NC}"
            ;;
        4)
            clear; systemctl status noobzvpns --no-pager 2>/dev/null \
                || echo -e "${RED}Service tidak tersedia${NC}"
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_noobzvpn
}

# ===================================================
#  [06] SS-LIBEV MENU
# ===================================================
menu_ss() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BG_BLUE}${WHITE}${BOLD}               SHADOWSOCKS-LIBEV MENU                      ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Tambah  ${GREEN}[2]${NC} Hapus  ${GREEN}[3]${NC} List  ${GREEN}[0]${NC} Kembali Menu Utama     ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-3]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            clear; echo -e "${CYAN}=== TAMBAH AKUN SHADOWSOCKS ===${NC}"
            echo -ne " Username: "; read -r u; echo -ne " Password: "; read -r p
            echo -ne " Masa aktif: "; read -r d
            exp=$(date -d "+${d} days" +"%Y-%m-%d")
            echo "${u}|${p}|${exp}" >> /etc/shadowsocks/akun.txt
            SS_LINK="ss://$(echo -n "chacha20-ietf-poly1305:${p}" | base64 -w 0)@${IP_VPS}:8388#${u}"
            echo -e "${GREEN}[✓] Akun SS Dibuat!${NC}"
            echo -e " Pass: ${WHITE}$p${NC} | Method: ${WHITE}chacha20-ietf-poly1305${NC} | Port: ${WHITE}8388${NC}"
            echo -e " Expired: ${WHITE}$exp${NC}"
            echo -e " Link:\n ${YELLOW}$SS_LINK${NC}"
            ;;
        2)
            clear; echo -ne " Username: "; read -r u
            sed -i "/^${u}|/d" /etc/shadowsocks/akun.txt 2>/dev/null
            echo -e "${GREEN}[✓] $u dihapus!${NC}"
            ;;
        3)
            clear; echo -e "${CYAN}=== List Akun Shadowsocks ===${NC}"
            [ -f /etc/shadowsocks/akun.txt ] && while IFS='|' read -r u pw exp; do
                echo -e " ${WHITE}$u${NC} | ${YELLOW}$exp${NC}"; done < /etc/shadowsocks/akun.txt \
                || echo "Belum ada akun."
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_ss
}

# ===================================================
#  [07] INSTALL UDP CUSTOM
#  Binary: github.com/Haris131/UDP-Custom
# ===================================================
install_udp() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}       INSTALL UDP CUSTOM - ePro Dev Team                   ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}Binary: github.com/Haris131/UDP-Custom${NC}                     ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    mkdir -p /root/udp

    echo -e "\n ${YELLOW}[1/3]${NC} Download binary UDP Custom (udp-custom-linux-amd64)..."
    # Link binary ePro Dev yang telah terverifikasi di GitHub
    UDP_BIN="https://github.com/Haris131/UDP-Custom/raw/main/udp-custom-linux-amd64"
    if wget -q --show-progress "$UDP_BIN" -O /root/udp/udp-custom; then
        chmod +x /root/udp/udp-custom
        echo -e " ${GREEN}[✓]${NC} Binary UDP Custom berhasil!"
    else
        echo -e " ${RED}[✗]${NC} Gagal download! Coba link alternatif..."
        # Link alternatif dari repo lain yang sama
        UDP_ALT="https://raw.githubusercontent.com/feely666/udp-custom/main/udp-custom-linux-amd64"
        wget -q "$UDP_ALT" -O /root/udp/udp-custom 2>/dev/null && \
            chmod +x /root/udp/udp-custom && \
            echo -e " ${GREEN}[✓]${NC} Binary dari alternatif berhasil!" || \
            { echo -e " ${RED}[✗]${NC} Semua link gagal!"; echo -ne "\nTekan Enter..."; read -r; return; }
    fi

    echo -e "\n ${YELLOW}[2/3]${NC} Download config.json..."
    UDP_CFG="https://raw.githubusercontent.com/Haris131/UDP-Custom/main/config.json"
    wget -q "$UDP_CFG" -O /root/udp/config.json 2>/dev/null || \
        echo '{"listen":":36712","stream_buffer":16777216,"receive_buffer":16777216,"auth":{"mode":"passwords","passwords":[]}}' \
        > /root/udp/config.json
    echo -e " ${GREEN}[✓]${NC} Config siap"

    echo -e "\n ${YELLOW}[3/3]${NC} Setup systemd service..."
    cat > /etc/systemd/system/udp-custom.service <<'EOF'
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target
[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s
[Install]
WantedBy=default.target
EOF
    systemctl daemon-reload
    systemctl enable udp-custom --now &>/dev/null

    echo -e "\n${GREEN}[✓] UDP Custom berhasil diinstall!${NC}"
    echo -e " Status : $(svc_s udp-custom)"
    echo -e " Config : ${WHITE}/root/udp/config.json${NC}"
    echo -e " Port   : ${WHITE}36712${NC} (default)"
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [08] BACKUP / RESTORE
# ===================================================
menu_backup() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                   BACKUP / RESTORE                        ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Backup  ${GREEN}[2]${NC} Restore  ${GREEN}[0]${NC} Kembali                      ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-2]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            BFILE="/root/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            echo -e "${YELLOW}[*] Membuat backup...${NC}"
            tar -czf "$BFILE" /etc/xray /etc/vmess /etc/vless /etc/trojan \
                /etc/shadowsocks /etc/noobzvpns /root/udp /root/domain 2>/dev/null
            echo -e "${GREEN}[✓] Backup: ${WHITE}$BFILE${NC}"
            ;;
        2)
            echo -ne " Path file .tar.gz: "; read -r bf
            [ -f "$bf" ] && { tar -xzf "$bf" -C / 2>/dev/null; echo -e "${GREEN}[✓] Restore selesai!${NC}"; } \
                || echo -e "${RED}[!] File tidak ditemukan!${NC}"
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_backup
}

# ===================================================
#  [09] GOTOP X RAM
#  Binary: github.com/xxxserxxx/gotop
# ===================================================
gotop_ram() {
    clear
    if command -v gotop &>/dev/null; then
        gotop
    else
        echo -e "${YELLOW}[*] Mendownload gotop dari GitHub (xxxserxxx/gotop)...${NC}"
        GOTOP_VER=$(curl -sL "https://api.github.com/repos/xxxserxxx/gotop/releases/latest" \
            | grep tag_name | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
        [ -z "$GOTOP_VER" ] && GOTOP_VER="4.2.0"
        ARCH_TAG=$(uname -m | grep -q aarch64 && echo arm64 || echo amd64)
        GURL="https://github.com/xxxserxxx/gotop/releases/download/v${GOTOP_VER}/gotop_v${GOTOP_VER}_linux_${ARCH_TAG}.tgz"
        if wget -q --show-progress "$GURL" -O /tmp/gotop.tgz 2>/dev/null; then
            tar -xzf /tmp/gotop.tgz -C /usr/local/bin/ 2>/dev/null
            chmod +x /usr/local/bin/gotop && rm -f /tmp/gotop.tgz
            echo -e "${GREEN}[✓] Gotop v${GOTOP_VER} terinstall! Membuka...${NC}"
            sleep 1; gotop
        else
            echo -e "${RED}[!] Gotop gagal. Menampilkan info sistem:${NC}\n"
            echo -e "${CYAN}=== RAM ===${NC}"; free -h
            echo -e "\n${CYAN}=== TOP PROSES ===${NC}"; top -bn1 | head -20
            echo -ne "\nTekan Enter..."; read -r
        fi
    fi
}

# ===================================================
#  [10] RESTART ALL
# ===================================================
restart_all() {
    clear
    echo -e "${CYAN}=== RESTART ALL SERVICES ===${NC}\n"
    for svc in ssh sshd nginx haproxy xray dropbear noobzvpns udp-custom; do
        systemctl list-units --type=service 2>/dev/null | grep -q "${svc}" && {
            systemctl restart "$svc" 2>/dev/null && \
                echo -e " ${GREEN}[✓]${NC} $svc" || echo -e " ${RED}[✗]${NC} $svc gagal"
        }
    done
    echo -e "\n${GREEN}[✓] Selesai!${NC}"
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [11] TELEGRAM BOT
# ===================================================
menu_telebot() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                 SETUP TELEGRAM BOT                        ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    [ -f /root/.bot_token ] && echo -e " Token: ${YELLOW}$(cat /root/.bot_token)${NC}"
    echo -ne "\n Bot Token : "; read -r BOT_TOKEN
    echo -ne " Chat ID   : "; read -r CHAT_ID
    [ -z "$BOT_TOKEN" ] && { echo -e "${RED}[!] Token kosong!${NC}"; echo -ne "\nTekan Enter..."; read -r; return; }
    echo "$BOT_TOKEN" > /root/.bot_token
    echo "$CHAT_ID"   > /root/.chat_id
    RESP=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}&text=✅ Bot VPS Aktif!%0A🖥 IP: ${IP_VPS}%0A📅 $(date)" 2>/dev/null)
    echo "$RESP" | grep -q '"ok":true' && \
        echo -e "${GREEN}[✓] Bot berhasil! Pesan test dikirim.${NC}" || \
        echo -e "${RED}[!] Gagal. Cek token/chat_id!${NC}"
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [12] UPDATE MENU
# ===================================================
update_menu() {
    clear
    echo -e "${CYAN}[*] Mengupdate script dari GitHub...${NC}"
    SELF_PATH="$(realpath "$0")"
    UPDATE_URL="https://raw.githubusercontent.com/st4nyel/vps-script/main/menu.sh"
    if wget -q --timeout=10 "$UPDATE_URL" -O /tmp/menu_update.sh 2>/dev/null && \
       [ -s /tmp/menu_update.sh ]; then
        cp /tmp/menu_update.sh "$SELF_PATH"
        chmod +x "$SELF_PATH"
        echo -e "${GREEN}[✓] Script diupdate! Restart untuk menerapkan perubahan.${NC}"
    else
        echo -e "${YELLOW}[!] Update gagal. Script tetap versi saat ini.${NC}"
    fi
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [13] RUNNING PROCESSES
# ===================================================
running_services() {
    clear
    echo -e "${CYAN}=== STATUS SERVICE VPN ===${NC}\n"
    for svc in ssh nginx haproxy xray dropbear noobzvpns udp-custom; do
        printf " %-15s : %s\n" "$svc" "$(svc_s "$svc")"
    done
    echo -e "\n${CYAN}=== TOP PROSES (CPU) ===${NC}"
    ps aux --sort=-%cpu 2>/dev/null | head -15
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [14] INFO PORT
# ===================================================
info_port() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                  INFO PORT AKTIF                          ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    declare -A PM
    PM[22]="SSH" PM[80]="HTTP" PM[443]="HTTPS/TLS Xray"
    PM[1194]="OpenVPN" PM[2083]="Xray CDN" PM[2096]="Xray CDN"
    PM[8080]="HTTP Custom" PM[8388]="Shadowsocks" PM[36712]="UDP Custom"
    PM[40000]="NoobzVPN" PM[8443]="Dropbear"
    printf "\n %-10s %s\n" "PORT" "SERVICE"
    echo "────────────────────────────────"
    ss -tlnp 2>/dev/null | awk 'NR>1{print $4}' | rev | cut -d: -f1 | rev | sort -n | uniq | \
    while read -r port; do
        printf " %-10s %s\n" "$port" "${PM[$port]:-Unknown}"
    done
    echo -e "\n${CYAN}=== Detail Listen ===${NC}"
    ss -tlnp 2>/dev/null | grep LISTEN
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [15] MENU BOT
# ===================================================
menu_bot() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                      MENU BOT AUTO                        ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Setup Telegram Bot           ${GREEN}[3]${NC} Auto Delete Expired     ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[2]${NC} Notif Login SSH              ${GREEN}[4]${NC} Test Notif              ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[0]${NC} Kembali Menu Utama                                      ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-4]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1) menu_telebot ;;
        2)
            BOT_TOKEN=$(cat /root/.bot_token 2>/dev/null)
            [ -z "$BOT_TOKEN" ] && { echo -e "${RED}[!] Setup bot dulu di [1]!${NC}"; echo -ne "\nTekan Enter..."; read -r; menu_bot; return; }
            cat > /usr/local/bin/ssh-notify.sh <<EOF
#!/bin/bash
BOT=\$(cat /root/.bot_token 2>/dev/null)
CID=\$(cat /root/.chat_id 2>/dev/null)
[ -z "\$BOT" ] && exit
curl -s "https://api.telegram.org/bot\${BOT}/sendMessage" \
    -d "chat_id=\${CID}&text=🔐 SSH Login%0A👤 User: \$PAM_USER%0A🌐 IP: \$PAM_RHOST%0A📅 \$(date)" &>/dev/null
EOF
            chmod +x /usr/local/bin/ssh-notify.sh
            grep -q "ssh-notify" /etc/pam.d/sshd 2>/dev/null || \
                echo "session optional pam_exec.so /usr/local/bin/ssh-notify.sh" >> /etc/pam.d/sshd
            echo -e "${GREEN}[✓] Notif login SSH diaktifkan!${NC}" ;;
        3)
            cat > /etc/cron.daily/auto-del-expired <<'EOF'
#!/bin/bash
TODAY=$(date +%Y-%m-%d)
for f in /etc/vmess/akun.txt /etc/vless/akun.txt /etc/trojan/akun.txt /etc/shadowsocks/akun.txt; do
    [ -f "$f" ] || continue
    while IFS='|' read -r u rest; do
        exp="${rest##*|}"
        [[ "$exp" < "$TODAY" ]] && sed -i "/^${u}|/d" "$f"
    done < "$f"
done
EOF
            chmod +x /etc/cron.daily/auto-del-expired
            echo -e "${GREEN}[✓] Auto delete expired diaktifkan!${NC}" ;;
        4)
            BOT_TOKEN=$(cat /root/.bot_token 2>/dev/null)
            CHAT_ID=$(cat /root/.chat_id 2>/dev/null)
            [ -n "$BOT_TOKEN" ] && \
                curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                -d "chat_id=${CHAT_ID}&text=🔔 Test notif VPS ${IP_VPS} - $(date)" &>/dev/null && \
                echo -e "${GREEN}[✓] Test dikirim!${NC}" || echo -e "${RED}[!] Setup bot dulu!${NC}" ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; menu_bot
}

# ===================================================
#  [16] CHANGE DOMAIN
# ===================================================
change_domain() {
    clear
    echo -e "${CYAN}=== GANTI DOMAIN ===${NC}"
    echo -e " Domain saat ini: ${WHITE}${DOMAIN}${NC}"
    echo -ne "\n Domain baru: "; read -r nd
    [ -n "$nd" ] && {
        echo "$nd" > /root/domain
        mkdir -p /etc/xray && echo "$nd" > /etc/xray/domain
        DOMAIN="$nd"
        echo -e "${GREEN}[✓] Domain diubah ke: ${WHITE}$nd${NC}"
    } || echo -e "${RED}[!] Domain tidak boleh kosong!${NC}"
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [17] FIX CERTIFICATE
# ===================================================
fix_cert() {
    clear
    echo -e "${CYAN}=== FIX SSL CERTIFICATE (Let's Encrypt) ===${NC}"
    echo -e " Domain: ${WHITE}${DOMAIN}${NC}"
    [ "$DOMAIN" = "yourdomain.com" ] && {
        echo -e "${RED}[!] Set domain dulu via menu [16]!${NC}"; echo -ne "\nTekan Enter..."; read -r; return
    }
    command -v certbot &>/dev/null || apt-get install -y certbot -qq 2>/dev/null
    systemctl stop nginx 2>/dev/null
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos \
        --email "admin@${DOMAIN}" 2>/dev/null && {
        mkdir -p /etc/xray/ssl
        cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/xray/ssl/ 2>/dev/null
        cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem   /etc/xray/ssl/ 2>/dev/null
        echo -e "${GREEN}[✓] SSL Certificate berhasil diperbarui!${NC}"
    } || echo -e "${RED}[!] Gagal! Pastikan domain $DOMAIN mengarah ke IP: $IP_VPS${NC}"
    systemctl start nginx 2>/dev/null
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [18] CHANGE BANNER
# ===================================================
change_banner() {
    clear
    echo -e "${CYAN}=== UBAH BANNER / MOTD ===${NC}"
    echo -e " Banner saat ini:"; cat /etc/motd 2>/dev/null || echo "(kosong)"
    echo -e "\n Masukkan teks banner baru (Ctrl+D selesai):"
    echo -e "${YELLOW}─────────────────────────${NC}"
    cat > /etc/motd
    cp /etc/motd /etc/ssh/banner 2>/dev/null
    grep -q "Banner" /etc/ssh/sshd_config 2>/dev/null || \
        echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "${GREEN}[✓] Banner diubah!${NC}"
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [19] RESTART BANNER
# ===================================================
restart_banner() {
    clear
    cat > /etc/motd <<'EOF'
╔══════════════════════════════════════════════════╗
║      Welcome To Script Premium St A1 Nyel       ║
║              >> GRATIS KITA <<                  ║
╚══════════════════════════════════════════════════╝
EOF
    echo -e "${GREEN}[✓] Banner direset ke default!${NC}"
    sleep 1
}

# ===================================================
#  [20] SPEEDTEST
#  Script: github.com/sivel/speedtest-cli (speedtest.py)
# ===================================================
run_speedtest() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                   SPEEDTEST VPS                           ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}Script: github.com/sivel/speedtest-cli${NC}                    ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}\n"

    SPURL="https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py"

    if command -v speedtest-cli &>/dev/null; then
        echo -e "${YELLOW}[*] Menjalankan speedtest...${NC}\n"
        python3 /usr/local/bin/speedtest-cli --simple 2>/dev/null || \
            /usr/local/bin/speedtest-cli --simple 2>/dev/null || \
            speedtest-cli --simple
    elif command -v speedtest &>/dev/null; then
        speedtest
    else
        echo -e "${YELLOW}[*] Download speedtest-cli...${NC}"
        wget -q "$SPURL" -O /usr/local/bin/speedtest-cli && \
            chmod +x /usr/local/bin/speedtest-cli && \
            echo -e "${GREEN}[✓] Terinstall! Menjalankan...\n${NC}" && \
            python3 /usr/local/bin/speedtest-cli --simple 2>/dev/null || \
            echo -e "${RED}[!] Perlu python3!${NC}"
    fi
    echo -ne "\nTekan Enter..."; read -r
}

# ===================================================
#  [21] EKSTRAK MENU
# ===================================================
ekstrak_menu() {
    clear
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}${BOLD}${WHITE}                    EKSTRAK MENU                           ${NC}${CYAN}│${NC}"
    echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[1]${NC} Export Semua Akun   ${GREEN}[2]${NC} Lihat Export   ${GREEN}[3]${NC} Generate Config ${CYAN}│${NC}"
    echo -e "${CYAN}│${NC} ${GREEN}[0]${NC} Kembali Menu Utama                                      ${CYAN}│${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo -ne " Pilih ${CYAN}[0-3]${NC} ${YELLOW}>>>${NC} "
    read -r opt
    case "$opt" in
        1)
            EF="/root/export_$(date +%Y%m%d_%H%M%S).txt"
            {
                echo "=== EXPORT AKUN VPS - $(date) ==="
                echo "IP: $IP_VPS | Domain: $DOMAIN"
                echo ""
                echo "=== SSH ===" && awk -F: '$7~/false|nologin/{print $1}' /etc/passwd 2>/dev/null
                echo "=== VMESS ===" && cat /etc/vmess/akun.txt 2>/dev/null || echo "Kosong"
                echo "=== VLESS ===" && cat /etc/vless/akun.txt 2>/dev/null || echo "Kosong"
                echo "=== TROJAN ===" && cat /etc/trojan/akun.txt 2>/dev/null || echo "Kosong"
                echo "=== SHADOWSOCKS ===" && cat /etc/shadowsocks/akun.txt 2>/dev/null || echo "Kosong"
            } > "$EF"
            echo -e "${GREEN}[✓] Diekspor ke: ${WHITE}$EF${NC}"
            ;;
        2)
            EF=$(ls -t /root/export_*.txt 2>/dev/null | head -1)
            [ -n "$EF" ] && cat "$EF" || echo -e "${RED}[!] Belum ada file export!${NC}"
            ;;
        3)
            mkdir -p /etc/xray
            cat > /etc/xray/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {"port": 443, "protocol": "vless",
     "settings": {"clients": [], "decryption": "none"},
     "streamSettings": {
       "network": "ws", "security": "tls",
       "wsSettings": {"path": "/vless"},
       "tlsSettings": {
         "serverName": "${DOMAIN}",
         "certificates": [{"certificateFile": "/etc/xray/ssl/fullchain.pem", "keyFile": "/etc/xray/ssl/privkey.pem"}]
       }
     }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
            echo -e "${GREEN}[✓] Config Xray dibuat: /etc/xray/config.json${NC}"
            ;;
        0) main; return ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
    esac
    echo -ne "\nTekan Enter..."; read -r; ekstrak_menu
}

# ===================================================
#  MAIN LOOP
# ===================================================
main() {
    get_system_info
    check_services
    show_header
    show_menu
    read -r OPTION
    case "$OPTION" in
        1)  menu_ssh ;;
        2)  menu_vmess ;;
        3)  menu_vless ;;
        4)  menu_trojan ;;
        5)  menu_noobzvpn ;;
        6)  menu_ss ;;
        7)  install_udp ;;
        8)  menu_backup ;;
        9)  gotop_ram ;;
        10) restart_all ;;
        11) menu_telebot ;;
        12) update_menu ;;
        13) running_services ;;
        14) info_port ;;
        15) menu_bot ;;
        16) change_domain ;;
        17) fix_cert ;;
        18) change_banner ;;
        19) restart_banner ;;
        20) run_speedtest ;;
        21) ekstrak_menu ;;
        0|q|Q|exit|quit)
            echo -e "\n${YELLOW}Keluar dari script. Sampai jumpa!${NC}\n"; exit 0 ;;
        *)
            echo -e "${RED}[!] Pilihan tidak valid! Masukkan angka 1-21.${NC}"; sleep 1 ;;
    esac
    main
}

# ===================================================
#  ENTRY POINT
# ===================================================
DEPS_LOCK="/tmp/.st_a1_nyel_done"
if [ ! -f "$DEPS_LOCK" ]; then
    auto_install_deps
    touch "$DEPS_LOCK"
fi

main
# NOTE: File ini lengkap dan siap digunakan.
# Untuk install ke VPS:
#   wget -O menu.sh <URL> && chmod +x menu.sh && sudo bash menu.sh
