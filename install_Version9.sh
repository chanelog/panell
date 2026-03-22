#!/bin/bash

################################################################################
# PANELL SSH Panel - All Protocol Support
# Support: VMess, VLESS, Trojan, WebSocket, V2Ray, UDP ZiVPN, UDP Custom
# Author: PANELL
# Date: 2026-03-22
################################################################################

# Color definitions - Elegant Minimal
NC='\033[0m'

# Logging Configuration
LOG_DIR="/var/log/panell"
LOG_FILE="${LOG_DIR}/panel.log"
ERROR_LOG="${LOG_DIR}/error.log"
ACCOUNT_FILE="${LOG_DIR}/accounts.json"
CONFIG_DIR="/etc/panell"
BIN_DIR="/usr/local/panell/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/install.sh"

################################################################################
# LOGGING FUNCTIONS
################################################################################

init_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}" "${ERROR_LOG}" "${ACCOUNT_FILE}"
    chmod 755 "${LOG_DIR}"
    log_info "=== PANELL Panel Started at $(date '+%Y-%m-%d %H:%M:%S') ==="
}

log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [INFO] ${message}" >> "${LOG_FILE}"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [ERROR] ${message}" >> "${ERROR_LOG}"
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [SUCCESS] ${message}" >> "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [WARNING] ${message}" >> "${LOG_FILE}"
}

################################################################################
# VPS INFORMATION & SPECIFICATIONS
################################################################################

get_vps_info() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - VPS INFORMATION & SYSTEM SPECIFICATIONS           │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "VPS Information displayed"
    
    # ===== BASIC SYSTEM INFO =====
    echo "BASIC INFORMATION"
    echo "─────────────────────────────────────────────────────────────"
    
    local hostname=$(hostname)
    local os_name=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f 2)
    local kernel_version=$(uname -r)
    local uptime=$(uptime -p)
    local system_load=$(uptime | awk -F'load average:' '{print $2}')
    
    printf "  Hostname              : %s\n" "$hostname"
    printf "  Operating System      : %s\n" "$os_name"
    printf "  Kernel Version        : %s\n" "$kernel_version"
    printf "  Uptime                : %s\n" "$uptime"
    printf "  System Load           : %s\n" "$system_load"
    
    # ===== CPU SPECIFICATIONS =====
    echo ""
    echo "CPU SPECIFICATIONS"
    echo "─────────────────────────────────────────────────────────────"
    
    local cpu_cores=$(nproc)
    local cpu_model=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f 2 | xargs)
    local cpu_freq=$(grep -m 1 "cpu MHz" /proc/cpuinfo | cut -d ':' -f 2 | xargs | cut -d '.' -f 1)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d 'u' -f 1)
    
    printf "  CPU Model             : %s\n" "$cpu_model"
    printf "  CPU Cores             : %s cores\n" "$cpu_cores"
    printf "  CPU Frequency         : %s MHz\n" "$cpu_freq"
    printf "  CPU Usage             : %s%%\n" "$cpu_usage"
    
    # ===== MEMORY SPECIFICATIONS =====
    echo ""
    echo "MEMORY SPECIFICATIONS"
    echo "─────────────────────────────────────────────────────────────"
    
    local mem_total=$(free -h | grep Mem | awk '{print $2}')
    local mem_used=$(free -h | grep Mem | awk '{print $3}')
    local mem_free=$(free -h | grep Mem | awk '{print $4}')
    local mem_percent=$(free | grep Mem | awk '{printf("%.1f", ($3/$2)*100)}')
    
    printf "  Total RAM             : %s\n" "$mem_total"
    printf "  Used RAM              : %s\n" "$mem_used"
    printf "  Free RAM              : %s\n" "$mem_free"
    printf "  RAM Usage             : %s%%\n" "$mem_percent"
    
    # ===== DISK SPECIFICATIONS =====
    echo ""
    echo "DISK SPECIFICATIONS"
    echo "─────────────────────────────────────────────────────────────"
    
    local disk_total=$(df -h / | awk 'NR==2 {print $2}')
    local disk_used=$(df -h / | awk 'NR==2 {print $3}')
    local disk_free=$(df -h / | awk 'NR==2 {print $4}')
    local disk_percent=$(df / | awk 'NR==2 {print $5}')
    
    printf "  Total Disk            : %s\n" "$disk_total"
    printf "  Used Disk             : %s\n" "$disk_used"
    printf "  Free Disk             : %s\n" "$disk_free"
    printf "  Disk Usage            : %s\n" "$disk_percent"
    
    # ===== NETWORK SPECIFICATIONS =====
    echo ""
    echo "NETWORK SPECIFICATIONS"
    echo "─────────────────────────────────────────────────────────────"
    
    local ipv4=$(hostname -I | awk '{print $1}')
    local ipv6=$(hostname -I | awk '{print NF>1?$NF:"N/A"}')
    local gateway=$(ip route | grep default | awk '{print $3}')
    local dns=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -2 | tr '\n' ',' | sed 's/,$//')
    
    printf "  IPv4 Address          : %s\n" "$ipv4"
    printf "  IPv6 Address          : %s\n" "$ipv6"
    printf "  Gateway               : %s\n" "$gateway"
    printf "  DNS Servers           : %s\n" "$dns"
    
    # ===== SECURITY & FIREWALL =====
    echo ""
    echo "SECURITY & FIREWALL STATUS"
    echo "─────────────────────────────────────────────────────────────"
    
    local firewall_status=$(systemctl is-active ufw 2>/dev/null || echo "Not installed")
    local fail2ban_status=$(systemctl is-active fail2ban 2>/dev/null || echo "Not installed")
    
    printf "  Firewall (UFW)        : %s\n" "$firewall_status"
    printf "  Fail2Ban Status       : %s\n" "$fail2ban_status"
    
    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

