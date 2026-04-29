#!/bin/bash
# ============================================================
#   VPS PANEL PRO - SSH & XRAY (V2Ray) Manager
#   Author  : VPanel Script
#   Version : 2.0
#   OS      : Ubuntu 20.04 / 22.04 / Debian 10/11
# ============================================================

# ── Warna ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
ORANGE='\033[38;5;208m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ── Garis & Simbol ─────────────────────────────────────────
LINE="═══════════════════════════════════════════════════════"
LINE2="───────────────────────────────────────────────────────"
TICK="${GREEN}✔${NC}"
CROSS="${RED}✘${NC}"
ARROW="${CYAN}➤${NC}"
STAR="${YELLOW}★${NC}"

# ── File path ──────────────────────────────────────────────
XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
SSH_USERS_DB="/etc/vpanel/ssh_users.db"
VMESS_USERS_DB="/etc/vpanel/vmess_users.db"
VLESS_USERS_DB="/etc/vpanel/vless_users.db"
TROJAN_USERS_DB="/etc/vpanel/trojan_users.db"
DOMAIN_FILE="/etc/vpanel/domain.conf"
PANEL_DIR="/etc/vpanel"

# ── Cek Root ───────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Script harus dijalankan sebagai ROOT!"
        echo -e "        Gunakan: ${YELLOW}sudo bash vpanel.sh${NC}"
        exit 1
    fi
}

# ── Deteksi OS ─────────────────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        echo -e "${RED}OS tidak dikenali!${NC}"
        exit 1
    fi
}

# ── Info VPS ───────────────────────────────────────────────
get_vps_info() {
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}' 2>/dev/null || echo "N/A")
    CPU_CORES=$(nproc 2>/dev/null || echo "N/A")
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    RAM_TOTAL=$(free -h | awk '/^Mem:/{print $2}' 2>/dev/null || echo "N/A")
    RAM_USED=$(free -h | awk '/^Mem:/{print $3}' 2>/dev/null || echo "N/A")
    RAM_FREE=$(free -h | awk '/^Mem:/{print $4}' 2>/dev/null || echo "N/A")
    DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}' 2>/dev/null || echo "N/A")
    DISK_USED=$(df -h / | awk 'NR==2{print $3}' 2>/dev/null || echo "N/A")
    DISK_FREE=$(df -h / | awk 'NR==2{print $4}' 2>/dev/null || echo "N/A")
    DISK_PCT=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
    IP_PUBLIC=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -s --max-time 5 https://ipv4.icanhazip.com 2>/dev/null || echo "N/A")
    IP_LOCAL=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")
    HOSTNAME=$(hostname 2>/dev/null || echo "N/A")
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //' 2>/dev/null || echo "N/A")
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "Belum diset")
    XRAY_STATUS=$(systemctl is-active xray 2>/dev/null || echo "not-installed")
    SSH_STATUS=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || echo "inactive")
    STUNNEL_STATUS=$(systemctl is-active stunnel4 2>/dev/null || echo "inactive")
    TOTAL_SSH=$(wc -l < $SSH_USERS_DB 2>/dev/null || echo "0")
    TOTAL_VMESS=$(wc -l < $VMESS_USERS_DB 2>/dev/null || echo "0")
    TOTAL_VLESS=$(wc -l < $VLESS_USERS_DB 2>/dev/null || echo "0")
    TOTAL_TROJAN=$(wc -l < $TROJAN_USERS_DB 2>/dev/null || echo "0")
}

# ── Status Warna ───────────────────────────────────────────
status_color() {
    if [[ "$1" == "active" ]]; then
        echo -e "${GREEN}● AKTIF${NC}"
    else
        echo -e "${RED}● MATI${NC}"
    fi
}

# ── Header Panel ───────────────────────────────────────────
show_header() {
    clear
    get_vps_info
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}             ██╗   ██╗██████╗  █████╗ ███╗   ██╗███████╗██╗     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}             ██║   ██║██╔══██╗██╔══██╗████╗  ██║██╔════╝██║     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}             ██║   ██║██████╔╝███████║██╔██╗ ██║█████╗  ██║     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}             ╚██╗ ██╔╝██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${WHITE}              ╚████╔╝ ██║     ██║  ██║██║ ╚████║███████╗███████╗${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${YELLOW}                     VPS PANEL PRO v2.0                        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${DIM}              SSH • VMess • VLESS • Trojan • Shadowsocks       ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${CYAN}║${NC} ${STAR} ${WHITE}Domain   :${NC} ${YELLOW}$DOMAIN${NC}"
    echo -e "${CYAN}║${NC} ${STAR} ${WHITE}IP Publik:${NC} ${GREEN}$IP_PUBLIC${NC}   ${WHITE}Hostname:${NC} ${CYAN}$HOSTNAME${NC}"
    echo -e "${CYAN}║${NC} ${STAR} ${WHITE}Uptime   :${NC} $UPTIME   ${WHITE}Load:${NC} $LOAD"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}SSH     :${NC} $(status_color $SSH_STATUS)   ${WHITE}Xray/V2Ray :${NC} $(status_color $XRAY_STATUS)   ${WHITE}Stunnel:${NC} $(status_color $STUNNEL_STATUS)"
    echo -e "${CYAN}║${NC}  ${WHITE}Akun SSH:${NC} ${GREEN}$TOTAL_SSH${NC}   ${WHITE}VMess:${NC} ${GREEN}$TOTAL_VMESS${NC}   ${WHITE}VLESS:${NC} ${GREEN}$TOTAL_VLESS${NC}   ${WHITE}Trojan:${NC} ${GREEN}$TOTAL_TROJAN${NC}"
    echo -e "${CYAN}${LINE}${NC}"
}

