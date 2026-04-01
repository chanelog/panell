#!/bin/bash
# ============================================================
#   SSH ALL PROTOCOL PANEL PRO - Enhanced Edition
#   Author  : Your Custom Panel
#   Version : 2.0 PRO
#   Base    : Enhanced from dotywrt concept
# ============================================================

# ─── COLORS ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
ORANGE='\033[38;5;214m'
LGRAY='\033[0;37m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ─── PATHS & CONFIG ──────────────────────────────────────────
PANEL_DIR="/etc/ssh-panel"
LOG_DIR="/var/log/ssh-panel"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/ssh-panel/config"
DB_FILE="$PANEL_DIR/users.db"
BACKUP_DIR="/etc/ssh-panel/backup"
LOCK_FILE="/tmp/ssh-panel.lock"
VERSION="3.0 PRO"
PANEL_PORT_WS=80
PANEL_PORT_WSS=443
PANEL_PORT_OVPN_TCP=1194
PANEL_PORT_OVPN_UDP=1194
PANEL_PORT_V2RAY=8080
PANEL_PORT_BADVPN=7300
PANEL_PORT_ZIVPN=5300
PANEL_PORT_UDPCUSTOM=1-65535
UDPCUSTOM_BIN="/usr/local/bin/udp-custom"
ZIVPN_BIN="/usr/local/bin/zivpn"
UDPCUSTOM_CFG="/etc/ssh-panel/config/udp-custom.json"
ZIVPN_CFG="/etc/ssh-panel/config/zivpn.conf"

# ─── CHECK ROOT ──────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Script harus dijalankan sebagai root!"
        exit 1
    fi
}

# ─── SPINNER ─────────────────────────────────────────────────
spinner() {
    local pid=$1
    local msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r${CYAN}[${spin:i++%${#spin}:1}]${NC} $msg"
        sleep 0.1
    done
    printf "\r${GREEN}[✔]${NC} $msg\n"
}

# ─── DETECT OS ───────────────────────────────────────────────
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    elif [ -f /etc/centos-release ]; then
        OS="centos"
    else
        OS="unknown"
    fi
}

# ─── GET SERVER INFO ─────────────────────────────────────────
get_server_info() {
    MYIP=$(curl -s ifconfig.me 2>/dev/null || curl -s api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
    ISP=$(curl -s "http://ip-api.com/line/$MYIP?fields=isp" 2>/dev/null || echo "Unknown")
    CITY=$(curl -s "http://ip-api.com/line/$MYIP?fields=city" 2>/dev/null || echo "Unknown")
    COUNTRY=$(curl -s "http://ip-api.com/line/$MYIP?fields=country" 2>/dev/null || echo "Unknown")
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')
    CPU_CORES=$(nproc)
    RAM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
    RAM_USED=$(free -m | awk '/Mem:/{print $3}')
    DISK_USED=$(df -h / | awk 'NR==2{print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
    KERNEL=$(uname -r)
}

# ─── AUTO INSTALL BINARIES ───────────────────────────────────
auto_install_binaries() {
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║      AUTO INSTALL BINARIES & DEPENDENCIES    ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}\n"

    detect_os

    # Update package list
    echo -e "${YELLOW}[*]${NC} Updating package list..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get update -qq &>/dev/null &
        spinner $! "Updating APT packages"
    elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
        yum update -y -q &>/dev/null &
        spinner $! "Updating YUM packages"
    fi

    # ── Core packages ──
    CORE_PKGS="wget curl net-tools iptables openssl ca-certificates gnupg lsb-release unzip tar gzip bc jq htop vnstat fail2ban uuid-runtime"
    echo -e "${YELLOW}[*]${NC} Installing core packages..."
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt-get install -y -qq $CORE_PKGS &>/dev/null &
        spinner $! "Installing core packages"
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        yum install -y -q epel-release &>/dev/null
        yum install -y -q $CORE_PKGS &>/dev/null &
        spinner $! "Installing core packages (CentOS)"
    fi

    # ── OpenSSH ──
    install_openssh
    # ── Dropbear ──
    install_dropbear
    # ── Stunnel4 ──
    install_stunnel
    # ── Websocket (ws-epro) ──
    install_websocket
    # ── BadVPN UDP ──
    install_badvpn
    # ── OpenVPN ──
    install_openvpn
    # ── V2Ray / Xray ──
    install_v2ray
    # ── Nginx ──
    install_nginx
    # ── Python3 / pip (for ws) ──
    install_python
    # ── Squid Proxy ──
    install_squid
    # ── SlowDNS ──
    install_slowdns
    # ── UDP ZiVPN ──
    install_zivpn
    # ── UDP Custom ──
    install_udp_custom
    # ── Badvpn-udpgw ──
    install_udpgw
    # ── Create dirs ──
    mkdir -p "$PANEL_DIR" "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR"
    touch "$DB_FILE"

    echo -e "\n${GREEN}[✔]${NC} ${BOLD}Semua binary berhasil diinstall!${NC}\n"
}

install_openssh() {
    echo -e "${YELLOW}[*]${NC} Checking OpenSSH..."
    if ! command -v sshd &>/dev/null; then
        apt-get install -y -qq openssh-server &>/dev/null &
        spinner $! "Installing OpenSSH Server"
    else
        echo -e "${GREEN}[✔]${NC} OpenSSH already installed"
    fi
    # Configure SSH
    sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
    grep -q "^Port 2222" /etc/ssh/sshd_config || echo "Port 2222" >> /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart ssh &>/dev/null || service ssh restart &>/dev/null
}

install_dropbear() {
    echo -e "${YELLOW}[*]${NC} Checking Dropbear..."
    if ! command -v dropbear &>/dev/null; then
        apt-get install -y -qq dropbear &>/dev/null &
        spinner $! "Installing Dropbear"
    else
        echo -e "${GREEN}[✔]${NC} Dropbear already installed"
    fi
    # Configure Dropbear
    cat > /etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
    systemctl restart dropbear &>/dev/null || service dropbear restart &>/dev/null
}

install_stunnel() {
    echo -e "${YELLOW}[*]${NC} Checking Stunnel4..."
    if ! command -v stunnel4 &>/dev/null; then
        apt-get install -y -qq stunnel4 &>/dev/null &
        spinner $! "Installing Stunnel4"
    else
        echo -e "${GREEN}[✔]${NC} Stunnel4 already installed"
    fi
    # Generate SSL cert
    if [ ! -f /etc/stunnel/stunnel.pem ]; then
        openssl req -new -x509 -days 3650 -nodes \
            -subj "/C=US/ST=State/L=City/O=Org/CN=panel" \
            -out /etc/stunnel/stunnel.pem \
            -keyout /etc/stunnel/stunnel.pem &>/dev/null
    fi
    cat > /etc/stunnel/stunnel.conf <<EOF
cert = /etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
[dropbear]
accept = 442
connect = 127.0.0.1:143
[openssh]
accept = 443
connect = 127.0.0.1:22
EOF
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
    systemctl restart stunnel4 &>/dev/null || service stunnel4 restart &>/dev/null
}

install_websocket() {
    echo -e "${YELLOW}[*]${NC} Checking WebSocket Proxy..."
    WS_BIN="/usr/local/bin/ws-pro"
    if [ ! -f "$WS_BIN" ]; then
        # Try download prebuilt ws binary
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            WS_URL="https://raw.githubusercontent.com/azizan060/ws-pro/main/ws-pro-amd64"
        else
            WS_URL="https://raw.githubusercontent.com/azizan060/ws-pro/main/ws-pro-arm"
        fi
        wget -q -O "$WS_BIN" "$WS_URL" &>/dev/null || true
        # Fallback: build python ws proxy
        if [ ! -s "$WS_BIN" ] || ! file "$WS_BIN" | grep -q ELF; then
            install_python_ws
        else
            chmod +x "$WS_BIN"
        fi
        echo -e "${GREEN}[✔]${NC} WebSocket proxy installed"
    else
        echo -e "${GREEN}[✔]${NC} WebSocket already installed"
    fi
    setup_ws_service
}

install_python_ws() {
    python3 -m pip install websockets &>/dev/null 2>&1 || true
    cat > /usr/local/bin/ws-python.py <<'PYEOF'
#!/usr/bin/env python3
import asyncio, websockets, socket, sys, logging

logging.basicConfig(level=logging.WARNING)

REMOTE_HOST = "127.0.0.1"
REMOTE_PORT = 22
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80

async def handle(websocket, path):
    try:
        remote = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        remote.connect((REMOTE_HOST, REMOTE_PORT))
        remote.setblocking(False)
        loop = asyncio.get_event_loop()
        async def ws_to_remote():
            async for msg in websocket:
                await loop.sock_sendall(remote, msg if isinstance(msg, bytes) else msg.encode())
        async def remote_to_ws():
            while True:
                data = await loop.sock_recv(remote, 4096)
                if not data: break
                await websocket.send(data)
        done, pending = await asyncio.wait(
            [asyncio.ensure_future(ws_to_remote()), asyncio.ensure_future(remote_to_ws())],
            return_when=asyncio.FIRST_COMPLETED)
        for t in pending: t.cancel()
    except Exception: pass
    finally:
        try: remote.close()
        except: pass

start_server = websockets.serve(handle, "0.0.0.0", LISTEN_PORT)
asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
PYEOF
    chmod +x /usr/local/bin/ws-python.py
    ln -sf /usr/local/bin/ws-python.py /usr/local/bin/ws-pro
}

setup_ws_service() {
    cat > /etc/systemd/system/ws-pro.service <<EOF
[Unit]
Description=WebSocket SSH Proxy PRO
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ws-pro 80
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    cat > /etc/systemd/system/ws-pro-ssl.service <<EOF
[Unit]
Description=WebSocket SSH Proxy SSL PRO
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ws-pro 8080
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload &>/dev/null
    systemctl enable ws-pro ws-pro-ssl &>/dev/null
    systemctl restart ws-pro ws-pro-ssl &>/dev/null
}

install_badvpn() {
    echo -e "${YELLOW}[*]${NC} Checking BadVPN..."
    if ! command -v badvpn-udpgw &>/dev/null; then
        apt-get install -y -qq cmake make gcc g++ &>/dev/null
        cd /tmp
        wget -q "https://github.com/ambrop72/badvpn/archive/refs/heads/master.zip" -O badvpn.zip &>/dev/null
        if [ -f badvpn.zip ]; then
            unzip -q badvpn.zip &>/dev/null
            cd badvpn-master
            mkdir build && cd build
            cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 &>/dev/null
            make -j$(nproc) &>/dev/null
            cp udpgw/badvpn-udpgw /usr/local/bin/
            chmod +x /usr/local/bin/badvpn-udpgw
        fi
        cd /tmp && rm -rf badvpn* &>/dev/null
        echo -e "${GREEN}[✔]${NC} BadVPN installed"
    else
        echo -e "${GREEN}[✔]${NC} BadVPN already installed"
    fi
    install_udpgw
}

install_udpgw() {
    cat > /etc/systemd/system/badvpn-udpgw.service <<EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload &>/dev/null
    systemctl enable badvpn-udpgw &>/dev/null
    systemctl restart badvpn-udpgw &>/dev/null
}

install_openvpn() {
    echo -e "${YELLOW}[*]${NC} Checking OpenVPN..."
    if ! command -v openvpn &>/dev/null; then
        apt-get install -y -qq openvpn easy-rsa &>/dev/null &
        spinner $! "Installing OpenVPN"
    else
        echo -e "${GREEN}[✔]${NC} OpenVPN already installed"
    fi
    [ ! -d /etc/openvpn/easy-rsa ] && setup_openvpn_pki
}

setup_openvpn_pki() {
    mkdir -p /etc/openvpn/easy-rsa
    cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/ &>/dev/null || true
    cd /etc/openvpn/easy-rsa
    if [ -f ./easyrsa ]; then
        ./easyrsa init-pki &>/dev/null
        echo "panel" | ./easyrsa build-ca nopass &>/dev/null
        ./easyrsa gen-dh &>/dev/null
        ./easyrsa build-server-full server nopass &>/dev/null
        cp pki/ca.crt pki/issued/server.crt pki/private/server.key pki/dh.pem /etc/openvpn/ &>/dev/null
    fi
    setup_openvpn_config
}

setup_openvpn_config() {
    cat > /etc/openvpn/server.conf <<EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
cipher AES-256-CBC
EOF
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p &>/dev/null
    systemctl enable openvpn@server &>/dev/null
    systemctl restart openvpn@server &>/dev/null
}

install_v2ray() {
    echo -e "${YELLOW}[*]${NC} Checking V2Ray/Xray..."
    if ! command -v xray &>/dev/null && ! command -v v2ray &>/dev/null; then
        # Install Xray
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>/dev/null &
        spinner $! "Installing Xray"
        setup_v2ray_config
    else
        echo -e "${GREEN}[✔]${NC} V2Ray/Xray already installed"
    fi
}

setup_v2ray_config() {
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    mkdir -p /usr/local/etc/xray
    cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "$UUID","alterId": 0}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vmess"}
      }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID","flow": ""}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/vless"}
      }
    },
    {
      "port": 3478,
      "protocol": "trojan",
      "settings": {
        "clients": [{"password": "panel-trojan"}]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {"path": "/trojan"}
      }
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    echo "$UUID" > "$CONFIG_DIR/v2ray_uuid"
    systemctl enable xray &>/dev/null
    systemctl restart xray &>/dev/null
}