################################################################################
# SPEEDTEST FUNCTION
################################################################################

run_speedtest() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - NETWORK SPEED TEST                               │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "Starting speedtest..."
    
    if ! command -v speedtest-cli &> /dev/null; then
        echo "Installing speedtest-cli..."
        pip3 install speedtest-cli > /dev/null 2>&1 || {
            apt-get install -y python3-pip > /dev/null 2>&1 && pip3 install speedtest-cli > /dev/null 2>&1
        }
    fi
    
    if command -v speedtest-cli &> /dev/null; then
        echo "Running speedtest (this may take 1-2 minutes)..."
        echo ""
        
        local result=$(speedtest-cli --simple 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            local download=$(echo "$result" | awk '{print $1}')
            local upload=$(echo "$result" | awk '{print $2}')
            
            echo "Speedtest Completed!"
            echo "─────────────────────────────────────────────────────────────"
            printf "  Download Speed        : %s Mbps\n" "$download"
            printf "  Upload Speed          : %s Mbps\n" "$upload"
            echo "─────────────────────────────────────────────────────────────"
            echo ""
            
            log_success "Speedtest - Download: ${download}Mbps | Upload: ${upload}Mbps"
        else
            echo "Error: Speedtest failed. Please try again later."
            log_error "Speedtest failed"
        fi
    else
        echo "Error: Cannot install speedtest-cli."
        log_error "speedtest-cli installation failed"
    fi
    
    echo ""
}

################################################################################
# ACCOUNT MANAGEMENT FUNCTIONS
################################################################################

add_account() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - ADD NEW ACCOUNT                                   │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    read -p "  Username                : " username
    read -p "  Protocol (vmess/vless/trojan/websocket/udp-zivpn/udp-custom): " protocol
    read -p "  Password/UUID           : " credential
    read -p "  Email                   : " email
    read -p "  Days until expiry       : " days_valid
    
    local expiry_date=$(date -d "+${days_valid} days" '+%Y-%m-%d')
    local account_id=$(date +%s)
    
    cat >> "${ACCOUNT_FILE}" << EOF
{"id": "$account_id", "username": "$username", "protocol": "$protocol", "credential": "$credential", "email": "$email", "created_at": "$(date '+%Y-%m-%d %H:%M:%S')", "expires_at": "$expiry_date", "status": "active"}
EOF
    
    log_success "Account added: $username ($protocol)"
    echo ""
    echo "Account added successfully!"
    echo "─────────────────────────────────────────────────────────────"
    printf "  Username              : %s\n" "$username"
    printf "  Protocol              : %s\n" "$protocol"
    printf "  Email                 : %s\n" "$email"
    printf "  Expires               : %s\n" "$expiry_date"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