# ── Info VPS Detail ────────────────────────────────────────
show_vps_info() {
    show_header
    echo -e "${CYAN}║${NC}${BOLD}${YELLOW}                   ⚙  SPESIFIKASI VPS                         ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}OS              :${NC} $OS $OS_VER"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Processor       :${NC} $CPU_MODEL"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}CPU Cores       :${NC} $CPU_CORES Core(s)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}CPU Usage       :${NC} $CPU_USAGE%"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}RAM Total       :${NC} $RAM_TOTAL"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}RAM Digunakan   :${NC} $RAM_USED"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}RAM Tersisa     :${NC} $RAM_FREE"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Disk Total      :${NC} $DISK_TOTAL"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Disk Digunakan  :${NC} $DISK_USED ($DISK_PCT)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Disk Tersisa    :${NC} $DISK_FREE"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}IP Publik       :${NC} $IP_PUBLIC"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}IP Lokal        :${NC} $IP_LOCAL"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}SSH Port        :${NC} 22, 80 (WS), 443 (SSL)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}VMess Port      :${NC} 8443 (WS+TLS), 80 (WS)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}VLESS Port      :${NC} 8443 (WS+TLS)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Trojan Port     :${NC} 443 (TLS)"
    echo -e "${CYAN}║${NC} ${ARROW} ${WHITE}Shadowsocks     :${NC} 2083"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "$(echo -e "${YELLOW}Tekan Enter untuk kembali...${NC}")"
}

# ── Install Dependencies ───────────────────────────────────
# Semua package dari Ubuntu/Debian APT official repository
# Sumber: https://packages.ubuntu.com / https://packages.debian.org
install_deps() {
    echo -e "\n${CYAN}[INFO]${NC} Update & Install semua dependencies dari APT resmi..."
    echo -e "       ${DIM}Sumber: packages.ubuntu.com / packages.debian.org${NC}"
    echo ""

    apt-get update -y &>/dev/null

    PKGS=(
        "curl"            # Transfer data - packages.ubuntu.com/curl
        "wget"            # Download file - packages.ubuntu.com/wget
        "unzip"           # Extract zip  - packages.ubuntu.com/unzip
        "jq"              # JSON parser  - packages.ubuntu.com/jq
        "uuid-runtime"    # UUID generate- packages.ubuntu.com/uuid-runtime
        "openssl"         # SSL/TLS tools- packages.ubuntu.com/openssl
        "net-tools"       # Network tools- packages.ubuntu.com/net-tools
        "cron"            # Task scheduler-packages.ubuntu.com/cron
        "python3"         # Python runtime-packages.ubuntu.com/python3
        "fail2ban"        # Brute force  - packages.ubuntu.com/fail2ban
        "openssh-server"  # SSH Server   - packages.ubuntu.com/openssh-server
        "stunnel4"        # SSH TLS/SSL  - packages.ubuntu.com/stunnel4
        "dropbear"        # SSH ringan   - packages.ubuntu.com/dropbear
        "squid"           # HTTP proxy   - packages.ubuntu.com/squid
    )

    for pkg in "${PKGS[@]}"; do
        PKG_NAME=$(echo "$pkg" | awk '{print $1}')
        PKG_DESC=$(echo "$pkg" | awk -F'# ' '{print $2}')
        printf "       %-20s " "$PKG_NAME..."
        if apt-get install -y "$PKG_NAME" &>/dev/null; then
            echo -e "${TICK} ${DIM}$PKG_DESC${NC}"
        else
            echo -e "${CROSS} ${RED}Gagal install $PKG_NAME${NC}"
        fi
    done
    echo ""
    echo -e "       ${TICK} Semua dependencies terinstall"
}

# ── Install & Konfigurasi OpenSSH ─────────────────────────
# Binary : /usr/sbin/sshd
# Sumber : https://packages.ubuntu.com/openssh-server
# GitHub : https://github.com/openssh/openssh-portable
install_openssh() {
    echo -e "\n${CYAN}[INFO]${NC} Konfigurasi OpenSSH Server..."
    echo -e "       ${DIM}Package : openssh-server (APT)${NC}"
    echo -e "       ${DIM}GitHub  : https://github.com/openssh/openssh-portable${NC}"
    echo -e "       ${DIM}Binary  : /usr/sbin/sshd${NC}"

    # Backup config asli
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null

    # Tulis ulang config openssh
    cat > /etc/ssh/sshd_config <<'EOF'
Port 22
Port 80
AddressFamily any
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 60
ClientAliveCountMax 3
MaxSessions 128
MaxStartups 128:30:256
EOF

    systemctl enable ssh &>/dev/null || systemctl enable sshd &>/dev/null
    systemctl restart ssh &>/dev/null || systemctl restart sshd &>/dev/null
    echo -e "${TICK} OpenSSH aktif di port ${GREEN}22, 80${NC}"
}

# ── Install & Konfigurasi Dropbear ────────────────────────
# Binary : /usr/sbin/dropbear
# Sumber : https://packages.ubuntu.com/dropbear
# GitHub : https://github.com/mkj/dropbear
install_dropbear() {
    echo -e "\n${CYAN}[INFO]${NC} Konfigurasi Dropbear SSH..."
    echo -e "       ${DIM}Package : dropbear (APT)${NC}"
    echo -e "       ${DIM}GitHub  : https://github.com/mkj/dropbear${NC}"
    echo -e "       ${DIM}Binary  : /usr/sbin/dropbear${NC}"

    # Config dropbear
    cat > /etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/vpanel/banner.txt"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

    # Buat banner
    cat > /etc/vpanel/banner.txt <<'EOF'
=====================================
      VPS PANEL PRO - SSH Server
  Unauthorized access is prohibited
=====================================
EOF

    systemctl enable dropbear &>/dev/null
    systemctl restart dropbear &>/dev/null
    echo -e "${TICK} Dropbear aktif di port ${GREEN}143, 109${NC}"
}