install_nginx() {
    echo -e "${YELLOW}[*]${NC} Checking Nginx..."
    if ! command -v nginx &>/dev/null; then
        apt-get install -y -qq nginx &>/dev/null &
        spinner $! "Installing Nginx"
    else
        echo -e "${GREEN}[✔]${NC} Nginx already installed"
    fi
    setup_nginx_proxy
}

setup_nginx_proxy() {
    cat > /etc/nginx/conf.d/panel.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    location /vmess { proxy_pass http://127.0.0.1:8080; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "Upgrade"; }
    location /vless { proxy_pass http://127.0.0.1:8443; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "Upgrade"; }
    location /trojan { proxy_pass http://127.0.0.1:3478; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "Upgrade"; }
    location /ssh-ws { proxy_pass http://127.0.0.1:2082; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "Upgrade"; }
    location / { return 200 'SSH Panel PRO'; add_header Content-Type text/plain; }
}
EOF
    nginx -t &>/dev/null && systemctl reload nginx &>/dev/null
}

install_python() {
    echo -e "${YELLOW}[*]${NC} Checking Python3..."
    if ! command -v python3 &>/dev/null; then
        apt-get install -y -qq python3 python3-pip &>/dev/null &
        spinner $! "Installing Python3"
    else
        echo -e "${GREEN}[✔]${NC} Python3 already installed"
    fi
    python3 -m pip install websockets requests &>/dev/null &>/dev/null
}

install_squid() {
    echo -e "${YELLOW}[*]${NC} Checking Squid Proxy..."
    if ! command -v squid &>/dev/null; then
        apt-get install -y -qq squid &>/dev/null &
        spinner $! "Installing Squid Proxy"
    else
        echo -e "${GREEN}[✔]${NC} Squid already installed"
    fi
    setup_squid_config
}

setup_squid_config() {
    cat > /etc/squid/squid.conf <<EOF
http_port 3128
http_port 8888 intercept
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl Safe_ports port 22
acl Safe_ports port 1-65535
acl CONNECT method CONNECT
http_access allow all
http_access allow CONNECT
cache_mem 8 MB
cache_dir ufs /var/spool/squid 100 16 256
access_log /var/log/squid/access.log
coredump_dir /var/spool/squid
refresh_pattern . 0 20% 4320
EOF
    systemctl enable squid &>/dev/null
    systemctl restart squid &>/dev/null
}

install_slowdns() {
    echo -e "${YELLOW}[*]${NC} Checking SlowDNS..."
    SDNS_BIN="/usr/local/bin/slowdns"
    if [ ! -f "$SDNS_BIN" ]; then
        ARCH=$(uname -m)
        if [[ "$ARCH" == "x86_64" ]]; then
            wget -q "https://raw.githubusercontent.com/snake-4/Socks5-Over-SlowDNS/main/bin/slowdns-linux-amd64" -O "$SDNS_BIN" &>/dev/null || true
        else
            wget -q "https://raw.githubusercontent.com/snake-4/Socks5-Over-SlowDNS/main/bin/slowdns-linux-arm" -O "$SDNS_BIN" &>/dev/null || true
        fi
        [ -f "$SDNS_BIN" ] && chmod +x "$SDNS_BIN" && echo -e "${GREEN}[✔]${NC} SlowDNS installed" || echo -e "${YELLOW}[!]${NC} SlowDNS not available (optional)"
    else
        echo -e "${GREEN}[✔]${NC} SlowDNS already installed"
    fi
}

# ═══════════════════════════════════════════════════════════════
# ─── INSTALL UDP ZIVPN ───────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
install_zivpn() {
    echo -e "${YELLOW}[*]${NC} Checking UDP ZiVPN..."
    if [ -f "$ZIVPN_BIN" ] && [ -x "$ZIVPN_BIN" ]; then
        echo -e "${GREEN}[✔]${NC} ZiVPN already installed"
        setup_zivpn_service
        return
    fi
    ARCH=$(uname -m)
    echo -e "${YELLOW}[*]${NC} Downloading ZiVPN binary..."
    # ZiVPN adalah UDP proxy/tunnel berbasis UDP yang populer di panel VPN
    # Coba berbagai sumber download
    ZIVPN_URLS=()
    if [[ "$ARCH" == "x86_64" ]]; then
        ZIVPN_URLS=(
            "https://github.com/radityaapratamaa/rsl/raw/master/udp/zivpn-amd64"
            "https://raw.githubusercontent.com/XTLS/Xray-core/main/release/amd64/xray"
        )
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        ZIVPN_URLS=(
            "https://github.com/radityaapratamaa/rsl/raw/master/udp/zivpn-arm64"
        )
    else
        ZIVPN_URLS=(
            "https://github.com/radityaapratamaa/rsl/raw/master/udp/zivpn-arm"
        )
    fi

    INSTALLED=0
    for URL in "${ZIVPN_URLS[@]}"; do
        wget -q --timeout=15 -O "$ZIVPN_BIN" "$URL" &>/dev/null
        if [ -s "$ZIVPN_BIN" ] && file "$ZIVPN_BIN" 2>/dev/null | grep -q ELF; then
            chmod +x "$ZIVPN_BIN"
            INSTALLED=1
            echo -e "${GREEN}[✔]${NC} ZiVPN binary downloaded"
            break
        fi
        rm -f "$ZIVPN_BIN"
    done

    # Fallback: build dari source UDP Tunnel (pengganti zivpn)
    if [ "$INSTALLED" -eq 0 ]; then
        echo -e "${YELLOW}[!]${NC} Binary tidak tersedia, membangun UDP ZiVPN dari source..."
        build_zivpn_from_source
        INSTALLED=$?
    fi

    if [ "$INSTALLED" -ne 0 ] || [ ! -x "$ZIVPN_BIN" ]; then
        echo -e "${YELLOW}[!]${NC} ZiVPN: menggunakan implementasi Python fallback..."
        install_zivpn_python_fallback
    fi

    setup_zivpn_config
    setup_zivpn_service
}

build_zivpn_from_source() {
    # Build udp-tunnel / zivpn dari Go source (lightweight)
    if ! command -v go &>/dev/null; then
        apt-get install -y -qq golang &>/dev/null 2>&1 || {
            echo -e "${YELLOW}[!]${NC} Go tidak tersedia, skip build"
            return 1
        }
    fi
    mkdir -p /tmp/zivpn-src
    cat > /tmp/zivpn-src/main.go <<'GOEOF'
package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "log"
    "net"
    "os"
    "sync"
    "time"
)

type Config struct {
    ListenPort int    `json:"listen_port"`
    RemoteHost string `json:"remote_host"`
    RemotePort int    `json:"remote_port"`
    MaxClients int    `json:"max_clients"`
    LogFile    string `json:"log_file"`
}

var (
    configFile = flag.String("c", "/etc/ssh-panel/config/zivpn.conf", "config file")
    clients    = make(map[string]*net.UDPAddr)
    mu         sync.RWMutex
)

func loadConfig() Config {
    cfg := Config{ListenPort: 5300, RemoteHost: "127.0.0.1", RemotePort: 22, MaxClients: 500, LogFile: "/var/log/ssh-panel/zivpn.log"}
    data, err := os.ReadFile(*configFile)
    if err == nil {
        json.Unmarshal(data, &cfg)
    }
    return cfg
}

func main() {
    flag.Parse()
    cfg := loadConfig()
    addr, err := net.ResolveUDPAddr("udp", fmt.Sprintf("0.0.0.0:%d", cfg.ListenPort))
    if err != nil { log.Fatal(err) }
    conn, err := net.ListenUDP("udp", addr)
    if err != nil { log.Fatal(err) }
    defer conn.Close()
    log.Printf("[ZiVPN] Listening on UDP :%d → %s:%d", cfg.ListenPort, cfg.RemoteHost, cfg.RemotePort)
    buf := make([]byte, 65535)
    for {
        conn.SetReadDeadline(time.Now().Add(30 * time.Second))
        n, remoteAddr, err := conn.ReadFromUDP(buf)
        if err != nil { continue }
        go handleUDP(conn, remoteAddr, buf[:n], cfg)
    }
}

func handleUDP(conn *net.UDPConn, client *net.UDPAddr, data []byte, cfg Config) {
    mu.Lock()
    clients[client.String()] = client
    mu.Unlock()
    remote, err := net.DialUDP("udp", nil, &net.UDPAddr{IP: net.ParseIP(cfg.RemoteHost), Port: cfg.RemotePort})
    if err != nil { return }
    defer remote.Close()
    remote.Write(data)
    resp := make([]byte, 65535)
    remote.SetReadDeadline(time.Now().Add(5 * time.Second))
    n, err := remote.Read(resp)
    if err == nil {
        conn.WriteToUDP(resp[:n], client)
    }
}
GOEOF
    cd /tmp/zivpn-src
    go build -o "$ZIVPN_BIN" main.go &>/dev/null
    cd /tmp && rm -rf zivpn-src
    if [ -x "$ZIVPN_BIN" ]; then
        echo -e "${GREEN}[✔]${NC} ZiVPN berhasil di-build dari source"
        return 0
    fi
    return 1
}

install_zivpn_python_fallback() {
    python3 -m pip install -q twisted &>/dev/null || true
    cat > /usr/local/bin/zivpn-py.py <<'PYEOF'
#!/usr/bin/env python3
"""ZiVPN UDP Tunnel - Python Fallback Implementation"""
import socket, threading, json, os, sys, logging, time

logging.basicConfig(
    filename='/var/log/ssh-panel/zivpn.log',
    level=logging.INFO,
    format='%(asctime)s [ZiVPN] %(message)s'
)

CFG_FILE = "/etc/ssh-panel/config/zivpn.conf"

def load_config():
    defaults = {"listen_port":5300,"remote_host":"127.0.0.1","remote_port":22,"max_clients":500}
    try:
        with open(CFG_FILE) as f:
            defaults.update(json.load(f))
    except:
        pass
    return defaults

clients = {}
lock = threading.Lock()

def relay_udp(server_sock, client_addr, data, cfg):
    try:
        remote = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        remote.settimeout(5)
        remote.sendto(data, (cfg["remote_host"], cfg["remote_port"]))
        with lock:
            clients[client_addr] = time.time()
        try:
            resp, _ = remote.recvfrom(65535)
            server_sock.sendto(resp, client_addr)
        except socket.timeout:
            pass
        finally:
            remote.close()
    except Exception as e:
        logging.error(f"Relay error: {e}")

def main():
    cfg = load_config()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", cfg["listen_port"]))
    logging.info(f"Listening on UDP :{cfg['listen_port']} -> {cfg['remote_host']}:{cfg['remote_port']}")
    print(f"[ZiVPN] UDP :{cfg['listen_port']} -> {cfg['remote_host']}:{cfg['remote_port']}")
    buf = bytearray(65535)
    while True:
        try:
            n, addr = sock.recvfrom_into(buf)
            t = threading.Thread(target=relay_udp, args=(sock, addr, bytes(buf[:n]), cfg), daemon=True)
            t.start()
            # Cleanup stale clients
            now = time.time()
            with lock:
                stale = [k for k,v in clients.items() if now-v > 300]
                for k in stale: del clients[k]
        except Exception as e:
            logging.error(f"Main loop error: {e}")

if __name__ == "__main__":
    main()
PYEOF
    chmod +x /usr/local/bin/zivpn-py.py
    ln -sf /usr/local/bin/zivpn-py.py "$ZIVPN_BIN"
    echo -e "${GREEN}[✔]${NC} ZiVPN Python fallback installed"
}

setup_zivpn_config() {
    mkdir -p "$(dirname "$ZIVPN_CFG")"
    if [ ! -f "$ZIVPN_CFG" ]; then
        cat > "$ZIVPN_CFG" <<EOF
{
  "listen_port": 5300,
  "remote_host": "127.0.0.1",
  "remote_port": 22,
  "max_clients": 500,
  "log_file": "/var/log/ssh-panel/zivpn.log",
  "timeout": 60,
  "buffer_size": 65535
}
EOF
    fi
}

setup_zivpn_service() {
    cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=UDP ZiVPN Tunnel PRO
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$ZIVPN_BIN -c $ZIVPN_CFG
Restart=always
RestartSec=5
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload &>/dev/null
    systemctl enable zivpn &>/dev/null
    systemctl restart zivpn &>/dev/null
    echo -e "${GREEN}[✔]${NC} ZiVPN service aktif di UDP port 5300"
}

# ═══════════════════════════════════════════════════════════════
# ─── INSTALL UDP CUSTOM ──────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
install_udp_custom() {
    echo -e "${YELLOW}[*]${NC} Checking UDP Custom..."
    if [ -f "$UDPCUSTOM_BIN" ] && [ -x "$UDPCUSTOM_BIN" ]; then
        echo -e "${GREEN}[✔]${NC} UDP Custom already installed"
        setup_udpcustom_service
        return
    fi

    ARCH=$(uname -m)
    echo -e "${YELLOW}[*]${NC} Downloading UDP Custom binary..."

    # UDP Custom - UDP request/response proxy dengan header injeksi
    UDPC_URLS=()
    if [[ "$ARCH" == "x86_64" ]]; then
        UDPC_URLS=(
            "https://github.com/Hy-Fight/UDP-Custom/releases/latest/download/udp-custom-linux-amd64"
            "https://github.com/Hy-Fight/udp-custom/releases/download/v1.0/udp-custom-linux-amd64"
            "https://raw.githubusercontent.com/ilyasfit/udp-vpn/master/bin/udp-custom-amd64"
        )
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        UDPC_URLS=(
            "https://github.com/Hy-Fight/UDP-Custom/releases/latest/download/udp-custom-linux-arm64"
            "https://raw.githubusercontent.com/ilyasfit/udp-vpn/master/bin/udp-custom-arm64"
        )
    else
        UDPC_URLS=(
            "https://github.com/Hy-Fight/UDP-Custom/releases/latest/download/udp-custom-linux-arm"
            "https://raw.githubusercontent.com/ilyasfit/udp-vpn/master/bin/udp-custom-arm"
        )
    fi

    INSTALLED=0
    for URL in "${UDPC_URLS[@]}"; do
        wget -q --timeout=15 -O "$UDPCUSTOM_BIN" "$URL" &>/dev/null
        if [ -s "$UDPCUSTOM_BIN" ] && file "$UDPCUSTOM_BIN" 2>/dev/null | grep -q ELF; then
            chmod +x "$UDPCUSTOM_BIN"
            INSTALLED=1
            echo -e "${GREEN}[✔]${NC} UDP Custom binary downloaded"
            break
        fi
        rm -f "$UDPCUSTOM_BIN"
    done

    # Fallback: build dari source
    if [ "$INSTALLED" -eq 0 ]; then
        echo -e "${YELLOW}[!]${NC} Binary tidak tersedia, membangun UDP Custom dari source..."
        build_udpcustom_from_source
        INSTALLED=$?
    fi

    if [ "$INSTALLED" -ne 0 ] || [ ! -x "$UDPCUSTOM_BIN" ]; then
        echo -e "${YELLOW}[!]${NC} UDP Custom: menggunakan implementasi Python fallback..."
        install_udpcustom_python_fallback
    fi

    setup_udpcustom_config
    setup_udpcustom_service
}

build_udpcustom_from_source() {
    if ! command -v go &>/dev/null; then
        apt-get install -y -qq golang &>/dev/null 2>&1 || return 1
    fi
    mkdir -p /tmp/udpcustom-src
    cat > /tmp/udpcustom-src/main.go <<'GOEOF'
package main

import (
    "encoding/json"
    "flag"
    "fmt"
    "log"
    "net"
    "os"
    "strings"
    "sync"
    "time"
)

type Config struct {
    ListenPort    int    `json:"listen_port"`
    ListenPortEnd int    `json:"listen_port_end"`
    RemoteHost    string `json:"remote_host"`
    RemotePort    int    `json:"remote_port"`
    ReqHeader     string `json:"request_header"`
    ResHeader     string `json:"response_header"`
    MaxClients    int    `json:"max_clients"`
    Timeout       int    `json:"timeout"`
    LogFile       string `json:"log_file"`
}

type Client struct {
    addr     *net.UDPAddr
    lastSeen time.Time
}

var (
    cfgFile = flag.String("c", "/etc/ssh-panel/config/udp-custom.json", "config")
    clients sync.Map
)

func loadConfig() Config {
    cfg := Config{
        ListenPort: 7100, ListenPortEnd: 7900,
        RemoteHost: "127.0.0.1", RemotePort: 7300,
        ReqHeader: "GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]",
        ResHeader: "HTTP/1.1 101 Switching Protocols[crlf][crlf]",
        MaxClients: 1000, Timeout: 60,
        LogFile: "/var/log/ssh-panel/udp-custom.log",
    }
    data, err := os.ReadFile(*cfgFile)
    if err == nil { json.Unmarshal(data, &cfg) }
    return cfg
}

func injectHeader(data []byte, header string, host string) []byte {
    h := strings.ReplaceAll(header, "[crlf]", "\r\n")
    h = strings.ReplaceAll(h, "[host]", host)
    if h == "" { return data }
    return append([]byte(h), data...)
}

func handleClient(serverConn *net.UDPConn, clientAddr *net.UDPAddr, data []byte, cfg Config) {
    remoteAddr := fmt.Sprintf("%s:%d", cfg.RemoteHost, cfg.RemotePort)
    remote, err := net.DialUDP("udp", nil, func() *net.UDPAddr {
        a, _ := net.ResolveUDPAddr("udp", remoteAddr)
        return a
    }())
    if err != nil { return }
    defer remote.Close()

    payload := injectHeader(data, cfg.ReqHeader, cfg.RemoteHost)
    remote.SetDeadline(time.Now().Add(time.Duration(cfg.Timeout) * time.Second))
    remote.Write(payload)

    buf := make([]byte, 65535)
    n, err := remote.Read(buf)
    if err != nil { return }

    resp := injectHeader(buf[:n], cfg.ResHeader, "")
    serverConn.WriteToUDP(resp, clientAddr)
    clients.Store(clientAddr.String(), time.Now())
}

func startListener(port int, cfg Config) {
    addr, _ := net.ResolveUDPAddr("udp", fmt.Sprintf("0.0.0.0:%d", port))
    conn, err := net.ListenUDP("udp", addr)
    if err != nil { return }
    defer conn.Close()
    log.Printf("[UDP-Custom] Port %d active → %s:%d", port, cfg.RemoteHost, cfg.RemotePort)
    buf := make([]byte, 65535)
    for {
        conn.SetReadDeadline(time.Now().Add(60 * time.Second))
        n, addr, err := conn.ReadFromUDP(buf)
        if err != nil { continue }
        go handleClient(conn, addr, buf[:n], cfg)
    }
}

func main() {
    flag.Parse()
    cfg := loadConfig()
    fmt.Printf("[UDP-Custom] Starting on ports %d-%d\n", cfg.ListenPort, cfg.ListenPortEnd)
    var wg sync.WaitGroup
    for p := cfg.ListenPort; p <= cfg.ListenPortEnd; p++ {
        wg.Add(1)
        go func(port int) {
            defer wg.Done()
            startListener(port, cfg)
        }(p)
    }
    wg.Wait()
}
GOEOF
    cd /tmp/udpcustom-src
    go build -o "$UDPCUSTOM_BIN" main.go &>/dev/null
    cd /tmp && rm -rf udpcustom-src
    if [ -x "$UDPCUSTOM_BIN" ]; then
        echo -e "${GREEN}[✔]${NC} UDP Custom berhasil di-build dari source"
        return 0
    fi
    return 1
}

install_udpcustom_python_fallback() {
    cat > /usr/local/bin/udp-custom-py.py <<'PYEOF'
#!/usr/bin/env python3
"""UDP Custom - Python Fallback Implementation dengan Header Injeksi"""
import socket, threading, json, os, sys, logging, time, re

logging.basicConfig(
    filename='/var/log/ssh-panel/udp-custom.log',
    level=logging.INFO,
    format='%(asctime)s [UDP-Custom] %(message)s'
)

CFG_FILE = "/etc/ssh-panel/config/udp-custom.json"

def load_config():
    defaults = {
        "listen_port": 7100,
        "listen_port_end": 7900,
        "remote_host": "127.0.0.1",
        "remote_port": 7300,
        "request_header": "GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]",
        "response_header": "HTTP/1.1 101 Switching Protocols[crlf][crlf]",
        "max_clients": 1000,
        "timeout": 60
    }
    try:
        with open(CFG_FILE) as f:
            defaults.update(json.load(f))
    except:
        pass
    return defaults

def inject_header(data: bytes, header: str, host: str) -> bytes:
    if not header:
        return data
    h = header.replace("[crlf]", "\r\n").replace("[host]", host)
    return h.encode() + data

def relay(server_sock, client_addr, data, cfg):
    try:
        remote = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        remote.settimeout(cfg["timeout"])
        payload = inject_header(data, cfg.get("request_header",""), cfg["remote_host"])
        remote.sendto(payload, (cfg["remote_host"], cfg["remote_port"]))
        try:
            resp, _ = remote.recvfrom(65535)
            resp = inject_header(resp, cfg.get("response_header",""), "")
            server_sock.sendto(resp, client_addr)
        except socket.timeout:
            pass
        finally:
            remote.close()
    except Exception as e:
        logging.error(f"Relay: {e}")

def listen_port(port, cfg):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("0.0.0.0", port))
        logging.info(f"Port {port} active -> {cfg['remote_host']}:{cfg['remote_port']}")
        buf = bytearray(65535)
        while True:
            n, addr = sock.recvfrom_into(buf)
            t = threading.Thread(target=relay, args=(sock, addr, bytes(buf[:n]), cfg), daemon=True)
            t.start()
    except Exception as e:
        logging.error(f"Listen port {port}: {e}")

def main():
    cfg = load_config()
    threads = []
    start = cfg["listen_port"]
    end = cfg.get("listen_port_end", start)
    print(f"[UDP-Custom] Starting ports {start}-{end} -> {cfg['remote_host']}:{cfg['remote_port']}")
    for port in range(start, end + 1):
        t = threading.Thread(target=listen_port, args=(port, cfg), daemon=True)
        t.start()
        threads.append(t)
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
PYEOF
    chmod +x /usr/local/bin/udp-custom-py.py
    ln -sf /usr/local/bin/udp-custom-py.py "$UDPCUSTOM_BIN"
    echo -e "${GREEN}[✔]${NC} UDP Custom Python fallback installed"
}

setup_udpcustom_config() {
    mkdir -p "$(dirname "$UDPCUSTOM_CFG")"
    if [ ! -f "$UDPCUSTOM_CFG" ]; then
        cat > "$UDPCUSTOM_CFG" <<EOF
{
  "listen_port": 7100,
  "listen_port_end": 7900,
  "remote_host": "127.0.0.1",
  "remote_port": 7300,
  "request_header": "GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]",
  "response_header": "HTTP/1.1 101 Switching Protocols[crlf][crlf]",
  "max_clients": 1000,
  "timeout": 60,
  "log_file": "/var/log/ssh-panel/udp-custom.log"
}
EOF
    fi
}

setup_udpcustom_service() {
    cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Tunnel PRO (Multi-Port)
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$UDPCUSTOM_BIN -c $UDPCUSTOM_CFG
Restart=always
RestartSec=5
LimitNOFILE=1000000
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload &>/dev/null
    systemctl enable udp-custom &>/dev/null
    systemctl restart udp-custom &>/dev/null
    echo -e "${GREEN}[✔]${NC} UDP Custom service aktif di port 7100-7900"
}

# ─── BANNER ──────────────────────────────────────────────────
show_banner() {
    clear
    get_server_info
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}         SSH ALL PROTOCOL PANEL PRO v${VERSION}           ${CYAN}║${NC}"
    echo -e "${CYAN}║${DIM}              Enhanced & Professional Edition               ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}IP Server  :${NC} ${GREEN}$MYIP${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Hostname   :${NC} ${GREEN}$(hostname)${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Location   :${NC} ${GREEN}$CITY, $COUNTRY${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}ISP        :${NC} ${GREEN}$ISP${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}OS         :${NC} ${GREEN}$(lsb_release -d 2>/dev/null | cut -d: -f2 | xargs || uname -o)${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Kernel     :${NC} ${GREEN}$KERNEL${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}CPU        :${NC} ${GREEN}$CPU_CORES Core - $CPU_MODEL${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}RAM        :${NC} ${GREEN}${RAM_USED}MB / ${RAM_TOTAL}MB${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Disk       :${NC} ${GREEN}${DISK_USED} / ${DISK_TOTAL}${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Uptime     :${NC} ${GREEN}$UPTIME${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Load Avg   :${NC} ${GREEN}$LOAD${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─── MAIN MENU ───────────────────────────────────────────────
main_menu() {
    show_banner
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                      MAIN MENU                            ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[01]${NC} Manage SSH / OpenSSH          ${GREEN}[09]${NC} Manage V2Ray/Xray  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[02]${NC} Manage Dropbear               ${GREEN}[10]${NC} Manage Trojan      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[03]${NC} Manage WebSocket (WS)         ${GREEN}[11]${NC} Manage SlowDNS     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[04]${NC} Manage WebSocket SSL (WSS)    ${GREEN}[12]${NC} Manage Squid Proxy ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[05]${NC} Manage Stunnel4 (SSL)         ${GREEN}[13]${NC} UDP ZiVPN          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[06]${NC} Manage OpenVPN TCP            ${GREEN}[14]${NC} UDP Custom         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[07]${NC} Manage OpenVPN UDP            ${GREEN}[15]${NC} BadVPN UdpGW       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[08]${NC} Manage SOCKS5                 ${GREEN}[16]${NC} Port Manager       ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[17]${NC} User Manager                  ${YELLOW}[21]${NC} Firewall/IPTables  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[18]${NC} Multi-Login Monitor           ${YELLOW}[22]${NC} Bandwidth Monitor  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[19]${NC} Active Users Monitor          ${YELLOW}[23]${NC} Auto-Kill Script   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}[20]${NC} Expired User Cleaner          ${YELLOW}[24]${NC} IP Limit Manager   ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}[25]${NC} System Info & Health          ${MAGENTA}[29]${NC} Speedtest          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}[26]${NC} Certificate Manager (SSL)     ${MAGENTA}[30]${NC} Generate Config    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}[27]${NC} Backup & Restore              ${MAGENTA}[31]${NC} Nginx Manager      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}[28]${NC} Update Panel                  ${MAGENTA}[32]${NC} Cron Job Manager   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${MAGENTA}[33]${NC} DNS over HTTPS                ${MAGENTA}[34]${NC} UDP Monitor Live   ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${RED}[00]${NC} Exit Panel                                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${WHITE}Select Menu ${CYAN}[00-34]${NC} : "
    read -r choice
    handle_menu "$choice"
}