list_accounts() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - LIST ALL ACCOUNTS                                 │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    if [ ! -f "${ACCOUNT_FILE}" ] || [ ! -s "${ACCOUNT_FILE}" ]; then
        echo "No accounts found"
        echo ""
        return
    fi
    
    echo "No.  Username            Protocol           Expires"
    echo "─────────────────────────────────────────────────────────────"
    
    local count=1
    local today=$(date '+%Y-%m-%d')
    
    if [ -f "${ACCOUNT_FILE}" ] && [ -s "${ACCOUNT_FILE}" ]; then
        while IFS= read -r line; do
            if [[ $line == *"username"* ]]; then
                local username=$(echo "$line" | grep -o '"username": "[^"]*' | cut -d '"' -f 4)
                local protocol=$(echo "$line" | grep -o '"protocol": "[^"]*' | cut -d '"' -f 4)
                local expires=$(echo "$line" | grep -o '"expires_at": "[^"]*' | cut -d '"' -f 4)
                
                printf "%-4d %-19s %-18s %s\n" "$count" "$username" "$protocol" "$expires"
                ((count++))
            fi
        done < "${ACCOUNT_FILE}"
    fi
    
    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

check_expired_accounts() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - EXPIRED ACCOUNTS CHECK                            │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    local today=$(date '+%Y-%m-%d')
    local expired_count=0
    local expiring_soon_count=0
    local active_count=0
    
    echo "EXPIRED ACCOUNTS"
    echo "─────────────────────────────────────────────────────────────"
    
    if [ -f "${ACCOUNT_FILE}" ] && [ -s "${ACCOUNT_FILE}" ]; then
        while IFS= read -r line; do
            if [[ $line == *"username"* ]]; then
                local username=$(echo "$line" | grep -o '"username": "[^"]*' | cut -d '"' -f 4)
                local expires=$(echo "$line" | grep -o '"expires_at": "[^"]*' | cut -d '"' -f 4)
                
                if [ "$expires" \< "$today" ]; then
                    printf "  ✗ %s (Expired: %s)\n" "$username" "$expires"
                    ((expired_count++))
                fi
            fi
        done < "${ACCOUNT_FILE}"
    fi
    
    if [ $expired_count -eq 0 ]; then
        echo "  No expired accounts"
    fi
    
    echo ""
    echo "EXPIRING SOON (Within 7 days)"
    echo "─────────────────────────────────────────────────────────────"
    
    local expire_limit=$(date -d "+7 days" '+%Y-%m-%d')
    
    if [ -f "${ACCOUNT_FILE}" ] && [ -s "${ACCOUNT_FILE}" ]; then
        while IFS= read -r line; do
            if [[ $line == *"username"* ]]; then
                local username=$(echo "$line" | grep -o '"username": "[^"]*' | cut -d '"' -f 4)
                local expires=$(echo "$line" | grep -o '"expires_at": "[^"]*' | cut -d '"' -f 4)
                
                if [ "$expires" \> "$today" ] && [ "$expires" \< "$expire_limit" ]; then
                    printf "  ⚠ %s (Expires: %s)\n" "$username" "$expires"
                    ((expiring_soon_count++))
                fi
            fi
        done < "${ACCOUNT_FILE}"
    fi
    
    if [ $expiring_soon_count -eq 0 ]; then
        echo "  No accounts expiring soon"
    fi
    
    echo ""
    echo "ACTIVE ACCOUNTS"
    echo "─────────────────────────────────────────────────────────────"
    
    if [ -f "${ACCOUNT_FILE}" ] && [ -s "${ACCOUNT_FILE}" ]; then
        while IFS= read -r line; do
            if [[ $line == *"username"* ]]; then
                local username=$(echo "$line" | grep -o '"username": "[^"]*' | cut -d '"' -f 4)
                local expires=$(echo "$line" | grep -o '"expires_at": "[^"]*' | cut -d '"' -f 4)
                
                if [ "$expires" \> "$expire_limit" ]; then
                    printf "  ✓ %s (Expires: %s)\n" "$username" "$expires"
                    ((active_count++))
                fi
            fi
        done < "${ACCOUNT_FILE}"
    fi
    
    if [ $active_count -eq 0 ]; then
        echo "  No active accounts"
    fi
    
    echo ""
    echo "Summary: $expired_count Expired | $expiring_soon_count Expiring Soon | $active_count Active"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    log_info "Expired check - Expired: $expired_count | Expiring: $expiring_soon_count | Active: $active_count"
}