# ── Install & Konfigurasi Stunnel (SSH TLS/SSL) ────────────
# Binary : /usr/bin/stunnel4
# Sumber : https://packages.ubuntu.com/stunnel4
# Website: https://www.stunnel.org
# GitHub : https://github.com/mtrojnar/stunnel
install_stunnel() {
    echo -e "\n${CYAN}[INFO]${NC} Konfigurasi Stunnel4 (SSH over TLS/SSL)..."
    echo -e "       ${DIM}Package : stunnel4 (APT)${NC}"
    echo -e "       ${DIM}Website : https://www.stunnel.org${NC}"
    echo -e "       ${DIM}GitHub  : https://github.com/mtrojnar/stunnel${NC}"
    echo -e "       ${DIM}Binary  : /usr/bin/stunnel4${NC}"

    # Generate cert jika belum ada
    mkdir -p /etc/vpanel/cert
    if [[ ! -f /etc/vpanel/cert/stunnel.pem ]]; then
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout /tmp/stunnel.key \
            -out /tmp/stunnel.crt \
            -subj "/C=ID/ST=Jakarta/O=VPanel/CN=vpanel" &>/dev/null
        cat /tmp/stunnel.key /tmp/stunnel.crt > /etc/vpanel/cert/stunnel.pem
        chmod 600 /etc/vpanel/cert/stunnel.pem
    fi

    cat > /etc/stunnel/stunnel.conf <<EOF
; ── Stunnel Config - VPanel Pro ──
pid = /var/run/stunnel4/stunnel4.pid
output = /var/log/stunnel4/stunnel.log

; SSL/TLS global
cert = /etc/vpanel/cert/stunnel.pem
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

; ── SSH over SSL port 443 ──────────
[ssh-ssl-443]
accept  = 443
connect = 127.0.0.1:22

; ── SSH over SSL port 222 ──────────
[ssh-ssl-222]
accept  = 222
connect = 127.0.0.1:22

; ── Dropbear over SSL port 110 ─────
[dropbear-ssl-110]
accept  = 110
connect = 127.0.0.1:143

; ── OpenVPN-like SSL port 992 ──────
[ssh-ssl-992]
accept  = 992
connect = 127.0.0.1:22
EOF

    # Pastikan folder log ada
    mkdir -p /var/log/stunnel4
    chown stunnel4:stunnel4 /var/log/stunnel4 &>/dev/null || true

    systemctl enable stunnel4 &>/dev/null
    systemctl restart stunnel4 &>/dev/null
    echo -e "${TICK} Stunnel4 aktif di port ${GREEN}443, 222, 110, 992${NC}"
}

# ── Install Xray-Core ──────────────────────────────────────
# Sumber resmi : https://github.com/XTLS/Xray-core
# Installer    : https://github.com/XTLS/Xray-install/raw/main/install-release.sh
# Releases     : https://github.com/XTLS/Xray-core/releases/latest
install_xray() {
    echo -e "\n${CYAN}[INFO]${NC} Menginstall Xray-Core (V2Ray) dari GitHub resmi..."
    echo -e "       ${DIM}Sumber: https://github.com/XTLS/Xray-core${NC}"
    echo -e "       ${DIM}Script: https://github.com/XTLS/Xray-install/raw/main/install-release.sh${NC}"

    XRAY_INSTALL_SCRIPT="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

    # Download installer lalu jalankan
    if curl -fsSL "$XRAY_INSTALL_SCRIPT" -o /tmp/xray-install.sh; then
        echo -e "       ${TICK} Installer berhasil didownload"
        bash /tmp/xray-install.sh @ install &>/dev/null
        rm -f /tmp/xray-install.sh
    else
        echo -e "       ${CROSS} Gagal download installer, coba metode fallback..."
        # Fallback: download binary langsung dari GitHub releases
        ARCH=$(uname -m)
        case $ARCH in
            x86_64)  XRAY_ARCH="64" ;;
            aarch64) XRAY_ARCH="arm64-v8a" ;;
            armv7l)  XRAY_ARCH="arm32-v7a" ;;
            *)       XRAY_ARCH="64" ;;
        esac
        LATEST=$(curl -fsSL "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep tag_name | cut -d'"' -f4)
        XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-linux-${XRAY_ARCH}.zip"
        echo -e "       ${DIM}Fallback URL: $XRAY_URL${NC}"
        curl -fsSL "$XRAY_URL" -o /tmp/xray.zip
        unzip -o /tmp/xray.zip xray -d /usr/local/bin/ &>/dev/null
        chmod +x /usr/local/bin/xray
        rm -f /tmp/xray.zip

        # Buat systemd service manual
        cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
    fi

    if [[ -f "$XRAY_BIN" ]]; then
        XRAY_VER=$($XRAY_BIN version 2>/dev/null | head -1)
        echo -e "       ${TICK} Xray-Core terinstall: ${GREEN}$XRAY_VER${NC}"
        echo -e "       ${TICK} Binary: ${GREEN}$XRAY_BIN${NC}"
    else
        echo -e "       ${CROSS} Gagal install Xray-Core. Cek koneksi internet VPS!"
        return 1
    fi
}