# ─── MENU HANDLER ────────────────────────────────────────────
handle_menu() {
    case "$1" in
        01|1)  menu_ssh ;;
        02|2)  menu_dropbear ;;
        03|3)  menu_ws ;;
        04|4)  menu_wss ;;
        05|5)  menu_stunnel ;;
        06|6)  menu_openvpn_tcp ;;
        07|7)  menu_openvpn_udp ;;
        08|8)  menu_socks5 ;;
        09|9)  menu_v2ray ;;
        10)    menu_trojan ;;
        11)    menu_slowdns ;;
        12)    menu_squid ;;
        13)    menu_zivpn ;;
        14)    menu_udp_custom ;;
        15)    menu_badvpn ;;
        16)    menu_port_manager ;;
        17)    menu_user_manager ;;
        18)    menu_multi_login ;;
        19)    menu_active_users ;;
        20)    menu_expired_cleaner ;;
        21)    menu_firewall ;;
        22)    menu_bandwidth ;;
        23)    menu_autokill ;;
        24)    menu_ip_limit ;;
        25)    menu_sysinfo ;;
        26)    menu_ssl_cert ;;
        27)    menu_backup ;;
        28)    menu_update ;;
        29)    menu_speedtest ;;
        30)    menu_gen_config ;;
        31)    menu_nginx ;;
        32)    menu_cron ;;
        33)    menu_dns_https ;;
        34)    menu_udp_monitor ;;
        00|0)  echo -e "${GREEN}Bye!${NC}"; exit 0 ;;
        *)     echo -e "${RED}Menu tidak valid!${NC}"; sleep 1; main_menu ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# ─── USER MANAGER ────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