delete_account() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - DELETE ACCOUNT                                    │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    read -p "  Enter username to delete: " username_to_delete
    
    if [ ! -f "${ACCOUNT_FILE}" ]; then
        echo "No accounts found"
        echo ""
        return
    fi
    
    if grep -q "\"username\": \"$username_to_delete\"" "${ACCOUNT_FILE}"; then
        grep -v "\"username\": \"$username_to_delete\"" "${ACCOUNT_FILE}" > "${ACCOUNT_FILE}.tmp"
        mv "${ACCOUNT_FILE}.tmp" "${ACCOUNT_FILE}"
        
        log_success "Account deleted: $username_to_delete"
        echo ""
        echo "Account deleted successfully!"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
    else
        echo ""
        echo "Error: Account not found!"
        echo "─────────────────────────────────────────────────────────────"
        echo ""
    fi
}

################################################################################
# BINARY INSTALLATION - AUTO INSTALLATION
################################################################################

check_requirements() {
    log_info "Checking system requirements..."
    
    local required_commands=("curl" "wget" "unzip")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_warning "Installing $cmd..."
            apt-get update > /dev/null 2>&1
            apt-get install -y "$cmd" > /dev/null 2>&1
        fi
    done
    
    log_success "All requirements satisfied"
}

install_xray() {
    log_info "Installing Xray-core..."
    
    mkdir -p "${BIN_DIR}"
    
    local latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null | grep tag_name | cut -d '"' -f 4)
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch Xray version"
        echo "  Error: Failed to download Xray"
        return 1
    fi
    
    local download_url="https://github.com/XTLS/Xray-core/releases/download/${latest_version}/Xray-linux-64.zip"
    
    log_info "Latest Xray version: ${latest_version}"
    
    cd "${BIN_DIR}"
    if wget -q "${download_url}" -O xray.zip 2>/dev/null; then
        unzip -o xray.zip > /dev/null 2>&1
        chmod +x xray
        rm -f xray.zip
        log_success "Xray-core installed: ${latest_version}"
        echo "  ✓ Xray-core installed (${latest_version})"
        return 0
    else
        log_error "Failed to download Xray"
        echo "  Error: Failed to download Xray"
        return 1
    fi
}

install_sing_box() {
    log_info "Installing sing-box..."
    
    mkdir -p "${BIN_DIR}"
    
    local latest_version=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>/dev/null | grep tag_name | cut -d '"' -f 4)
    
    if [ -z "$latest_version" ]; then
        log_error "Failed to fetch sing-box version"
        echo "  Error: Failed to download sing-box"
        return 1
    fi
    
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/sing-box-${latest_version#v}-linux-amd64.tar.gz"
    
    log_info "Latest sing-box version: ${latest_version}"
    
    cd "${BIN_DIR}"
    if wget -q "${download_url}" -O sing-box.tar.gz 2>/dev/null; then
        tar -xzf sing-box.tar.gz > /dev/null 2>&1
        chmod +x sing-box*/sing-box 2>/dev/null || true
        mv sing-box*/sing-box . 2>/dev/null || true
        rm -rf sing-box* sing-box.tar.gz
        log_success "sing-box installed: ${latest_version}"
        echo "  ✓ sing-box installed (${latest_version})"
        return 0
    else
        log_error "Failed to download sing-box"
        echo "  Error: Failed to download sing-box"
        return 1
    fi
}

auto_install_binaries() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - AUTO INSTALL BINARIES                             │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "Starting auto binary installation..."
    
    check_requirements
    
    echo ""
    echo "Installing Xray-core (untuk: VMess, VLESS, Trojan, WebSocket)..."
    install_xray
    
    echo ""
    echo "Installing sing-box (untuk: UDP ZiVPN, UDP Custom)..."
    install_sing_box
    
    echo ""
    echo "Installation complete!"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    log_success "Auto binary installation completed"
}

################################################################################
# PROTOCOL CONFIGURATION FUNCTIONS
################################################################################

setup_vmess() {
    log_info "Configuring VMess protocol..."
    mkdir -p "${CONFIG_DIR}/vmess"
    
    cat > "${CONFIG_DIR}/vmess/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10086,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "CHANGE_THIS_UUID",
        "alterId": 0,
        "level": 1,
        "email": "user@example.com"
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "none"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    log_success "VMess config created"
    echo "  ✓ VMess config created (Port: 10086)"
}