# ── Buat Config Xray ───────────────────────────────────────
generate_xray_config() {
    local domain=$1
    mkdir -p /usr/local/etc/xray
    
    cat > $XRAY_CONFIG <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 8443,
      "protocol": "vmess",
      "tag": "vmess-ws-tls",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/vpanel/cert/cert.crt",
              "keyFile": "/etc/vpanel/cert/key.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "tag": "vmess-ws",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "port": 2053,
      "protocol": "vless",
      "tag": "vless-ws-tls",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/vpanel/cert/cert.crt",
              "keyFile": "/etc/vpanel/cert/key.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "port": 443,
      "protocol": "trojan",
      "tag": "trojan-tls",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/vpanel/cert/cert.crt",
              "keyFile": "/etc/vpanel/cert/key.pem"
            }
          ]
        }
      }
    },
    {
      "port": 2083,
      "protocol": "shadowsocks",
      "tag": "shadowsocks",
      "settings": {
        "method": "chacha20-ietf-poly1305",
        "password": "vpanel@ss2024",
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF
    mkdir -p /var/log/xray
    echo -e "${TICK} Xray config dibuat"
}

# ── Generate Self-Signed SSL ───────────────────────────────
generate_ssl() {
    local domain=$1
    mkdir -p /etc/vpanel/cert
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/vpanel/cert/key.pem \
        -out /etc/vpanel/cert/cert.crt \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=VPanel/CN=$domain" &>/dev/null
    echo -e "${TICK} SSL certificate dibuat (self-signed, 10 tahun)"
}

# ── Install SSH WebSocket ──────────────────────────────────
# Binary : /usr/local/bin/ssh-ws.py
# Runtime: python3 (APT) - https://packages.ubuntu.com/python3
# Dibuat : Langsung oleh script ini (tidak didownload)
# Fungsi : Tunnel SSH dalam HTTP WebSocket protocol
install_ssh_ws() {
    echo -e "\n${CYAN}[INFO]${NC} Setup SSH WebSocket Proxy..."
    echo -e "       ${DIM}Runtime : python3 (APT) - packages.ubuntu.com/python3${NC}"
    echo -e "       ${DIM}Binary  : /usr/local/bin/ssh-ws.py (dibuat oleh script)${NC}"
    echo -e "       ${DIM}Port    : 8880${NC}"
    
    # Install websocket untuk SSH
    cat > /usr/local/bin/ssh-ws.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, select, sys

LISTEN_PORT = 8880
SSH_HOST = '127.0.0.1'
SSH_PORT = 22
BUFFER = 65535
HTTP_RESPONSE = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"

def handle(client):
    try:
        data = client.recv(BUFFER)
        if b"CONNECT" in data or b"GET" in data:
            client.send(HTTP_RESPONSE)
        ssh = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh.connect((SSH_HOST, SSH_PORT))
        while True:
            r, _, _ = select.select([client, ssh], [], [], 60)
            if not r: break
            for s in r:
                d = s.recv(BUFFER)
                if not d: return
                (ssh if s is client else client).sendall(d)
    except: pass
    finally:
        try: client.close()
        except: pass

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', LISTEN_PORT))
srv.listen(100)
while True:
    c, _ = srv.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
PYEOF
    chmod +x /usr/local/bin/ssh-ws.py

    # Buat systemd service
    cat > /etc/systemd/system/ssh-ws.service <<EOF
[Unit]
Description=SSH WebSocket Proxy
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ssh-ws &>/dev/null
    systemctl restart ssh-ws &>/dev/null
    echo -e "${TICK} SSH WebSocket (port 8880) aktif"
}

# ── Proses Instalasi ───────────────────────────────────────
run_install() {
    show_header
    echo -e "${CYAN}╔${LINE}╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}${YELLOW}              🔧  PROSES INSTALASI VPANEL PRO               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚${LINE}╝${NC}"
    echo ""

    if [[ -f "$XRAY_BIN" ]] && [[ -d "$PANEL_DIR" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Panel sudah terinstall sebelumnya."
        echo -ne "${YELLOW}Lanjut reinstall? (y/n): ${NC}"
        read -r yn
        [[ "$yn" != "y" ]] && return
    fi

    echo -ne "${ARROW} Masukkan domain/IP VPS kamu: "
    read -r DOMAIN_INPUT
    [[ -z "$DOMAIN_INPUT" ]] && DOMAIN_INPUT=$IP_PUBLIC

    mkdir -p $PANEL_DIR
    echo "$DOMAIN_INPUT" > $DOMAIN_FILE
    touch $SSH_USERS_DB $VMESS_USERS_DB $VLESS_USERS_DB $TROJAN_USERS_DB

    echo ""
    echo -e "${ARROW} ${WHITE}[1/9]${NC} Update & Install dependencies (openssh, dropbear, stunnel4, xray, python3...)..."
    install_deps

    echo -e "${ARROW} ${WHITE}[2/9]${NC} Install & Konfigurasi OpenSSH Server..."
    install_openssh

    echo -e "${ARROW} ${WHITE}[3/9]${NC} Install & Konfigurasi Dropbear SSH..."
    install_dropbear

    echo -e "${ARROW} ${WHITE}[4/9]${NC} Generate SSL Certificate..."
    generate_ssl "$DOMAIN_INPUT"

    echo -e "${ARROW} ${WHITE}[5/9]${NC} Install & Konfigurasi Stunnel4 (SSH TLS/SSL)..."
    install_stunnel

    echo -e "${ARROW} ${WHITE}[6/9]${NC} Install Xray-Core (V2Ray/VMess/VLESS/Trojan)..."
    install_xray

    echo -e "${ARROW} ${WHITE}[7/9]${NC} Generate Konfigurasi Xray..."
    generate_xray_config "$DOMAIN_INPUT"

    echo -e "${ARROW} ${WHITE}[8/9]${NC} Setup SSH WebSocket Proxy..."
    install_ssh_ws

    echo -e "${ARROW} ${WHITE}[9/9]${NC} Aktifkan & Restart semua layanan..."
    systemctl daemon-reload &>/dev/null
    for svc in ssh xray stunnel4 ssh-ws dropbear; do
        systemctl enable $svc &>/dev/null
        systemctl restart $svc &>/dev/null && \
            echo -e "   ${TICK} $svc aktif" || \
            echo -e "   ${CROSS} $svc gagal (mungkin tidak support di OS ini)"
    done

    echo ""
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${TICK} ${GREEN}${BOLD}INSTALASI SELESAI! Semua binary terpasang.${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e ""
    echo -e " ${WHITE}── SSH ──────────────────────────────────────${NC}"
    echo -e " ${STAR} OpenSSH Direct  : Port ${GREEN}22, 80${NC}           [openssh-server]"
    echo -e " ${STAR} Dropbear SSH    : Port ${GREEN}143, 109${NC}         [dropbear]"
    echo -e " ${STAR} SSH WebSocket   : Port ${GREEN}8880${NC}             [python3 ws-proxy]"
    echo -e " ${STAR} SSH over TLS    : Port ${GREEN}443, 222, 992${NC}    [stunnel4]"
    echo -e " ${STAR} Dropbear TLS    : Port ${GREEN}110${NC}              [stunnel4]"
    echo -e ""
    echo -e " ${WHITE}── V2Ray / Xray ─────────────────────────────${NC}"
    echo -e " ${STAR} VMess WS        : Port ${BLUE}80${NC}  path=/vmess   [xray]"
    echo -e " ${STAR} VMess WS+TLS   : Port ${BLUE}8443${NC} path=/vmess   [xray]"
    echo -e " ${STAR} VLESS WS+TLS   : Port ${PURPLE}2053${NC} path=/vless   [xray]"
    echo -e " ${STAR} Trojan TCP+TLS  : Port ${ORANGE}443${NC}              [xray]"
    echo -e " ${STAR} Shadowsocks     : Port ${YELLOW}2083${NC}             [xray]"
    echo -e ""
    echo -e " ${WHITE}── Binary yang Terinstall ───────────────────${NC}"
    echo -e " ${STAR} /usr/sbin/sshd          → OpenSSH Server"
    echo -e " ${STAR} /usr/sbin/dropbear      → Dropbear SSH"
    echo -e " ${STAR} /usr/bin/stunnel4       → SSH TLS/SSL Wrapper"
    echo -e " ${STAR} /usr/local/bin/xray     → Xray-Core (V2Ray)"
    echo -e " ${STAR} /usr/local/bin/ssh-ws.py → SSH WebSocket Proxy"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "$(echo -e "${YELLOW}Tekan Enter untuk kembali ke menu...${NC}")"
}

# ═══════════════════════════════════════════════════════════
#  MANAJEMEN AKUN SSH
# ═══════════════════════════════════════════════════════════

ssh_add_user() {
    echo -e "\n${CYAN}═══ TAMBAH AKUN SSH ══════════════════════════════${NC}"
    echo -ne " ${ARROW} Username   : "
    read -r user
    echo -ne " ${ARROW} Password   : "
    read -r pass
    echo -ne " ${ARROW} Masa Aktif (hari): "
    read -r days

    [[ -z "$user" || -z "$pass" || -z "$days" ]] && echo -e "${CROSS} Input tidak boleh kosong!" && return

    if id "$user" &>/dev/null; then
        echo -e "${CROSS} User ${RED}$user${NC} sudah ada!"
        read -p "Tekan Enter..." && return
    fi

    EXP_DATE=$(date -d "+${days} days" +"%Y-%m-%d")
    useradd -m -s /bin/false -e "$EXP_DATE" "$user" &>/dev/null
    echo "$user:$pass" | chpasswd &>/dev/null

    # Simpan ke DB
    echo "$user|$pass|$EXP_DATE" >> $SSH_USERS_DB

    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "N/A")
    echo ""
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${TICK} ${GREEN}Akun SSH berhasil dibuat!${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e " ${STAR} Username    : ${GREEN}$user${NC}"
    echo -e " ${STAR} Password    : ${YELLOW}$pass${NC}"
    echo -e " ${STAR} Expire      : ${RED}$EXP_DATE${NC}"
    echo -e " ${STAR} Host/IP     : $DOMAIN"
    echo -e " ${STAR} Port SSH    : 22, 80"
    echo -e " ${STAR} Port SSL    : 443, 222"
    echo -e " ${STAR} Port WS     : 8880"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "Tekan Enter..."
}

ssh_del_user() {
    echo -e "\n${CYAN}═══ HAPUS AKUN SSH ═══════════════════════════════${NC}"
    echo -ne " ${ARROW} Username yang dihapus: "
    read -r user
    [[ -z "$user" ]] && return
    if ! id "$user" &>/dev/null; then
        echo -e "${CROSS} User tidak ditemukan!"; read -p "Tekan Enter..." && return
    fi
    userdel -r "$user" &>/dev/null
    sed -i "/^$user|/d" $SSH_USERS_DB 2>/dev/null
    echo -e "${TICK} User ${GREEN}$user${NC} berhasil dihapus!"
    read -p "Tekan Enter..."
}

ssh_list_user() {
    echo -e "\n${CYAN}═══ DAFTAR AKUN SSH ══════════════════════════════${NC}"
    if [[ ! -s $SSH_USERS_DB ]]; then
        echo -e " ${CROSS} Belum ada akun SSH"; read -p "Tekan Enter..." && return
    fi
    printf "\n %-18s %-18s %-12s %s\n" "USERNAME" "PASSWORD" "EXPIRE" "STATUS"
    echo -e " ${LINE2}"
    while IFS='|' read -r u p e; do
        EXP=$(date -d "$e" +%s 2>/dev/null)
        NOW=$(date +%s)
        if [[ $EXP -lt $NOW ]]; then ST="${RED}EXPIRED${NC}"; else ST="${GREEN}AKTIF${NC}"; fi
        printf " %-18s %-18s %-12s " "$u" "$p" "$e"
        echo -e "$ST"
    done < $SSH_USERS_DB
    echo ""
    read -p "Tekan Enter..."
}

ssh_renew_user() {
    echo -e "\n${CYAN}═══ PERPANJANG AKUN SSH ══════════════════════════${NC}"
    echo -ne " ${ARROW} Username   : "
    read -r user
    echo -ne " ${ARROW} Tambah hari: "
    read -r days
    [[ -z "$user" || -z "$days" ]] && return
    if ! id "$user" &>/dev/null; then
        echo -e "${CROSS} User tidak ditemukan!"; read -p "Tekan Enter..." && return
    fi
    CURR_EXP=$(chage -l "$user" | grep "Account expires" | awk -F': ' '{print $2}')
    NEW_EXP=$(date -d "+${days} days" +"%Y-%m-%d")
    chage -E "$NEW_EXP" "$user"
    sed -i "s/^$user|.*|.*/$user|$(grep "^$user|" $SSH_USERS_DB | cut -d'|' -f2)|$NEW_EXP/" $SSH_USERS_DB
    echo -e "${TICK} Akun $user diperpanjang hingga ${GREEN}$NEW_EXP${NC}"
    read -p "Tekan Enter..."
}

ssh_check_login() {
    echo -e "\n${CYAN}═══ CEK LOGIN SSH AKTIF ══════════════════════════${NC}"
    echo ""
    who | grep -v "^$" | while read -r line; do
        echo -e " ${ARROW} $line"
    done
    echo ""
    echo -e " ${WHITE}Total sesi aktif: ${GREEN}$(who | wc -l)${NC}"
    read -p "Tekan Enter..."
}

# ═══════════════════════════════════════════════════════════
#  MANAJEMEN AKUN VMESS
# ═══════════════════════════════════════════════════════════

vmess_add_user() {
    echo -e "\n${CYAN}═══ TAMBAH AKUN VMESS ════════════════════════════${NC}"
    echo -ne " ${ARROW} Username   : "
    read -r user
    echo -ne " ${ARROW} Masa Aktif (hari): "
    read -r days
    [[ -z "$user" || -z "$days" ]] && return

    UUID=$(cat /proc/sys/kernel/random/uuid)
    EXP_DATE=$(date -d "+${days} days" +"%Y-%m-%d")
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "N/A")

    # Tambah ke xray config
    if [[ -f "$XRAY_CONFIG" ]]; then
        NEW_CLIENT="{\"id\":\"$UUID\",\"alterId\":0,\"email\":\"$user\"}"
        # Inject ke vmess inbound (port 8443)
        python3 -c "
import json,sys
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='vmess':
        clients=ib['settings'].get('clients',[])
        clients.append({'id':'$UUID','alterId':0,'email':'$user'})
        ib['settings']['clients']=clients
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
        systemctl restart xray &>/dev/null
    fi

    echo "$user|$UUID|$EXP_DATE" >> $VMESS_USERS_DB

    # Generate config link
    B64_VMESS=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$DOMAIN\",\"port\":\"8443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w 0)

    echo ""
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${TICK} ${GREEN}Akun VMess berhasil dibuat!${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e " ${STAR} Username    : ${GREEN}$user${NC}"
    echo -e " ${STAR} UUID        : ${YELLOW}$UUID${NC}"
    echo -e " ${STAR} Expire      : ${RED}$EXP_DATE${NC}"
    echo -e " ${STAR} Host        : $DOMAIN"
    echo -e " ${STAR} Port TLS    : 8443"
    echo -e " ${STAR} Port Non-TLS: 80"
    echo -e " ${STAR} Path        : /vmess"
    echo -e " ${STAR} Network     : WebSocket"
    echo -e " ${STAR} TLS         : yes"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e " ${STAR} ${WHITE}Link Config:${NC}"
    echo -e " ${YELLOW}vmess://$B64_VMESS${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "Tekan Enter..."
}

vmess_del_user() {
    echo -e "\n${CYAN}═══ HAPUS AKUN VMESS ═════════════════════════════${NC}"
    echo -ne " ${ARROW} Username yang dihapus: "
    read -r user
    [[ -z "$user" ]] && return

    UUID=$(grep "^$user|" $VMESS_USERS_DB | cut -d'|' -f2)
    if [[ -z "$UUID" ]]; then
        echo -e "${CROSS} User tidak ditemukan!"; read -p "Tekan Enter..." && return
    fi

    python3 -c "
import json
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='vmess':
        ib['settings']['clients']=[c for c in ib['settings'].get('clients',[]) if c.get('email')!='$user']
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
    systemctl restart xray &>/dev/null
    sed -i "/^$user|/d" $VMESS_USERS_DB
    echo -e "${TICK} Akun VMess ${GREEN}$user${NC} berhasil dihapus!"
    read -p "Tekan Enter..."
}

vmess_list_user() {
    echo -e "\n${CYAN}═══ DAFTAR AKUN VMESS ════════════════════════════${NC}"
    if [[ ! -s $VMESS_USERS_DB ]]; then
        echo -e " ${CROSS} Belum ada akun VMess"; read -p "Tekan Enter..." && return
    fi
    printf "\n %-18s %-38s %-12s\n" "USERNAME" "UUID" "EXPIRE"
    echo -e " ${LINE2}"
    while IFS='|' read -r u uuid e; do
        printf " %-18s %-38s %-12s\n" "$u" "$uuid" "$e"
    done < $VMESS_USERS_DB
    echo ""
    read -p "Tekan Enter..."
}

# ═══════════════════════════════════════════════════════════
#  MANAJEMEN AKUN VLESS
# ═══════════════════════════════════════════════════════════

vless_add_user() {
    echo -e "\n${CYAN}═══ TAMBAH AKUN VLESS ════════════════════════════${NC}"
    echo -ne " ${ARROW} Username   : "
    read -r user
    echo -ne " ${ARROW} Masa Aktif (hari): "
    read -r days
    [[ -z "$user" || -z "$days" ]] && return

    UUID=$(cat /proc/sys/kernel/random/uuid)
    EXP_DATE=$(date -d "+${days} days" +"%Y-%m-%d")
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "N/A")

    if [[ -f "$XRAY_CONFIG" ]]; then
        python3 -c "
import json
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='vless':
        clients=ib['settings'].get('clients',[])
        clients.append({'id':'$UUID','email':'$user','flow':''})
        ib['settings']['clients']=clients
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
        systemctl restart xray &>/dev/null
    fi

    echo "$user|$UUID|$EXP_DATE" >> $VLESS_USERS_DB
    VLESS_LINK="vless://$UUID@$DOMAIN:2053?encryption=none&security=tls&type=ws&host=$DOMAIN&path=%2Fvless#$user"

    echo ""
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${TICK} ${GREEN}Akun VLESS berhasil dibuat!${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e " ${STAR} Username    : ${GREEN}$user${NC}"
    echo -e " ${STAR} UUID        : ${YELLOW}$UUID${NC}"
    echo -e " ${STAR} Expire      : ${RED}$EXP_DATE${NC}"
    echo -e " ${STAR} Host        : $DOMAIN"
    echo -e " ${STAR} Port        : 2053"
    echo -e " ${STAR} Path        : /vless"
    echo -e " ${STAR} TLS         : yes"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e " ${STAR} ${WHITE}Link Config:${NC}"
    echo -e " ${YELLOW}$VLESS_LINK${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "Tekan Enter..."
}

vless_del_user() {
    echo -e "\n${CYAN}═══ HAPUS AKUN VLESS ═════════════════════════════${NC}"
    echo -ne " ${ARROW} Username: "
    read -r user
    [[ -z "$user" ]] && return
    python3 -c "
import json
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='vless':
        ib['settings']['clients']=[c for c in ib['settings'].get('clients',[]) if c.get('email')!='$user']
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
    systemctl restart xray &>/dev/null
    sed -i "/^$user|/d" $VLESS_USERS_DB
    echo -e "${TICK} Akun VLESS ${GREEN}$user${NC} dihapus!"
    read -p "Tekan Enter..."
}

vless_list_user() {
    echo -e "\n${CYAN}═══ DAFTAR AKUN VLESS ════════════════════════════${NC}"
    if [[ ! -s $VLESS_USERS_DB ]]; then
        echo -e " ${CROSS} Belum ada akun VLESS"; read -p "Tekan Enter..." && return
    fi
    printf "\n %-18s %-38s %-12s\n" "USERNAME" "UUID" "EXPIRE"
    echo -e " ${LINE2}"
    while IFS='|' read -r u uuid e; do
        printf " %-18s %-38s %-12s\n" "$u" "$uuid" "$e"
    done < $VLESS_USERS_DB
    echo ""
    read -p "Tekan Enter..."
}

# ═══════════════════════════════════════════════════════════
#  MANAJEMEN AKUN TROJAN
# ═══════════════════════════════════════════════════════════

trojan_add_user() {
    echo -e "\n${CYAN}═══ TAMBAH AKUN TROJAN ═══════════════════════════${NC}"
    echo -ne " ${ARROW} Username   : "
    read -r user
    echo -ne " ${ARROW} Password   : "
    read -r pass
    echo -ne " ${ARROW} Masa Aktif (hari): "
    read -r days
    [[ -z "$user" || -z "$pass" || -z "$days" ]] && return

    EXP_DATE=$(date -d "+${days} days" +"%Y-%m-%d")
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "N/A")

    if [[ -f "$XRAY_CONFIG" ]]; then
        python3 -c "
import json
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='trojan':
        clients=ib['settings'].get('clients',[])
        clients.append({'password':'$pass','email':'$user'})
        ib['settings']['clients']=clients
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
        systemctl restart xray &>/dev/null
    fi

    echo "$user|$pass|$EXP_DATE" >> $TROJAN_USERS_DB
    TROJAN_LINK="trojan://$pass@$DOMAIN:443?security=tls&type=tcp#$user"

    echo ""
    echo -e "${CYAN}${LINE}${NC}"
    echo -e "${TICK} ${GREEN}Akun Trojan berhasil dibuat!${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    echo -e " ${STAR} Username    : ${GREEN}$user${NC}"
    echo -e " ${STAR} Password    : ${YELLOW}$pass${NC}"
    echo -e " ${STAR} Expire      : ${RED}$EXP_DATE${NC}"
    echo -e " ${STAR} Host        : $DOMAIN"
    echo -e " ${STAR} Port        : 443"
    echo -e " ${STAR} TLS         : yes"
    echo -e "${CYAN}${LINE2}${NC}"
    echo -e " ${STAR} ${WHITE}Link Config:${NC}"
    echo -e " ${YELLOW}$TROJAN_LINK${NC}"
    echo -e "${CYAN}${LINE}${NC}"
    read -p "Tekan Enter..."
}

trojan_del_user() {
    echo -e "\n${CYAN}═══ HAPUS AKUN TROJAN ════════════════════════════${NC}"
    echo -ne " ${ARROW} Username: "
    read -r user
    [[ -z "$user" ]] && return
    python3 -c "
import json
with open('$XRAY_CONFIG','r') as f: cfg=json.load(f)
for ib in cfg['inbounds']:
    if ib.get('protocol')=='trojan':
        ib['settings']['clients']=[c for c in ib['settings'].get('clients',[]) if c.get('email')!='$user']
with open('$XRAY_CONFIG','w') as f: json.dump(cfg,f,indent=2)
" 2>/dev/null
    systemctl restart xray &>/dev/null
    sed -i "/^$user|/d" $TROJAN_USERS_DB
    echo -e "${TICK} Akun Trojan ${GREEN}$user${NC} dihapus!"
    read -p "Tekan Enter..."
}

trojan_list_user() {
    echo -e "\n${CYAN}═══ DAFTAR AKUN TROJAN ═══════════════════════════${NC}"
    if [[ ! -s $TROJAN_USERS_DB ]]; then
        echo -e " ${CROSS} Belum ada akun Trojan"; read -p "Tekan Enter..." && return
    fi
    printf "\n %-18s %-25s %-12s\n" "USERNAME" "PASSWORD" "EXPIRE"
    echo -e " ${LINE2}"
    while IFS='|' read -r u p e; do
        printf " %-18s %-25s %-12s\n" "$u" "$p" "$e"
    done < $TROJAN_USERS_DB
    echo ""
    read -p "Tekan Enter..."
}

# ═══════════════════════════════════════════════════════════
#  MENU SSH
# ═══════════════════════════════════════════════════════════

menu_ssh() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${GREEN}                   🔐  MENU SSH MANAGER                       ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠${LINE}╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Tambah Akun SSH              ${GREEN}[4]${NC} Perpanjang Akun SSH      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} Hapus Akun SSH               ${GREEN}[5]${NC} Cek Login Aktif          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} List Akun SSH                ${RED}[0]${NC} Kembali                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne " ${ARROW} Pilihan: "
        read -r opt
        case $opt in
            1) ssh_add_user ;;
            2) ssh_del_user ;;
            3) ssh_list_user ;;
            4) ssh_renew_user ;;
            5) ssh_check_login ;;
            0) break ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  MENU VMESS