menu_user_manager() {
    clear
    show_banner
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}           USER MANAGER PRO               ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Add User SSH + All Protocol      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} Delete User                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} Renew / Extend User              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} List All Users                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} Check User Expire                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} Lock / Unlock User               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[7]${NC} Change User Password             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[8]${NC} Set IP Limit                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[9]${NC} Trial User (1 Hari)              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back to Main Menu                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"
    read -r opt
    case "$opt" in
        1) add_user ;;
        2) del_user ;;
        3) renew_user ;;
        4) list_users ;;
        5) check_expire ;;
        6) lock_unlock_user ;;
        7) change_password ;;
        8) set_ip_limit ;;
        9) add_trial_user ;;
        0) main_menu ;;
        *) menu_user_manager ;;
    esac
}

add_user() {
    clear
    echo -e "\n${CYAN}══ ADD USER SSH ALL PROTOCOL ══${NC}\n"
    echo -ne "${YELLOW}Username     : ${NC}"; read -r USER
    echo -ne "${YELLOW}Password     : ${NC}"; read -r PASS
    echo -ne "${YELLOW}Masa Aktif (hari) : ${NC}"; read -r DAYS
    echo -ne "${YELLOW}Maks. Login  : ${NC}"; read -r MAXLOGIN
    [[ -z "$USER" || -z "$PASS" || -z "$DAYS" ]] && { echo -e "${RED}Input tidak boleh kosong!${NC}"; sleep 1; add_user; return; }
    [[ -z "$MAXLOGIN" ]] && MAXLOGIN=2
    EXP=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    # Create system user
    if id "$USER" &>/dev/null; then
        echo -e "${RED}User sudah ada!${NC}"; sleep 1; return
    fi
    useradd -e "$EXP" -s /bin/false -M "$USER"
    echo "$USER:$PASS" | chpasswd
    # Save to DB
    echo "$USER:$PASS:$EXP:$MAXLOGIN:active" >> "$DB_FILE"
    # Get V2Ray UUID
    V2UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)
    # Add V2Ray user if xray/v2ray running
    if command -v xray &>/dev/null; then
        V2CFG="/usr/local/etc/xray/config.json"
        if [ -f "$V2CFG" ]; then
            python3 -c "
import json,sys
cfg=json.load(open('$V2CFG'))
for inb in cfg.get('inbounds',[]):
    if inb.get('protocol') in ['vmess','vless']:
        inb['settings']['clients'].append({'id':'$V2UUID','alterId':0,'email':'$USER'})
    elif inb.get('protocol')=='trojan':
        inb['settings']['clients'].append({'password':'${PASS}','email':'$USER'})