setup_vless() {
    log_info "Configuring VLESS protocol..."
    mkdir -p "${CONFIG_DIR}/vless"
    
    cat > "${CONFIG_DIR}/vless/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10087,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "CHANGE_THIS_UUID",
        "level": 1,
        "email": "user@example.com"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "none"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    log_success "VLESS config created"
    echo "  ✓ VLESS config created (Port: 10087)"
}

setup_trojan() {
    log_info "Configuring Trojan protocol..."
    mkdir -p "${CONFIG_DIR}/trojan"
    
    cat > "${CONFIG_DIR}/trojan/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10088,
    "protocol": "trojan",
    "settings": {
      "clients": [{
        "password": "CHANGE_THIS_PASSWORD",
        "level": 1,
        "email": "user@example.com"
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "certificates": [{
          "certificateFile": "/etc/panell/cert/cert.pem",
          "keyFile": "/etc/panell/cert/key.pem"
        }]
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    log_success "Trojan config created"
    echo "  ✓ Trojan config created (Port: 10088)"
}

setup_websocket() {
    log_info "Configuring WebSocket protocol..."
    mkdir -p "${CONFIG_DIR}/websocket"
    
    cat > "${CONFIG_DIR}/websocket/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10089,
    "protocol": "vmess",
    "settings": {
      "clients": [{
        "id": "CHANGE_THIS_UUID",
        "alterId": 0,
        "level": 1,
        "email": "user@example.com"
      }]
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": {
        "path": "/ws",
        "headers": {
          "Host": "example.com"
        }
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    log_success "WebSocket config created"
    echo "  ✓ WebSocket config created (Port: 10089)"
}

setup_udp_zivpn() {
    log_info "Configuring UDP ZiVPN protocol..."
    mkdir -p "${CONFIG_DIR}/udp-zivpn"
    
    cat > "${CONFIG_DIR}/udp-zivpn/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10090,
    "protocol": "shadowsocks",
    "settings": {
      "method": "chacha20-poly1305",
      "password": "CHANGE_THIS_PASSWORD",
      "clients": [{
        "address": "127.0.0.1",
        "port": 10090,
        "level": 1,
        "email": "user@example.com"
      }]
    },
    "streamSettings": {
      "network": "udp"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  }]
}
EOF
    log_success "UDP ZiVPN config created"
    echo "  ✓ UDP ZiVPN config created (Port: 10090)"
}

setup_udp_custom() {
    log_info "Configuring UDP Custom protocol..."
    mkdir -p "${CONFIG_DIR}/udp-custom"
    
    cat > "${CONFIG_DIR}/udp-custom/config.json" << 'EOF'
{
  "inbounds": [{
    "port": 10091,
    "protocol": "dokodemo-door",
    "settings": {
      "network": "udp",
      "followRedirect": false,
      "userLevel": 1
    },
    "streamSettings": {
      "network": "udp"
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIP"
    }
  }]
}
EOF
    log_success "UDP Custom config created"
    echo "  ✓ UDP Custom config created (Port: 10091)"
}

################################################################################
# FIREWALL CONFIGURATION
################################################################################

setup_firewall() {
    log_info "Configuring firewall rules..."
    
    if ! command -v ufw &> /dev/null; then
        log_warning "UFW not installed, installing..."
        apt-get install -y ufw > /dev/null 2>&1
    fi
    
    echo "y" | ufw enable > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    
    local ports=(10086 10087 10088 10089 10090 10091)
    for port in "${ports[@]}"; do
        ufw allow "${port}/tcp" > /dev/null 2>&1
        ufw allow "${port}/udp" > /dev/null 2>&1
        log_info "Firewall rule added for port ${port}"
    done
    
    log_success "Firewall configured successfully"
    echo "Firewall rules configured for all protocol ports"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

create_systemd_service() {
    local protocol=$1
    
    log_info "Creating systemd service for ${protocol}..."
    
    cat > "/etc/systemd/system/panell-${protocol}.service" << EOF
[Unit]
Description=PANELL - ${protocol} Protocol
After=network.target

[Service]
Type=simple
User=root
ExecStart=${BIN_DIR}/xray -c ${CONFIG_DIR}/${protocol}/config.json
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "Systemd service created for ${protocol}"
}

service_status() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - SERVICE STATUS                                    │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    local protocols=("vmess" "vless" "trojan" "websocket" "udp-zivpn" "udp-custom")
    
    echo "Protocol               Status          Port        Binary"
    echo "─────────────────────────────────────────────────────────────"
    
    for protocol in "${protocols[@]}"; do
        local status=$(systemctl is-active "panell-${protocol}" 2>/dev/null || echo "inactive")
        local port=""
        local binary=""
        case $protocol in
            vmess) port="10086"; binary="Xray" ;;
            vless) port="10087"; binary="Xray" ;;
            trojan) port="10088"; binary="Xray" ;;
            websocket) port="10089"; binary="Xray" ;;
            udp-zivpn) port="10090"; binary="sing-box" ;;
            udp-custom) port="10091"; binary="sing-box" ;;
        esac
        
        if [ "$status" = "active" ]; then
            printf "%-22s %-15s %-11s %s\n" "$protocol" "Running" "$port" "$binary"
        else
            printf "%-22s %-15s %-11s %s\n" "$protocol" "Inactive" "$port" "$binary"
        fi
    done
    
    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