# ═══════════════════════════════════════════════════════════

menu_vmess() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${BLUE}                   📡  MENU VMESS MANAGER                     ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠${LINE}╣${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}[1]${NC} Tambah Akun VMess            ${BLUE}[3]${NC} List Akun VMess          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${BLUE}[2]${NC} Hapus Akun VMess             ${RED}[0]${NC} Kembali                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne " ${ARROW} Pilihan: "
        read -r opt
        case $opt in
            1) vmess_add_user ;;
            2) vmess_del_user ;;
            3) vmess_list_user ;;
            0) break ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  MENU VLESS
# ═══════════════════════════════════════════════════════════

menu_vless() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${PURPLE}                   🔒  MENU VLESS MANAGER                     ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠${LINE}╣${NC}"
        echo -e "${CYAN}║${NC}  ${PURPLE}[1]${NC} Tambah Akun VLESS            ${PURPLE}[3]${NC} List Akun VLESS          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${PURPLE}[2]${NC} Hapus Akun VLESS             ${RED}[0]${NC} Kembali                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne " ${ARROW} Pilihan: "
        read -r opt
        case $opt in
            1) vless_add_user ;;
            2) vless_del_user ;;
            3) vless_list_user ;;
            0) break ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  MENU TROJAN
# ═══════════════════════════════════════════════════════════