json.dump(cfg,open('$V2CFG','w'),indent=2)
" 2>/dev/null && systemctl restart xray &>/dev/null
        fi
    fi
    local ZPORT=$(jq -r '.listen_port' "$ZIVPN_CFG" 2>/dev/null || echo "5300")
    local UCPORT_S=$(jq -r '.listen_port' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7100")
    local UCPORT_E=$(jq -r '.listen_port_end' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7900")
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${BOLD}${WHITE}         AKUN BERHASIL DIBUAT ✔                   ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${YELLOW}Username     :${NC} $USER"
    echo -e "${GREEN}║${NC} ${YELLOW}Password     :${NC} $PASS"
    echo -e "${GREEN}║${NC} ${YELLOW}Expired      :${NC} $EXP"
    echo -e "${GREEN}║${NC} ${YELLOW}Max Login    :${NC} $MAXLOGIN"
    echo -e "${GREEN}║${NC} ${YELLOW}IP Server    :${NC} $MYIP"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► SSH / Dropbear${NC}"
    echo -e "${GREEN}║${NC}   SSH Port   : 22, 2222"
    echo -e "${GREEN}║${NC}   Dropbear   : 143, 109"
    echo -e "${GREEN}║${NC}   SSL/TLS    : 443, 442"
    echo -e "${GREEN}║${NC}   WS Port    : 80, 8080 | Path: /ssh-ws"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► UDP ZiVPN${NC}"
    echo -e "${GREEN}║${NC}   UDP Port   : $ZPORT"
    echo -e "${GREEN}║${NC}   Host       : $MYIP"
    echo -e "${GREEN}║${NC}   User/Pass  : $USER / $PASS"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► UDP Custom (Multi-Port)${NC}"
    echo -e "${GREEN}║${NC}   UDP Ports  : $UCPORT_S - $UCPORT_E"
    echo -e "${GREEN}║${NC}   Host       : $MYIP"
    echo -e "${GREEN}║${NC}   User/Pass  : $USER / $PASS"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► V2Ray VMess (WS)${NC}"
    echo -e "${GREEN}║${NC}   UUID       : $V2UUID"
    echo -e "${GREEN}║${NC}   Port/Path  : 8080 / /vmess | TLS: false"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► VLESS (WS)${NC}"
    echo -e "${GREEN}║${NC}   UUID       : $V2UUID"
    echo -e "${GREEN}║${NC}   Port/Path  : 8443 / /vless"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► Trojan (WS)${NC}"
    echo -e "${GREEN}║${NC}   Password   : $PASS"
    echo -e "${GREEN}║${NC}   Port/Path  : 3478 / /trojan"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► SlowDNS${NC}"
    echo -e "${GREEN}║${NC}   Host       : $MYIP"
    echo -e "${GREEN}║${NC}   User/Pass  : $USER / $PASS"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    read -rp "Press Enter to continue..."
    menu_user_manager
}

del_user() {
    clear
    echo -e "\n${CYAN}══ DELETE USER ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username to delete: ${NC}"; read -r USER
    if ! id "$USER" &>/dev/null; then
        echo -e "${RED}User tidak ditemukan!${NC}"; sleep 1; return
    fi
    userdel -f "$USER" &>/dev/null
    sed -i "/^$USER:/d" "$DB_FILE"
    # Remove from xray config
    if command -v xray &>/dev/null && [ -f /usr/local/etc/xray/config.json ]; then
        python3 -c "
import json
cfg=json.load(open('/usr/local/etc/xray/config.json'))
for inb in cfg.get('inbounds',[]):
    s=inb.get('settings',{})
    for k in ['clients']:
        s[k]=[c for c in s.get(k,[]) if c.get('email','')!='$USER']
json.dump(cfg,open('/usr/local/etc/xray/config.json','w'),indent=2)
" 2>/dev/null && systemctl restart xray &>/dev/null
    fi
    echo -e "${GREEN}[✔]${NC} User ${YELLOW}$USER${NC} berhasil dihapus!"
    sleep 1; menu_user_manager
}

renew_user() {
    clear
    echo -e "\n${CYAN}══ RENEW USER ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username: ${NC}"; read -r USER
    echo -ne "${YELLOW}Tambah hari: ${NC}"; read -r DAYS
    if ! id "$USER" &>/dev/null; then
        echo -e "${RED}User tidak ditemukan!${NC}"; sleep 1; return
    fi
    NEW_EXP=$(date -d "+${DAYS} days" +"%Y-%m-%d")
    chage -E "$NEW_EXP" "$USER"
    sed -i "s/^$USER:\([^:]*\):[^:]*:\([^:]*:[^:]*\)/$USER:\1:$NEW_EXP:\2/" "$DB_FILE"
    echo -e "${GREEN}[✔]${NC} User ${YELLOW}$USER${NC} diperpanjang hingga ${GREEN}$NEW_EXP${NC}"
    sleep 1; menu_user_manager
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                   DAFTAR USER AKTIF                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════╦══════════════╦══════════╦════════════════╣${NC}"
    printf "${CYAN}║${NC} %-13s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-8s ${CYAN}║${NC} %-14s ${CYAN}║${NC}\n" "Username" "Expired" "MaxLogin" "Status"
    echo -e "${CYAN}╠═══════════════╬══════════════╬══════════╬════════════════╣${NC}"
    if [ -s "$DB_FILE" ]; then
        while IFS=: read -r user pass exp maxlogin status; do
            TODAY=$(date +%Y-%m-%d)
            if [[ "$exp" < "$TODAY" ]]; then
                STATUS="${RED}EXPIRED${NC}"
            else
                STATUS="${GREEN}ACTIVE${NC}"
            fi
            printf "${CYAN}║${NC} %-13s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-8s ${CYAN}║${NC} " "$user" "$exp" "$maxlogin"
            echo -e "$STATUS ${CYAN}║${NC}"
        done < "$DB_FILE"
    else
        echo -e "${CYAN}║${NC}  Belum ada user terdaftar                                 ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚═══════════════╩══════════════╩══════════╩════════════════╝${NC}"
    echo ""
    read -rp "Press Enter to continue..."; menu_user_manager
}

list_users_short() {
    echo -e "${YELLOW}Users:${NC}"
    awk -F: '{print "  - "$1" (exp: "$3")"}' "$DB_FILE" 2>/dev/null || echo "  (kosong)"
    echo ""
}

check_expire() {
    clear
    echo -e "\n${CYAN}══ CEK EXPIRED USER ══${NC}\n"
    TODAY=$(date +%Y-%m-%d)
    FOUND=0
    while IFS=: read -r user pass exp maxlogin status; do
        if [[ "$exp" < "$TODAY" ]]; then
            echo -e "${RED}[EXPIRED]${NC} $user - Expired: $exp"
            FOUND=$((FOUND+1))
        elif [[ $(( ($(date -d "$exp" +%s) - $(date +%s)) / 86400 )) -le 3 ]]; then
            SISA=$(( ($(date -d "$exp" +%s) - $(date +%s)) / 86400 ))
            echo -e "${YELLOW}[SOON]${NC} $user - Sisa: ${SISA} hari (exp: $exp)"
        fi
    done < "$DB_FILE"
    [[ $FOUND -eq 0 ]] && echo -e "${GREEN}Tidak ada user expired.${NC}"
    echo ""
    read -rp "Press Enter..."; menu_user_manager
}

lock_unlock_user() {
    clear
    echo -e "\n${CYAN}══ LOCK / UNLOCK USER ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username: ${NC}"; read -r USER
    echo -ne "${YELLOW}Action (lock/unlock): ${NC}"; read -r ACTION
    if [[ "$ACTION" == "lock" ]]; then
        passwd -l "$USER" &>/dev/null
        echo -e "${GREEN}[✔]${NC} User $USER di-lock!"
    else
        passwd -u "$USER" &>/dev/null
        echo -e "${GREEN}[✔]${NC} User $USER di-unlock!"
    fi
    sleep 1; menu_user_manager
}

change_password() {
    clear
    echo -e "\n${CYAN}══ GANTI PASSWORD USER ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username : ${NC}"; read -r USER
    echo -ne "${YELLOW}Password Baru: ${NC}"; read -r NEWPASS
    echo "$USER:$NEWPASS" | chpasswd
    sed -i "s/^$USER:[^:]*:/$USER:$NEWPASS:/" "$DB_FILE"
    echo -e "${GREEN}[✔]${NC} Password berhasil diubah!"
    sleep 1; menu_user_manager
}

set_ip_limit() {
    clear
    echo -e "\n${CYAN}══ SET IP LIMIT ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username : ${NC}"; read -r USER
    echo -ne "${YELLOW}Max IP (1-10): ${NC}"; read -r MAXIP
    sed -i "s/^$USER:\([^:]*:[^:]*\):[^:]*:/$USER:\1:$MAXIP:/" "$DB_FILE"
    echo -e "${GREEN}[✔]${NC} IP limit user $USER diset ke $MAXIP!"
    sleep 1; menu_user_manager
}

add_trial_user() {
    clear
    echo -e "\n${CYAN}══ ADD TRIAL USER (1 HARI) ══${NC}\n"
    echo -ne "${YELLOW}Username: ${NC}"; read -r USER
    echo -ne "${YELLOW}Password: ${NC}"; read -r PASS
    DAYS=1; MAXLOGIN=1
    EXP=$(date -d "+1 day" +"%Y-%m-%d")
    if id "$USER" &>/dev/null; then
        echo -e "${RED}User sudah ada!${NC}"; sleep 1; return
    fi
    useradd -e "$EXP" -s /bin/false -M "$USER"
    echo "$USER:$PASS" | chpasswd
    echo "$USER:$PASS:$EXP:$MAXLOGIN:trial" >> "$DB_FILE"
    echo -e "${GREEN}[✔]${NC} Trial user ${YELLOW}$USER${NC} dibuat! Expired: ${RED}$EXP${NC}"
    sleep 1; menu_user_manager
}

# ═══════════════════════════════════════════════════════════════
# ─── ACTIVE USERS MONITOR ────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
menu_active_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                ACTIVE USERS MONITOR                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    # SSH Active
    SSH_USERS=$(who | awk '{print $1}' | sort -u)
    SSH_COUNT=$(who | wc -l)
    echo -e "${CYAN}║${NC} ${YELLOW}[SSH ACTIVE - $SSH_COUNT sessions]${NC}"
    if [ -n "$SSH_USERS" ]; then
        while IFS= read -r line; do
            USER=$(echo "$line" | awk '{print $1}')
            FROM=$(echo "$line" | awk '{print $5}' | tr -d '()')
            SINCE=$(echo "$line" | awk '{print $3,$4}')
            echo -e "${CYAN}║${NC}   ${GREEN}$USER${NC} from ${CYAN}$FROM${NC} since $SINCE"
        done <<< "$(who)"
    else
        echo -e "${CYAN}║${NC}   Tidak ada user aktif"
    fi
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    # OpenVPN Active
    echo -e "${CYAN}║${NC} ${YELLOW}[OpenVPN Active]${NC}"
    if [ -f /var/log/openvpn-status.log ]; then
        OVPN_COUNT=$(grep "CLIENT_LIST" /var/log/openvpn-status.log | wc -l)
        echo -e "${CYAN}║${NC}   Clients: $OVPN_COUNT"
        grep "CLIENT_LIST" /var/log/openvpn-status.log | while IFS=, read -r _ name real virtual _ _ since; do
            echo -e "${CYAN}║${NC}   ${GREEN}$name${NC} - ${CYAN}$real${NC} since $since"
        done
    else
        echo -e "${CYAN}║${NC}   OpenVPN status tidak tersedia"
    fi
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}[System Load]${NC}"
    echo -e "${CYAN}║${NC}   CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% | RAM: ${RAM_USED}MB/${RAM_TOTAL}MB"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -rp "Press Enter to continue..."; main_menu
}

# ─── MULTI LOGIN MONITOR ─────────────────────────────────────
menu_multi_login() {
    clear
    echo -e "\n${CYAN}══ MULTI LOGIN MONITOR ══${NC}\n"
    echo -e "${YELLOW}Detecting duplicate logins...${NC}\n"
    who | awk '{print $1}' | sort | uniq -d | while read -r user; do
        COUNT=$(who | grep "^$user " | wc -l)
        echo -e "${RED}[MULTI]${NC} User ${YELLOW}$user${NC} login ${RED}$COUNT${NC} kali"
        who | grep "^$user " | awk '{print "       From:", $5}'
    done
    TOTAL=$(who | awk '{print $1}' | sort | uniq -d | wc -l)
    echo -e "\nTotal multi-login users: ${RED}$TOTAL${NC}"
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── EXPIRED CLEANER ─────────────────────────────────────────
menu_expired_cleaner() {
    clear
    echo -e "\n${CYAN}══ EXPIRED USER CLEANER ══${NC}\n"
    TODAY=$(date +%Y-%m-%d)
    CLEANED=0
    while IFS=: read -r user pass exp maxlogin status; do
        if [[ "$exp" < "$TODAY" ]]; then
            userdel -f "$user" &>/dev/null
            sed -i "/^$user:/d" "$DB_FILE"
            echo -e "${GREEN}[DEL]${NC} User ${YELLOW}$user${NC} (exp: $exp) dihapus"
            CLEANED=$((CLEANED+1))
        fi
    done < "$DB_FILE"
    echo -e "\n${GREEN}$CLEANED${NC} user expired berhasil dibersihkan."
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── AUTO KILL MULTI LOGIN ───────────────────────────────────
menu_autokill() {
    clear
    echo -e "\n${CYAN}══ AUTO KILL MULTI LOGIN ══${NC}\n"
    echo -ne "${YELLOW}Aktifkan auto-kill multi login? (y/n): ${NC}"; read -r yn
    if [[ "$yn" == "y" ]]; then
        cat > /usr/local/bin/autokill-multi.sh <<'AKEOF'
#!/bin/bash
DB="/etc/ssh-panel/users.db"
while IFS=: read -r user pass exp maxlogin status; do
    COUNT=$(who | grep -c "^$user ")
    MAX=${maxlogin:-2}
    if [ "$COUNT" -gt "$MAX" ]; then
        PIDS=$(who | grep "^$user " | awk '{print $6}' | tr -d '()' | head -n$(($COUNT - $MAX)))
        for PID in $PIDS; do
            kill -9 "$PID" 2>/dev/null
        done
        logger "Auto-kill: user $user exceeded $MAX logins"
    fi
done < "$DB"
AKEOF
        chmod +x /usr/local/bin/autokill-multi.sh
        (crontab -l 2>/dev/null | grep -v autokill-multi; echo "*/2 * * * * /usr/local/bin/autokill-multi.sh") | crontab -
        echo -e "${GREEN}[✔]${NC} Auto-kill aktif! (cek tiap 2 menit)"
    else
        crontab -l 2>/dev/null | grep -v autokill-multi | crontab -
        echo -e "${YELLOW}[!]${NC} Auto-kill dinonaktifkan"
    fi
    sleep 1; main_menu
}

# ─── BANDWIDTH MONITOR ───────────────────────────────────────
menu_bandwidth() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}       BANDWIDTH MONITOR              ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    NIC=$(ip route get 1 | awk '{print $5; exit}')
    RX=$(cat /sys/class/net/$NIC/statistics/rx_bytes 2>/dev/null || echo 0)
    TX=$(cat /sys/class/net/$NIC/statistics/tx_bytes 2>/dev/null || echo 0)
    RX_MB=$(echo "scale=2; $RX/1048576" | bc)
    TX_MB=$(echo "scale=2; $TX/1048576" | bc)
    echo -e "${CYAN}║${NC} Interface : ${GREEN}$NIC${NC}"
    echo -e "${CYAN}║${NC} Download  : ${GREEN}${RX_MB} MB${NC}"
    echo -e "${CYAN}║${NC} Upload    : ${GREEN}${TX_MB} MB${NC}"
    if command -v vnstat &>/dev/null; then
        echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}[VnStat Monthly]${NC}"
        vnstat --oneline 2>/dev/null | while read -r line; do
            echo -e "${CYAN}║${NC} $line"
        done
    fi
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── PORT MANAGER ────────────────────────────────────────────
menu_port_manager() {
    clear
    echo -e "\n${CYAN}══ PORT MANAGER ══${NC}\n"
    echo -e "${YELLOW}Port yang sedang digunakan:${NC}"
    echo -e "SSH        : $(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' | tr '\n' ' ')"
    echo -e "Dropbear   : 143, 109"
    echo -e "Stunnel    : 443, 442"
    echo -e "WS         : 80, 8080"
    echo -e "OpenVPN    : 1194"
    echo -e "V2Ray/Xray : 8080, 8443, 3478"
    echo -e "BadVPN UDP : 7300"
    echo -e "Squid      : 3128, 8888"
    echo -e "ZiVPN UDP  : $(jq -r '.listen_port' "$ZIVPN_CFG" 2>/dev/null || echo "5300")"
    echo -e "UDP Custom : $(jq -r '.listen_port' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7100")-$(jq -r '.listen_port_end' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7900")"
    echo ""
    echo -e "${YELLOW}Open ports:${NC}"
    ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | sort -u
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── SYSTEM INFO ─────────────────────────────────────────────
menu_sysinfo() {
    clear
    get_server_info
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                  SYSTEM INFORMATION                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} IP Public   : ${GREEN}$MYIP${NC}"
    echo -e "${CYAN}║${NC} ISP         : ${GREEN}$ISP${NC}"
    echo -e "${CYAN}║${NC} Kota        : ${GREEN}$CITY${NC}"
    echo -e "${CYAN}║${NC} Negara      : ${GREEN}$COUNTRY${NC}"
    echo -e "${CYAN}║${NC} OS          : ${GREEN}$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')${NC}"
    echo -e "${CYAN}║${NC} Kernel      : ${GREEN}$KERNEL${NC}"
    echo -e "${CYAN}║${NC} Uptime      : ${GREEN}$UPTIME${NC}"
    echo -e "${CYAN}║${NC} Load Avg    : ${GREEN}$LOAD${NC}"
    echo -e "${CYAN}║${NC} CPU         : ${GREEN}$CPU_CORES Core${NC}"
    echo -e "${CYAN}║${NC} RAM         : ${GREEN}${RAM_USED}MB / ${RAM_TOTAL}MB${NC}"
    echo -e "${CYAN}║${NC} Disk        : ${GREEN}${DISK_USED} / ${DISK_TOTAL}${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}Service Status:${NC}"
    for svc in ssh dropbear stunnel4 openvpn xray nginx squid badvpn-udpgw zivpn udp-custom; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "${CYAN}║${NC}   ${GREEN}[✔] $svc${NC}"
        else
            echo -e "${CYAN}║${NC}   ${RED}[✘] $svc${NC}"
        fi
    done
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── FIREWALL MANAGER ────────────────────────────────────────
menu_firewall() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}        FIREWALL / IPTABLES           ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Lihat Rules IPTables        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} Allow Port                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} Block Port                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Block IP                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} Unblock IP                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} Setup Default Rules         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[7]${NC} Flush All Rules              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1) iptables -L -n -v; echo ""; read -rp "Enter..." ;;
        2) echo -ne "Port: "; read -r PORT; iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT; echo -e "${GREEN}[✔]${NC} Port $PORT allowed" ;;
        3) echo -ne "Port: "; read -r PORT; iptables -A INPUT -p tcp --dport "$PORT" -j DROP; echo -e "${GREEN}[✔]${NC} Port $PORT blocked" ;;
        4) echo -ne "IP: "; read -r IP; iptables -A INPUT -s "$IP" -j DROP; echo -e "${GREEN}[✔]${NC} IP $IP blocked" ;;
        5) echo -ne "IP: "; read -r IP; iptables -D INPUT -s "$IP" -j DROP; echo -e "${GREEN}[✔]${NC} IP $IP unblocked" ;;
        6) setup_default_iptables ;;
        7) iptables -F; echo -e "${GREEN}[✔]${NC} All rules flushed" ;;
        0) main_menu; return ;;
    esac
    sleep 1; menu_firewall
}