start_all_services() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - STARTING ALL SERVICES                             │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "Starting all PANELL services..."
    
    local protocols=("vmess" "vless" "trojan" "websocket" "udp-zivpn" "udp-custom")
    
    for protocol in "${protocols[@]}"; do
        if systemctl start "panell-${protocol}" 2>/dev/null; then
            log_success "${protocol^} service started"
            echo "  ✓ ${protocol} service started"
        else
            log_warning "${protocol^} service not found"
            echo "  ✗ ${protocol} service not found (configure first)"
        fi
    done
    
    echo ""
}

stop_all_services() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - STOPPING ALL SERVICES                             │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "Stopping all PANELL services..."
    
    local protocols=("vmess" "vless" "trojan" "websocket" "udp-zivpn" "udp-custom")
    
    for protocol in "${protocols[@]}"; do
        if systemctl stop "panell-${protocol}" 2>/dev/null; then
            log_success "${protocol^} service stopped"
            echo "  ✓ ${protocol} service stopped"
        fi
    done
    
    echo ""
}

################################################################################
# MAIN MENU - ELEGANT DESIGN
################################################################################

show_main_menu() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - SSH PANEL CONTROL CENTER                          │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    echo "  System Management"
    echo "  ─────────────────────────────────────────────────────────────"
    echo "    [1]   Show VPS Information"
    echo "    [2]   Auto Install Binaries"
    echo "    [3]   Network Speedtest"
    echo ""
    
    echo "  Protocol Configuration"
    echo "  ─────────────────────────────────────────────────────────────"
    echo "    [4]   Configure VMess        (Xray)"
    echo "    [5]   Configure VLESS        (Xray)"
    echo "    [6]   Configure Trojan       (Xray)"
    echo "    [7]   Configure WebSocket    (Xray)"
    echo "    [8]   Configure UDP ZiVPN    (sing-box)"
    echo "    [9]   Configure UDP Custom   (sing-box)"
    echo ""
    
    echo "  Account Management"
    echo "  ─────────────────────────────────────────────────────────────"
    echo "    [10]  Add New Account"
    echo "    [11]  List All Accounts"
    echo "    [12]  Check Expired Accounts"
    echo "    [13]  Delete Account"
    echo ""
    
    echo "  Service Management"
    echo "  ─────────────────────────────────────────────────────────────"
    echo "    [14]  Setup Firewall"
    echo "    [15]  Start All Services"
    echo "    [16]  Stop All Services"
    echo "    [17]  Service Status"
    echo "    [18]  View Logs"
    echo ""
    
    echo "    [0]   Exit"
    echo ""
    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

view_logs() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - VIEW LOGS                                         │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    echo "  [1] Main Log (panell.log)"
    echo "  [2] Error Log (error.log)"
    echo "  [0] Back to Menu"
    echo ""
    
    read -p "  Select log: " log_choice
    
    case $log_choice in
        1)
            clear
            echo "Main Log"
            echo "─────────────────────────────────────────────────────────────"
            echo ""
            tail -f "${LOG_FILE}"
            ;;
        2)
            clear
            echo "Error Log"
            echo "─────────────────────────────────────────────────────────────"
            echo ""
            tail -f "${ERROR_LOG}"
            ;;
    esac
}

################################################################################
# INSTALLATION WIZARD
################################################################################