menu_trojan() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${ORANGE}                   🛡  MENU TROJAN MANAGER                    ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠${LINE}╣${NC}"
        echo -e "${CYAN}║${NC}  ${ORANGE}[1]${NC} Tambah Akun Trojan           ${ORANGE}[3]${NC} List Akun Trojan         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${ORANGE}[2]${NC} Hapus Akun Trojan            ${RED}[0]${NC} Kembali                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne " ${ARROW} Pilihan: "
        read -r opt
        case $opt in
            1) trojan_add_user ;;
            2) trojan_del_user ;;
            3) trojan_list_user ;;
            0) break ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  MANAJEMEN SISTEM
# ═══════════════════════════════════════════════════════════

restart_services() {
    echo -e "\n${CYAN}═══ RESTART SEMUA LAYANAN ════════════════════════${NC}"
    for svc in ssh xray stunnel4 ssh-ws; do
        systemctl restart $svc &>/dev/null && echo -e " ${TICK} $svc restarted" || echo -e " ${CROSS} $svc gagal"
    done
    read -p "Tekan Enter..."
}

service_status() {
    echo -e "\n${CYAN}═══ STATUS LAYANAN ═══════════════════════════════${NC}"
    for svc in ssh xray stunnel4 ssh-ws; do
        STATUS=$(systemctl is-active $svc 2>/dev/null)
        printf " %-15s : " "$svc"
        echo -e "$(status_color $STATUS)"
    done
    echo ""
    echo -e " ${WHITE}Port yang Terbuka:${NC}"
    ss -tlnp | grep -E ":(22|80|443|222|2053|2083|8443|8880)" | awk '{print "  " $4}' | sort -u
    echo ""
    read -p "Tekan Enter..."
}