setup_default_iptables() {
    iptables -F
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    for PORT in 22 109 143 442 443 80 8080 1194 8443 3478 3128 7300 2222 5300; do
        iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
    done
    iptables -A INPUT -p udp --dport 1194 -j ACCEPT
    iptables -A INPUT -p udp --dport 7300 -j ACCEPT
    iptables -A INPUT -p udp --dport 5300 -j ACCEPT
    # UDP Custom port range 7100-7900
    iptables -A INPUT -p udp --dport 7100:7900 -j ACCEPT
    iptables -t nat -A POSTROUTING -j MASQUERADE
    echo -e "${GREEN}[✔]${NC} Default firewall rules applied!"
}

# ─── SSL CERT MANAGER ────────────────────────────────────────
menu_ssl_cert() {
    clear
    echo -e "\n${CYAN}══ SSL CERTIFICATE MANAGER ══${NC}\n"
    echo -e "${GREEN}[1]${NC} Generate Self-Signed Cert"
    echo -e "${GREEN}[2]${NC} Install Let's Encrypt (Certbot)"
    echo -e "${GREEN}[3]${NC} Renew Let's Encrypt"
    echo -e "${GREEN}[4]${NC} Lihat Sertifikat"
    echo -e "${RED}[0]${NC} Back"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1)
            echo -ne "Domain/CN: "; read -r CN
            openssl req -new -x509 -days 3650 -nodes -subj "/CN=$CN" \
                -out "/etc/ssl/${CN}.crt" -keyout "/etc/ssl/${CN}.key"
            echo -e "${GREEN}[✔]${NC} Cert: /etc/ssl/${CN}.crt"
            ;;
        2)
            apt-get install -y certbot &>/dev/null
            echo -ne "Domain: "; read -r DOMAIN
            certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"
            ;;
        3) certbot renew ;;
        4) ls -la /etc/ssl/ /etc/letsencrypt/live/ 2>/dev/null ;;
        0) main_menu; return ;;
    esac
    echo ""
    read -rp "Press Enter..."; menu_ssl_cert
}

# ─── BACKUP & RESTORE ────────────────────────────────────────
menu_backup() {
    clear
    echo -e "\n${CYAN}══ BACKUP & RESTORE ══${NC}\n"
    echo -e "${GREEN}[1]${NC} Backup semua config"
    echo -e "${GREEN}[2]${NC} Restore backup"
    echo -e "${GREEN}[3]${NC} Lihat backup tersedia"
    echo -e "${RED}[0]${NC} Back"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1)
            BK_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
            tar -czf "$BK_FILE" \
                /etc/ssh/sshd_config \
                /etc/default/dropbear \
                /etc/stunnel/stunnel.conf \
                /etc/openvpn/server.conf \
                /usr/local/etc/xray/config.json \
                "$ZIVPN_CFG" \
                "$UDPCUSTOM_CFG" \
                "$DB_FILE" 2>/dev/null
            echo -e "${GREEN}[✔]${NC} Backup: $BK_FILE"
            ;;
        2)
            ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null || { echo "Tidak ada backup!"; sleep 1; return; }
            echo -ne "File backup: "; read -r BK
            tar -xzf "$BK" -C / &>/dev/null
            echo -e "${GREEN}[✔]${NC} Restore selesai. Restart services?"
            ;;
        3) ls -lh "$BACKUP_DIR"/ ;;
        0) main_menu; return ;;
    esac
    echo ""; read -rp "Press Enter..."; menu_backup
}

# ─── SPEEDTEST ───────────────────────────────────────────────
menu_speedtest() {
    clear
    echo -e "\n${CYAN}══ SPEEDTEST SERVER ══${NC}\n"
    if ! command -v speedtest-cli &>/dev/null; then
        echo "Installing speedtest-cli..."
        pip3 install speedtest-cli &>/dev/null || apt-get install -y speedtest-cli &>/dev/null
    fi
    speedtest-cli --simple 2>/dev/null || echo "Speedtest tidak tersedia. Install: pip3 install speedtest-cli"
    echo ""; read -rp "Press Enter..."; main_menu
}

# ─── GENERATE CONFIG (IMPORT LINK) ───────────────────────────
menu_gen_config() {
    clear
    echo -e "\n${CYAN}══ GENERATE CONFIG / IMPORT LINK ══${NC}\n"
    list_users_short
    echo -ne "${YELLOW}Username: ${NC}"; read -r USER
    if ! grep -q "^$USER:" "$DB_FILE" 2>/dev/null; then
        echo -e "${RED}User tidak ditemukan!${NC}"; sleep 1; return
    fi
    PASS=$(grep "^$USER:" "$DB_FILE" | cut -d: -f2)
    V2UUID=$(grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$CONFIG_DIR/v2ray_uuid" 2>/dev/null || echo "N/A")
    local ZPORT=$(jq -r '.listen_port' "$ZIVPN_CFG" 2>/dev/null || echo "5300")
    local UCPORT_S=$(jq -r '.listen_port' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7100")
    local UCPORT_E=$(jq -r '.listen_port_end' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7900")
    local EXP_DATE=$(grep "^$USER:" "$DB_FILE" | cut -d: -f3)
    local MAXLOGIN=$(grep "^$USER:" "$DB_FILE" | cut -d: -f4)
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${BOLD}${WHITE}         AKUN CONFIG - $USER                      ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${YELLOW}Username  :${NC} $USER"
    echo -e "${GREEN}║${NC} ${YELLOW}Password  :${NC} $PASS"
    echo -e "${GREEN}║${NC} ${YELLOW}Expired   :${NC} $EXP_DATE"
    echo -e "${GREEN}║${NC} ${YELLOW}Max Login :${NC} $MAXLOGIN"
    echo -e "${GREEN}║${NC} ${YELLOW}IP Server :${NC} $MYIP"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► SSH Direct${NC}"
    echo -e "${GREEN}║${NC}   ssh $USER@$MYIP -p 22"
    echo -e "${GREEN}║${NC}   ssh $USER@$MYIP -p 2222"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► Dropbear${NC}"
    echo -e "${GREEN}║${NC}   Host: $MYIP | Port: 143 / 109"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► SSH over SSL/TLS (Stunnel)${NC}"
    echo -e "${GREEN}║${NC}   Host: $MYIP | Port: 443 / 442 | SSL: ON"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► SSH over WebSocket${NC}"
    echo -e "${GREEN}║${NC}   Host: $MYIP | Port: 80 | Path: /ssh-ws"
    echo -e "${GREEN}║${NC}   Host: $MYIP | Port: 8080 | Path: /ssh-ws (SSL)"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► UDP ZiVPN${NC}"
    echo -e "${GREEN}║${NC}   Host     : $MYIP"
    echo -e "${GREEN}║${NC}   UDP Port : $ZPORT"
    echo -e "${GREEN}║${NC}   Username : $USER"
    echo -e "${GREEN}║${NC}   Password : $PASS"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► UDP Custom (Multi-Port)${NC}"
    echo -e "${GREEN}║${NC}   Host      : $MYIP"
    echo -e "${GREEN}║${NC}   UDP Ports : $UCPORT_S - $UCPORT_E"
    echo -e "${GREEN}║${NC}   Username  : $USER"
    echo -e "${GREEN}║${NC}   Password  : $PASS"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► V2Ray VMess (WS)${NC}"
    VMESS_CFG=$(echo -n '{"v":"2","ps":"'"$USER"'","add":"'"$MYIP"'","port":"8080","id":"'"$V2UUID"'","aid":"0","net":"ws","type":"none","host":"'"$MYIP"'","path":"/vmess","tls":"none"}' | base64 -w0)
    echo -e "${GREEN}║${NC}   vmess://$VMESS_CFG"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► VLESS (WS)${NC}"
    VLESS_CFG="vless://${V2UUID}@${MYIP}:8443?type=ws&path=/vless&encryption=none#${USER}"
    echo -e "${GREEN}║${NC}   $VLESS_CFG"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}► Trojan (WS)${NC}"
    echo -e "${GREEN}║${NC}   trojan://$PASS@$MYIP:3478?type=ws&path=/trojan#$USER"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    read -rp "Press Enter..."; main_menu
}

# ─── NGINX MANAGER ───────────────────────────────────────────
menu_nginx() {
    clear
    echo -e "\n${CYAN}══ NGINX MANAGER ══${NC}\n"
    echo -e "${GREEN}[1]${NC} Status Nginx"
    echo -e "${GREEN}[2]${NC} Restart Nginx"
    echo -e "${GREEN}[3]${NC} Reload Nginx"
    echo -e "${GREEN}[4]${NC} Test Config"
    echo -e "${GREEN}[5]${NC} Lihat Config"
    echo -e "${RED}[0]${NC} Back"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1) systemctl status nginx --no-pager ;;
        2) systemctl restart nginx && echo -e "${GREEN}[✔] Nginx restarted${NC}" ;;
        3) systemctl reload nginx && echo -e "${GREEN}[✔] Nginx reloaded${NC}" ;;
        4) nginx -t ;;
        5) cat /etc/nginx/conf.d/panel.conf ;;
        0) main_menu; return ;;
    esac
    echo ""; read -rp "Press Enter..."; menu_nginx
}

# ─── V2RAY MENU ──────────────────────────────────────────────
menu_v2ray() {
    clear
    echo -e "\n${CYAN}══ V2RAY / XRAY MANAGER ══${NC}\n"
    echo -e "${GREEN}[1]${NC} Status Xray"
    echo -e "${GREEN}[2]${NC} Restart Xray"
    echo -e "${GREEN}[3]${NC} Lihat Config"
    echo -e "${GREEN}[4]${NC} Lihat UUID V2Ray"
    echo -e "${RED}[0]${NC} Back"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1) systemctl status xray --no-pager ;;
        2) systemctl restart xray && echo -e "${GREEN}[✔] Xray restarted${NC}" ;;
        3) cat /usr/local/etc/xray/config.json 2>/dev/null | python3 -m json.tool 2>/dev/null ;;
        4) echo "UUID: $(cat $CONFIG_DIR/v2ray_uuid 2>/dev/null || echo 'N/A')" ;;
        0) main_menu; return ;;
    esac
    echo ""; read -rp "Press Enter..."; menu_v2ray
}

# ─── UPDATE PANEL ────────────────────────────────────────────
menu_update() {
    clear
    echo -e "\n${CYAN}══ UPDATE PANEL ══${NC}\n"
    echo -e "${YELLOW}[*]${NC} Updating system packages..."
    apt-get update -qq &>/dev/null && apt-get upgrade -y -qq &>/dev/null
    echo -e "${GREEN}[✔]${NC} System updated!"
    echo -e "${YELLOW}[*]${NC} Restarting services..."
    for svc in ssh dropbear stunnel4 nginx xray openvpn@server badvpn-udpgw squid zivpn udp-custom; do
        systemctl restart "$svc" &>/dev/null && echo -e "  ${GREEN}[✔]${NC} $svc"
    done
    echo -e "\n${GREEN}[✔]${NC} Update selesai!"
    read -rp "Press Enter..."; main_menu
}