install_all() {
    clear
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│  PANELL - COMPLETE INSTALLATION WIZARD                      │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    log_info "Starting complete installation..."
    
    check_requirements
    
    echo ""
    echo "Installing Xray-core..."
    install_xray
    
    echo ""
    echo "Installing sing-box..."
    install_sing_box
    
    echo ""
    echo "Creating configuration directories..."
    mkdir -p "${CONFIG_DIR}/cert"
    echo "  ✓ Configuration directories created"
    
    echo ""
    echo "Setting up all protocols..."
    setup_vmess
    setup_vless
    setup_trojan
    setup_websocket
    setup_udp_zivpn
    setup_udp_custom
    echo ""
    
    echo "Creating systemd services..."
    create_systemd_service "vmess"
    create_systemd_service "vless"
    create_systemd_service "trojan"
    create_systemd_service "websocket"
    create_systemd_service "udp-zivpn"
    create_systemd_service "udp-custom"
    echo "  ✓ Systemd services created"
    
    echo ""
    echo "Configuring firewall..."
    setup_firewall
    
    echo ""
    
    # Setup panel command
    setup_panel_command
    
    echo ""
    log_success "Complete installation finished successfully!"
    echo "Installation complete! All protocols ready to use."
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    read -p "  Press Enter to continue..."
}

################################################################################
# PANEL COMMAND SETUP
################################################################################

setup_panel_command() {
    local script_path="$SCRIPT_PATH"
    
    cat > /usr/local/bin/panel << EOF
#!/bin/bash
sudo bash "${script_path}"
EOF
    
    chmod +x /usr/local/bin/panel
    log_success "Panel command installed successfully"
    echo "  ✓ Panel command installed"
    echo "  ✓ You can now type 'panel' to access the control panel"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    init_logging
    
    if [ "$1" = "install" ]; then
        install_all
        exit 0
    fi
    
    while true; do
        show_main_menu
        read -p "  Select option (0-18): " choice
        
        case $choice in
            1) get_vps_info; read -p "  Press Enter to continue..." ;;
            2) auto_install_binaries; read -p "  Press Enter to continue..." ;;
            3) run_speedtest; read -p "  Press Enter to continue..." ;;
            4) clear; setup_vmess; create_systemd_service "vmess"; log_success "VMess configured"; echo ""; read -p "  Press Enter to continue..." ;;
            5) clear; setup_vless; create_systemd_service "vless"; log_success "VLESS configured"; echo ""; read -p "  Press Enter to continue..." ;;
            6) clear; setup_trojan; create_systemd_service "trojan"; log_success "Trojan configured"; echo ""; read -p "  Press Enter to continue..." ;;
            7) clear; setup_websocket; create_systemd_service "websocket"; log_success "WebSocket configured"; echo ""; read -p "  Press Enter to continue..." ;;
            8) clear; setup_udp_zivpn; create_systemd_service "udp-zivpn"; log_success "UDP ZiVPN configured"; echo ""; read -p "  Press Enter to continue..." ;;
            9) clear; setup_udp_custom; create_systemd_service "udp-custom"; log_success "UDP Custom configured"; echo ""; read -p "  Press Enter to continue..." ;;
            10) add_account; read -p "  Press Enter to continue..." ;;
            11) list_accounts; read -p "  Press Enter to continue..." ;;
            12) check_expired_accounts; read -p "  Press Enter to continue..." ;;
            13) delete_account; read -p "  Press Enter to continue..." ;;
            14) clear; setup_firewall; echo ""; read -p "  Press Enter to continue..." ;;
            15) start_all_services; read -p "  Press Enter to continue..." ;;
            16) stop_all_services; read -p "  Press Enter to continue..." ;;
            17) service_status; read -p "  Press Enter to continue..." ;;
            18) view_logs ;;
            0)
                log_info "Panel exited by user"
                clear
                echo "┌─────────────────────────────────────────────────────────────┐"
                echo "│  PANELL - SSH PANEL CONTROL CENTER                          │"
                echo "└─────────────────────────────────────────────────────────────┘"
                echo ""
                echo "Thank you for using PANELL!"
                echo "Type 'panel' anytime to access the control panel"
                echo ""
                exit 0
                ;;
            *)
                echo ""
                echo "  Invalid option"
                echo ""
                sleep 1
                ;;
        esac
    done
}

# Root check
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (sudo)"
    exit 1
fi

main "$@"