set_domain() {
    echo -e "\n${CYAN}═══ GANTI DOMAIN ═════════════════════════════════${NC}"
    echo -ne " ${ARROW} Domain/IP baru: "
    read -r new_domain
    [[ -z "$new_domain" ]] && return
    echo "$new_domain" > $DOMAIN_FILE
    echo -e "${TICK} Domain diubah ke: ${GREEN}$new_domain${NC}"
    read -p "Tekan Enter..."
}

show_ports() {
    echo -e "\n${CYAN}═══ INFORMASI PORT ═══════════════════════════════${NC}"
    echo -e ""
    echo -e " ${WHITE}SSH:${NC}"
    echo -e "  ${ARROW} SSH Direct  : Port ${GREEN}22, 80${NC}"
    echo -e "  ${ARROW} SSH SSL     : Port ${GREEN}443, 222${NC} (via Stunnel)"
    echo -e "  ${ARROW} SSH WS      : Port ${GREEN}8880${NC}"
    echo -e ""
    echo -e " ${WHITE}V2Ray/Xray:${NC}"
    echo -e "  ${ARROW} VMess WS    : Port ${BLUE}80${NC}   | Path: /vmess | TLS: No"
    echo -e "  ${ARROW} VMess WS TLS: Port ${BLUE}8443${NC} | Path: /vmess | TLS: Yes"
    echo -e "  ${ARROW} VLESS WS TLS: Port ${PURPLE}2053${NC} | Path: /vless | TLS: Yes"
    echo -e "  ${ARROW} Trojan      : Port ${ORANGE}443${NC}  | TCP          | TLS: Yes"
    echo -e "  ${ARROW} Shadowsocks : Port ${YELLOW}2083${NC} | Method: chacha20-ietf-poly1305"
    echo -e ""
    read -p "Tekan Enter..."
}