# ─── CRON MANAGER ────────────────────────────────────────────
menu_cron() {
    clear
    echo -e "\n${CYAN}══ CRON JOB MANAGER ══${NC}\n"
    echo -e "${GREEN}[1]${NC} Lihat cron jobs"
    echo -e "${GREEN}[2]${NC} Setup auto-expired cleaner (daily)"
    echo -e "${GREEN}[3]${NC} Setup auto-restart services"
    echo -e "${RED}[0]${NC} Back"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1) crontab -l 2>/dev/null || echo "(tidak ada)"; echo ""; read -rp "Enter..." ;;
        2)
            (crontab -l 2>/dev/null | grep -v "expired_cleaner"; echo "0 0 * * * bash $0 --clean-expired") | crontab -
            echo -e "${GREEN}[✔]${NC} Auto-expired cleaner diaktifkan (tiap tengah malam)"
            ;;
        3)
            (crontab -l 2>/dev/null | grep -v "restart-services"; echo "@reboot systemctl restart ssh dropbear stunnel4 nginx xray zivpn udp-custom badvpn-udpgw") | crontab -
            echo -e "${GREEN}[✔]${NC} Auto-restart on reboot diaktifkan"
            ;;
        0) main_menu; return ;;
    esac
    sleep 1; menu_cron
}

# ═══════════════════════════════════════════════════════════════
# ─── MENU UDP ZIVPN ──────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
menu_zivpn() {
    clear
    show_banner
    local STATUS_ICON STATUS_TEXT
    if systemctl is-active --quiet zivpn 2>/dev/null; then
        STATUS_ICON="${GREEN}●${NC}"; STATUS_TEXT="${GREEN}RUNNING${NC}"
    else
        STATUS_ICON="${RED}●${NC}"; STATUS_TEXT="${RED}STOPPED${NC}"
    fi
    local CUR_PORT=$(jq -r '.listen_port' "$ZIVPN_CFG" 2>/dev/null || echo "5300")
    local CUR_REMOTE=$(jq -r '.remote_host + ":" + (.remote_port|tostring)' "$ZIVPN_CFG" 2>/dev/null || echo "127.0.0.1:22")
    local CUR_MAX=$(jq -r '.max_clients' "$ZIVPN_CFG" 2>/dev/null || echo "500")
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}           UDP ZiVPN MANAGER PRO                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Status      : $(echo -e $STATUS_ICON) $(echo -e $STATUS_TEXT)"
    echo -e "${CYAN}║${NC} Listen Port : ${YELLOW}UDP $CUR_PORT${NC}"
    echo -e "${CYAN}║${NC} Forward To  : ${YELLOW}$CUR_REMOTE${NC}"
    echo -e "${CYAN}║${NC} Max Clients : ${YELLOW}$CUR_MAX${NC}"
    echo -e "${CYAN}║${NC} Config      : ${DIM}$ZIVPN_CFG${NC}"
    echo -e "${CYAN}║${NC} Log         : ${DIM}/var/log/ssh-panel/zivpn.log${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Start ZiVPN"
    echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} Stop ZiVPN"
    echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} Restart ZiVPN"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Ganti Port ZiVPN"
    echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} Ganti Remote Forward (host:port)"
    echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} Set Max Clients"
    echo -e "${CYAN}║${NC}  ${GREEN}[7]${NC} Lihat Log ZiVPN (live)"
    echo -e "${CYAN}║${NC}  ${GREEN}[8]${NC} Lihat Koneksi Aktif"
    echo -e "${CYAN}║${NC}  ${GREEN}[9]${NC} Reinstall / Update Binary"
    echo -e "${CYAN}║${NC}  ${GREEN}[A]${NC} Edit Config Manual"
    echo -e "${CYAN}║${NC}  ${GREEN}[B]${NC} Test Koneksi ZiVPN"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1)
            systemctl start zivpn
            echo -e "${GREEN}[✔]${NC} ZiVPN started"
            sleep 1 ;;
        2)
            systemctl stop zivpn
            echo -e "${YELLOW}[!]${NC} ZiVPN stopped"
            sleep 1 ;;
        3)
            systemctl restart zivpn
            echo -e "${GREEN}[✔]${NC} ZiVPN restarted"
            sleep 1 ;;
        4)
            echo -ne "${YELLOW}Port baru (UDP): ${NC}"; read -r NEWPORT
            [[ "$NEWPORT" =~ ^[0-9]+$ ]] && {
                python3 -c "
import json
c=json.load(open('$ZIVPN_CFG'))
c['listen_port']=$NEWPORT
json.dump(c,open('$ZIVPN_CFG','w'),indent=2)
" 2>/dev/null
                systemctl restart zivpn
                echo -e "${GREEN}[✔]${NC} ZiVPN port diubah ke UDP $NEWPORT"
            } || echo -e "${RED}Port tidak valid!${NC}"
            sleep 1 ;;
        5)
            echo -ne "${YELLOW}Remote host: ${NC}"; read -r RHOST
            echo -ne "${YELLOW}Remote port: ${NC}"; read -r RPORT
            python3 -c "
import json
c=json.load(open('$ZIVPN_CFG'))
c['remote_host']='$RHOST'
c['remote_port']=$RPORT
json.dump(c,open('$ZIVPN_CFG','w'),indent=2)
" 2>/dev/null
            systemctl restart zivpn
            echo -e "${GREEN}[✔]${NC} ZiVPN forward diubah ke $RHOST:$RPORT"
            sleep 1 ;;
        6)
            echo -ne "${YELLOW}Max clients: ${NC}"; read -r MAXC
            [[ "$MAXC" =~ ^[0-9]+$ ]] && {
                python3 -c "
import json
c=json.load(open('$ZIVPN_CFG'))
c['max_clients']=$MAXC
json.dump(c,open('$ZIVPN_CFG','w'),indent=2)
" 2>/dev/null
                systemctl restart zivpn
                echo -e "${GREEN}[✔]${NC} Max clients diubah ke $MAXC"
            }
            sleep 1 ;;
        7)
            echo -e "${CYAN}[Log ZiVPN - Ctrl+C untuk keluar]${NC}"
            tail -f /var/log/ssh-panel/zivpn.log 2>/dev/null || journalctl -u zivpn -f --no-pager ;;
        8)
            echo -e "${CYAN}══ Koneksi UDP ZiVPN Port $CUR_PORT ══${NC}"
            ss -u -n | grep ":$CUR_PORT" || echo "Tidak ada koneksi aktif"
            echo ""
            read -rp "Press Enter..." ;;
        9)
            echo -e "${YELLOW}[*]${NC} Reinstalling ZiVPN..."
            rm -f "$ZIVPN_BIN"
            install_zivpn
            echo -e "${GREEN}[✔]${NC} Reinstall selesai"
            sleep 1 ;;
        [Aa])
            if command -v nano &>/dev/null; then nano "$ZIVPN_CFG"
            else vi "$ZIVPN_CFG"; fi
            systemctl restart zivpn ;;
        [Bb])
            echo -e "${YELLOW}[*]${NC} Testing UDP ZiVPN port $CUR_PORT..."
            timeout 3 bash -c "echo test | nc -u -w2 127.0.0.1 $CUR_PORT" &>/dev/null \
                && echo -e "${GREEN}[✔]${NC} Port UDP $CUR_PORT merespons" \
                || echo -e "${YELLOW}[?]${NC} UDP port $CUR_PORT (tidak ada respons - normal untuk UDP)"
            sleep 1 ;;
        0) main_menu; return ;;
    esac
    menu_zivpn
}

# ═══════════════════════════════════════════════════════════════
# ─── MENU UDP CUSTOM ─────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
menu_udp_custom() {
    clear
    show_banner
    local STATUS_ICON STATUS_TEXT
    if systemctl is-active --quiet udp-custom 2>/dev/null; then
        STATUS_ICON="${GREEN}●${NC}"; STATUS_TEXT="${GREEN}RUNNING${NC}"
    else
        STATUS_ICON="${RED}●${NC}"; STATUS_TEXT="${RED}STOPPED${NC}"
    fi
    local PORT_START=$(jq -r '.listen_port' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7100")
    local PORT_END=$(jq -r '.listen_port_end' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7900")
    local REMOTE=$(jq -r '.remote_host + ":" + (.remote_port|tostring)' "$UDPCUSTOM_CFG" 2>/dev/null || echo "127.0.0.1:7300")
    local REQHDR=$(jq -r '.request_header' "$UDPCUSTOM_CFG" 2>/dev/null || echo "")
    local RESHDR=$(jq -r '.response_header' "$UDPCUSTOM_CFG" 2>/dev/null || echo "")
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}          UDP CUSTOM MANAGER PRO                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Status       : $(echo -e $STATUS_ICON) $(echo -e $STATUS_TEXT)"
    echo -e "${CYAN}║${NC} Port Range   : ${YELLOW}UDP $PORT_START - $PORT_END${NC}"
    echo -e "${CYAN}║${NC} Forward To   : ${YELLOW}$REMOTE${NC}"
    echo -e "${CYAN}║${NC} Req Header   : ${DIM}${REQHDR:0:45}...${NC}"
    echo -e "${CYAN}║${NC} Res Header   : ${DIM}${RESHDR:0:45}${NC}"
    echo -e "${CYAN}║${NC} Config       : ${DIM}$UDPCUSTOM_CFG${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Start UDP Custom"
    echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} Stop UDP Custom"
    echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} Restart UDP Custom"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Ganti Port Range"
    echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} Ganti Remote Forward"
    echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} Set Request Header"
    echo -e "${CYAN}║${NC}  ${GREEN}[7]${NC} Set Response Header"
    echo -e "${CYAN}║${NC}  ${GREEN}[8]${NC} Preset Header Populer"
    echo -e "${CYAN}║${NC}  ${GREEN}[9]${NC} Lihat Log UDP Custom (live)"
    echo -e "${CYAN}║${NC}  ${GREEN}[A]${NC} Lihat Koneksi Aktif"
    echo -e "${CYAN}║${NC}  ${GREEN}[B]${NC} Test Port UDP Custom"
    echo -e "${CYAN}║${NC}  ${GREEN}[C]${NC} Edit Config Manual"
    echo -e "${CYAN}║${NC}  ${GREEN}[D]${NC} Reinstall / Update Binary"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1)
            systemctl start udp-custom
            echo -e "${GREEN}[✔]${NC} UDP Custom started"
            sleep 1 ;;
        2)
            systemctl stop udp-custom
            echo -e "${YELLOW}[!]${NC} UDP Custom stopped"
            sleep 1 ;;
        3)
            systemctl restart udp-custom
            echo -e "${GREEN}[✔]${NC} UDP Custom restarted"
            sleep 1 ;;
        4)
            echo -ne "${YELLOW}Port mulai: ${NC}"; read -r PS
            echo -ne "${YELLOW}Port akhir: ${NC}"; read -r PE
            [[ "$PS" =~ ^[0-9]+$ && "$PE" =~ ^[0-9]+$ ]] && {
                python3 -c "
import json
c=json.load(open('$UDPCUSTOM_CFG'))
c['listen_port']=$PS
c['listen_port_end']=$PE
json.dump(c,open('$UDPCUSTOM_CFG','w'),indent=2)
" 2>/dev/null
                systemctl restart udp-custom
                echo -e "${GREEN}[✔]${NC} Port range diubah ke UDP $PS-$PE"
            } || echo -e "${RED}Input tidak valid!${NC}"
            sleep 1 ;;
        5)
            echo -ne "${YELLOW}Remote host: ${NC}"; read -r RHOST
            echo -ne "${YELLOW}Remote port: ${NC}"; read -r RPORT
            python3 -c "
import json
c=json.load(open('$UDPCUSTOM_CFG'))
c['remote_host']='$RHOST'
c['remote_port']=$RPORT
json.dump(c,open('$UDPCUSTOM_CFG','w'),indent=2)
" 2>/dev/null
            systemctl restart udp-custom
            echo -e "${GREEN}[✔]${NC} Remote diubah ke $RHOST:$RPORT"
            sleep 1 ;;
        6)
            echo -e "${YELLOW}Format header: gunakan [crlf] untuk newline, [host] untuk hostname${NC}"
            echo -e "${DIM}Contoh: GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]${NC}"
            echo -ne "${YELLOW}Request Header: ${NC}"; read -r REQH
            python3 -c "
import json
c=json.load(open('$UDPCUSTOM_CFG'))
c['request_header']='$REQH'
json.dump(c,open('$UDPCUSTOM_CFG','w'),indent=2)
" 2>/dev/null
            systemctl restart udp-custom
            echo -e "${GREEN}[✔]${NC} Request header diperbarui"
            sleep 1 ;;
        7)
            echo -ne "${YELLOW}Response Header: ${NC}"; read -r RESH
            python3 -c "
import json
c=json.load(open('$UDPCUSTOM_CFG'))
c['response_header']='$RESH'
json.dump(c,open('$UDPCUSTOM_CFG','w'),indent=2)
" 2>/dev/null
            systemctl restart udp-custom
            echo -e "${GREEN}[✔]${NC} Response header diperbarui"
            sleep 1 ;;
        8)
            udp_custom_header_presets ;;
        9)
            echo -e "${CYAN}[Log UDP Custom - Ctrl+C untuk keluar]${NC}"
            tail -f /var/log/ssh-panel/udp-custom.log 2>/dev/null || journalctl -u udp-custom -f --no-pager ;;
        [Aa])
            echo -e "${CYAN}══ Koneksi UDP Custom Port $PORT_START-$PORT_END ══${NC}"
            ss -u -n | awk -v s="$PORT_START" -v e="$PORT_END" '
            {
                split($5,a,":")
                p=a[length(a)]+0
                if(p>=s && p<=e) print
            }' || echo "Tidak ada koneksi aktif"
            echo ""; read -rp "Press Enter..." ;;
        [Bb])
            echo -e "${YELLOW}[*]${NC} Testing UDP Custom port $PORT_START..."
            timeout 3 bash -c "echo test | nc -u -w2 127.0.0.1 $PORT_START" &>/dev/null \
                && echo -e "${GREEN}[✔]${NC} UDP $PORT_START aktif" \
                || echo -e "${YELLOW}[?]${NC} UDP $PORT_START (normal untuk UDP tanpa respons)"
            sleep 1 ;;
        [Cc])
            if command -v nano &>/dev/null; then nano "$UDPCUSTOM_CFG"
            else vi "$UDPCUSTOM_CFG"; fi
            systemctl restart udp-custom ;;
        [Dd])
            echo -e "${YELLOW}[*]${NC} Reinstalling UDP Custom..."
            rm -f "$UDPCUSTOM_BIN"
            install_udp_custom
            echo -e "${GREEN}[✔]${NC} Reinstall selesai"
            sleep 1 ;;
        0) main_menu; return ;;
    esac
    menu_udp_custom
}

udp_custom_header_presets() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}        PRESET HEADER UDP CUSTOM                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} HTTP GET Standar"
    echo -e "${CYAN}║${NC}  ${GREEN}[2]${NC} HTTP CONNECT (Proxy)"
    echo -e "${CYAN}║${NC}  ${GREEN}[3]${NC} WebSocket Upgrade"
    echo -e "${CYAN}║${NC}  ${GREEN}[4]${NC} Telkomsel Bug Host"
    echo -e "${CYAN}║${NC}  ${GREEN}[5]${NC} Indosat Bug Host"
    echo -e "${CYAN}║${NC}  ${GREEN}[6]${NC} XL Bug Host"
    echo -e "${CYAN}║${NC}  ${GREEN}[7]${NC} Axis Bug Host"
    echo -e "${CYAN}║${NC}  ${GREEN}[8]${NC} Custom (input manual)"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"; read -r popt

    local REQH RESH
    case "$popt" in
        1) REQH="GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf][crlf]" ;;
        2) REQH="CONNECT [host]:443 HTTP/1.1[crlf]Host: [host][crlf][crlf]"
           RESH="HTTP/1.1 200 Connection established[crlf][crlf]" ;;
        3) REQH="GET / HTTP/1.1[crlf]Host: [host][crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]" ;;
        4) REQH="GET / HTTP/1.1[crlf]Host: 12271.xl.id[crlf]X-Online-Host: 12271.xl.id[crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf][crlf]" ;;
        5) REQH="GET / HTTP/1.1[crlf]Host: unlimited.isat.io[crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf][crlf]" ;;
        6) REQH="GET / HTTP/1.1[crlf]Host: xlhome.xl.co.id[crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf][crlf]" ;;
        7) REQH="GET / HTTP/1.1[crlf]Host: free.axis.co.id[crlf][crlf]"
           RESH="HTTP/1.1 101 Switching Protocols[crlf][crlf]" ;;
        8)
            echo -ne "${YELLOW}Request Header: ${NC}"; read -r REQH
            echo -ne "${YELLOW}Response Header: ${NC}"; read -r RESH ;;
        0) menu_udp_custom; return ;;
        *) menu_udp_custom; return ;;
    esac

    python3 -c "
import json
c=json.load(open('$UDPCUSTOM_CFG'))
c['request_header']='$REQH'
c['response_header']='$RESH'
json.dump(c,open('$UDPCUSTOM_CFG','w'),indent=2)
" 2>/dev/null
    systemctl restart udp-custom
    echo -e "${GREEN}[✔]${NC} Preset header diterapkan dan service direstart!"
    sleep 1
    menu_udp_custom
}

# ═══════════════════════════════════════════════════════════════
# ─── UDP LIVE MONITOR ────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════
menu_udp_monitor() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}              UDP LIVE MONITOR                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"

    # ZiVPN status
    local ZPORT=$(jq -r '.listen_port' "$ZIVPN_CFG" 2>/dev/null || echo "5300")
    local ZSTATUS; systemctl is-active --quiet zivpn 2>/dev/null && ZSTATUS="${GREEN}RUNNING${NC}" || ZSTATUS="${RED}STOPPED${NC}"
    local ZCONN=$(ss -u -n 2>/dev/null | grep -c ":$ZPORT " || echo 0)

    # UDP Custom status
    local UCPORT_S=$(jq -r '.listen_port' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7100")
    local UCPORT_E=$(jq -r '.listen_port_end' "$UDPCUSTOM_CFG" 2>/dev/null || echo "7900")
    local UCSTATUS; systemctl is-active --quiet udp-custom 2>/dev/null && UCSTATUS="${GREEN}RUNNING${NC}" || UCSTATUS="${RED}STOPPED${NC}"
    local UCCONN=$(ss -u -n 2>/dev/null | awk -v s="$UCPORT_S" -v e="$UCPORT_E" '{split($5,a,":"); p=a[length(a)]+0; if(p>=s && p<=e) c++} END{print c+0}')

    # BadVPN status
    local BVSTATUS; systemctl is-active --quiet badvpn-udpgw 2>/dev/null && BVSTATUS="${GREEN}RUNNING${NC}" || BVSTATUS="${RED}STOPPED${NC}"
    local BVCONN=$(ss -u -n 2>/dev/null | grep -c ":7300 " || echo 0)

    echo -e "${CYAN}║${NC} ${YELLOW}[UDP ZiVPN]${NC}"
    echo -e "${CYAN}║${NC}   Status  : $(echo -e $ZSTATUS)"
    echo -e "${CYAN}║${NC}   Port    : UDP $ZPORT"
    echo -e "${CYAN}║${NC}   Koneksi : $ZCONN sessions"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}[UDP Custom]${NC}"
    echo -e "${CYAN}║${NC}   Status  : $(echo -e $UCSTATUS)"
    echo -e "${CYAN}║${NC}   Port    : UDP $UCPORT_S - $UCPORT_E"
    echo -e "${CYAN}║${NC}   Koneksi : $UCCONN sessions"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}[BadVPN UdpGW]${NC}"
    echo -e "${CYAN}║${NC}   Status  : $(echo -e $BVSTATUS)"
    echo -e "${CYAN}║${NC}   Port    : UDP 7300"
    echo -e "${CYAN}║${NC}   Koneksi : $BVCONN sessions"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}[Semua UDP Socket Aktif]${NC}"
    ss -u -n 2>/dev/null | grep ESTAB | head -10 | while read -r line; do
        echo -e "${CYAN}║${NC}   $line"
    done
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}[1]${NC} Refresh   ${GREEN}[2]${NC} Start semua UDP   ${GREEN}[3]${NC} Stop semua UDP"
    echo -e "${CYAN}║${NC}  ${RED}[0]${NC} Back"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo -ne "${WHITE}Select: ${NC}"; read -r opt
    case "$opt" in
        1) menu_udp_monitor ;;
        2)
            systemctl start zivpn udp-custom badvpn-udpgw 2>/dev/null
            echo -e "${GREEN}[✔]${NC} Semua UDP service distart"
            sleep 1; menu_udp_monitor ;;
        3)
            systemctl stop zivpn udp-custom badvpn-udpgw 2>/dev/null
            echo -e "${YELLOW}[!]${NC} Semua UDP service distop"
            sleep 1; menu_udp_monitor ;;
        0) main_menu; return ;;
        *) menu_udp_monitor ;;
    esac
}

# ─── STUB MENUS ──────────────────────────────────────────────
menu_ssh()         { clear; echo -e "\n${CYAN}══ SSH MANAGER ══${NC}"; systemctl status ssh --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_dropbear()    { clear; echo -e "\n${CYAN}══ DROPBEAR MANAGER ══${NC}"; systemctl status dropbear --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_ws()          { clear; echo -e "\n${CYAN}══ WEBSOCKET ══${NC}"; systemctl status ws-pro --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_wss()         { clear; echo -e "\n${CYAN}══ WEBSOCKET SSL ══${NC}"; systemctl status ws-pro-ssl --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_stunnel()     { clear; echo -e "\n${CYAN}══ STUNNEL4 ══${NC}"; systemctl status stunnel4 --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_openvpn_tcp() { clear; echo -e "\n${CYAN}══ OPENVPN TCP ══${NC}"; systemctl status openvpn@server --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_openvpn_udp() { clear; echo -e "\n${CYAN}══ OPENVPN UDP ══${NC}"; echo "Konfigurasi UDP silahkan edit /etc/openvpn/server.conf"; echo ""; read -rp "Press Enter..."; main_menu; }
menu_socks5()      { clear; echo -e "\n${CYAN}══ SOCKS5 ══${NC}"; echo "Port 1080 (dante/microsocks)"; echo ""; read -rp "Press Enter..."; main_menu; }
menu_trojan()      { clear; echo -e "\n${CYAN}══ TROJAN ══${NC}"; systemctl status xray --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_slowdns()     { clear; echo -e "\n${CYAN}══ SLOWDNS ══${NC}"; systemctl status slowdns --no-pager 2>/dev/null || echo "SlowDNS tidak aktif"; echo ""; read -rp "Press Enter..."; main_menu; }
menu_squid()       { clear; echo -e "\n${CYAN}══ SQUID PROXY ══${NC}"; systemctl status squid --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_badvpn()      { clear; echo -e "\n${CYAN}══ BADVPN UDPGW ══${NC}"; systemctl status badvpn-udpgw --no-pager; echo ""; read -rp "Press Enter..."; main_menu; }
menu_dns_https()   { clear; echo -e "\n${CYAN}══ DNS OVER HTTPS ══${NC}"; echo "DoH: Gunakan 1.1.1.1 (Cloudflare) atau 8.8.8.8 (Google)"; echo ""; read -rp "Press Enter..."; main_menu; }
menu_ip_limit()    { clear; echo -e "\n${CYAN}══ IP LIMIT MANAGER ══${NC}"; echo "Gunakan menu User Manager > Set IP Limit"; echo ""; read -rp "Press Enter..."; main_menu; }

# ─── FIRST RUN CHECK ─────────────────────────────────────────
first_run_check() {
    if [ ! -f "$PANEL_DIR/.installed" ]; then
        echo -e "\n${YELLOW}╔══════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║   PANEL BELUM DIINSTALL - AUTO INSTALL   ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}\n"
        echo -e "${CYAN}Menjalankan instalasi pertama kali...${NC}\n"
        sleep 1
        auto_install_binaries
        setup_default_iptables
        mkdir -p "$PANEL_DIR" "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR"
        touch "$DB_FILE"
        touch "$PANEL_DIR/.installed"
        echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║     INSTALASI SELESAI! PANEL SIAP ✔      ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}\n"
        sleep 2
    fi
}

# ─── MAIN ENTRY ──────────────────────────────────────────────
main() {
    check_root
    # Handle CLI flags
    case "$1" in
        --install) auto_install_binaries; exit 0 ;;
        --clean-expired) menu_expired_cleaner; exit 0 ;;
        --add-user) add_user; exit 0 ;;
        --list-users) list_users; exit 0 ;;
        --status) menu_sysinfo; exit 0 ;;
    esac
    first_run_check
    while true; do
        main_menu
    done
}

main "$@"