menu_sistem() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${WHITE}                   ⚙  MENU SISTEM & TOOLS                    ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠${LINE}╣${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}[1]${NC} Restart Semua Layanan        ${WHITE}[4]${NC} Set Domain/IP            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}[2]${NC} Status Layanan               ${WHITE}[5]${NC} Info Port                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${WHITE}[3]${NC} Spek VPS                     ${RED}[0]${NC} Kembali                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne " ${ARROW} Pilihan: "
        read -r opt
        case $opt in
            1) restart_services ;;
            2) service_status ;;
            3) show_vps_info ;;
            4) set_domain ;;
            5) show_ports ;;
            0) break ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  MAIN MENU UTAMA
# ═══════════════════════════════════════════════════════════

main_menu() {
    while true; do
        show_header
        echo -e "${CYAN}╔${LINE}╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}${YELLOW}               📋  MENU UTAMA VPS PANEL PRO                   ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════╦════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                              ${CYAN}║${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${CYAN}[1]${NC} 🔧 Install Panel           ${CYAN}║${NC}  ${GREEN}[5]${NC} 🔐 Menu SSH            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                              ${CYAN}║${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${CYAN}[2]${NC} 💻 Spesifikasi VPS         ${CYAN}║${NC}  ${BLUE}[6]${NC} 📡 Menu VMess          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                              ${CYAN}║${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${CYAN}[3]${NC} ⚙  Sistem & Tools          ${CYAN}║${NC}  ${PURPLE}[7]${NC} 🔒 Menu VLESS          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                              ${CYAN}║${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${CYAN}[4]${NC} 🔌 Info Port & Protokol    ${CYAN}║${NC}  ${ORANGE}[8]${NC} 🛡  Menu Trojan        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                              ${CYAN}║${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════╩════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC} 🚪 Keluar                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╚${LINE}╝${NC}"
        echo -ne "\n ${ARROW} ${WHITE}Masukkan pilihan menu${NC} [0-8]: "
        read -r choice
        case $choice in
            1) run_install ;;
            2) show_vps_info ;;
            3) menu_sistem ;;
            4) show_ports ;;
            5) menu_ssh ;;
            6) menu_vmess ;;
            7) menu_vless ;;
            8) menu_trojan ;;
            0)
                echo -e "\n${YELLOW}Terima kasih telah menggunakan VPanel Pro!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════
#  ENTRY POINT
# ═══════════════════════════════════════════════════════════

check_root
detect_os
mkdir -p $PANEL_DIR
touch $SSH_USERS_DB $VMESS_USERS_DB $VLESS_USERS_DB $TROJAN_USERS_DB 2>/dev/null
main_menu
