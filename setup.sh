
# ===== lib-header.sh =====
#!/bin/bash
# ============================================================
#  JustVPN - all-in-one VPN panel installer
#  Runs on Ubuntu 20.04 / 22.04 / 24.04
#  Custom domain required (no free-domain feature)
# ============================================================
clear
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
stty erase '^?' 2>/dev/null || true
unalias -a 2>/dev/null || true

LOGFILE="/var/log/justvpn-setup.log"
touch "$LOGFILE" 2>/dev/null || LOGFILE="/tmp/justvpn-setup.log"
exec 3>&1
exec 1>>"$LOGFILE" 2>&1

# ---------- palette ----------
OR='\033[1;93m'
CY='\033[1;36m'
BL='\033[1;34m'
GR='\033[1;32m'
RD='\033[1;31m'
YL='\033[1;33m'
MG='\033[1;35m'
WH='\033[1;37m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${BL}──────────────────────────────────────────────${NC}"
    echo -e "${BL}│ ${WH}$1${NC}"
    echo -e "${BL}──────────────────────────────────────────────${NC}"
}

logo() {
    clear >&3
    echo -e "${BL} ╭─────────────────────────────────────────────────╮${NC}" >&3
    echo -e "${BL} │${NC}   ██╗   ██╗██╗   ██╗███╗   ██╗    ${CY}██╗   ██╗${NC} ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}   ██║   ██║██║   ██║████╗  ██║    ${CY}╚██╗ ██╔╝${NC} ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}   ██║   ██║██║   ██║██╔██╗ ██║     ${CY}╚████╔╝${NC} ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}   ██║   ██║╚██╗ ██╔╝██║╚██╗██║      ${CY}╚██╔╝${NC} ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}   ╚██████╔╝ ╚████╔╝ ██║ ╚████║       ${CY}██║${NC} ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}    ╚═════╝   ╚═══╝  ╚═╝  ╚═══╝       ${CY}╚═╝${NC} ${BL}│${NC}" >&3
    echo -e "${BL} ├─────────────────────────────────────────────────┤${NC}" >&3
    echo -e "${BL} │${NC}        ${GR}JustVPN — Premium VPN Panel${NC}         ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}    SSH • OpenVPN • VMess • VLess • Trojan     ${BL}│${NC}" >&3
    echo -e "${BL} │${NC}    Shadowsocks • Socks5 • SlowDNS • gRPC      ${BL}│${NC}" >&3
    echo -e "${BL} ╰─────────────────────────────────────────────────╯${NC}" >&3
    echo "" >&3
}

type_text() {
    local text="$1" delay="$2"
    [ -z "$delay" ] && delay=0.02
    for ((i = 0; i < ${#text}; i++)); do
        echo -n "${text:$i:1}" >&3
        sleep "$delay"
    done
    echo "" >&3
}

banner() {
    logo
    type_text "  JustVPN Panel Installer" 0.02
    sleep 1
}

# ---------- vars ----------
IS_ROOT=$(id -u)
MYIP=$(wget -qO- ipinfo.io/ip 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
CITYGEO=$(wget -qO- ipinfo.io/city 2>/dev/null)
REGION=$(wget -qO- ipinfo.io/region 2>/dev/null)
ISP=$(wget -qO- ipinfo.io/org 2>/dev/null)
ARCH=$(uname -m)
NETIF=$(ip -o -4 route show to default | awk '{print $5}' | head -1)
TIMES="10"

# ---------- root check ----------
is_root() {
    if [ "$IS_ROOT" -ne 0 ]; then
        echo -e "${RD}[ ERROR ]${NC} Please run as root" >&3
        exit 1
    fi
}

# ---------- OS check: Ubuntu 20.04 / 22.04 / 24.04 ----------
check_ubuntu_version() {
    source /etc/os-release
    if [[ ! "$ID" == "ubuntu" ]]; then
        echo -e "${RD}[ ERROR ]${NC} Only Ubuntu is supported (20.04 / 22.04 / 24.04)" >&3
        exit 1
    fi
    case "$VERSION_ID" in
        20.04|22.04|24.04)
            UBUNTU_VER="$VERSION_ID"
            echo -e "${GR}[ OK ]${NC} Ubuntu $UBUNTU_VER detected." >&3
            ;;
        *)
            echo -e "${RD}[ ERROR ]${NC} Unsupported Ubuntu version: $VERSION_ID" >&3
            echo -e "${YL}Supported: Ubuntu 20.04, 22.04, 24.04${NC}" >&3
            read -n 1 -s -r -p "Press any key to continue" >&3
            ;;
    esac
}

# ---------- virtualization check ----------
check_vz() {
    if [ -d /proc/vz ] && [ ! -d /proc/bc ]; then
        echo -e "${RD}[ ERROR ]${NC} OpenVZ/Virtuozzo not supported" >&3
        exit 1
    fi
}

make_folder_xray() {
    mkdir -p /etc/xray
    mkdir -p /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/socks /etc/ssh
    mkdir -p /etc/xray/quota /etc/xray/iplimit /etc/xray/logs
    mkdir -p /etc/funny /etc/mlak
    mkdir -p /etc/slowdns
    mkdir -p /var/log/xray
    mkdir -p /var/www/html
    mkdir -p /usr/bin
}
# ===== lib-deps.sh =====
#!/bin/bash
# ---------- apt dependency install (Ubuntu 20.04 / 22.04 / 24.04) ----------
PKG=(php php-cli php-fpm php-mysql php-xml php-curl libxml-parser-perl
     nginx haproxy dropbear squid openvpn stunnel4 tmux cron bc netfilter-persistent
     vnstat gcc make cmake git jq curl wget openssl zip unzip
     python3 python3-venv python3-pip uuid-runtime coreutils sed gawk
     net-tools tcpdump dnsutils psmisc lsof)

updatePackages() {
    print_step "Updating system packages"
    echo -e "${YL}[ INFO ]${NC} Running apt update ..." >&3
    apt-get update -y >/dev/null 2>&1
    apt-get upgrade -y >/dev/null 2>&1
    apt-get autoremove -y >/dev/null 2>&1
    apt-get clean >/dev/null 2>&1
    for service in dropbear pure-ftpd apache2 nginx; do
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
    done
    echo -e "${GR}[ OK ]${NC} apt base update done" >&3
}

insDepedency() {
    print_step "Installing dependencies"
    for soft in "${PKG[@]}"; do
        if ! dpkg -s "$soft" >/dev/null 2>&1; then
            echo -e "${BL}│ install ${WH}$soft${NC} ..." >&3
            if ! apt-get install -y "$soft" >/dev/null 2>&1; then
                echo -e "${RD}[ ERROR ]${NC} apt install failed for $soft , retry" >&3
                apt-get install -y "$soft" >/dev/null 2>&1
            fi
        fi
    done
    echo -e "${GR}[ OK ]${NC} dependencies installed" >&3
}

install_badvpn() {
    print_step "Building BadVPN (udp-custom gateway)"
    if [ -x /usr/bin/badvpn-udpgw ]; then
        echo -e "${GR}[ OK ]${NC} badvpn-udpgw already present" >&3
        return 0
    fi
    cd /tmp || exit 1
    rm -rf badvpn-build
    git clone --depth 1 https://github.com/ambrop72/badvpn badvpn-build >/dev/null 2>&1
    cd badvpn-build || exit 1
    cmake -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 -DBUILD_TUN2SOCKS=0 \
          -DBUILD_TUNNELTEST=0 -DCMAKE_BUILD_TYPE=Release . >/dev/null 2>&1
    make -j"$(nproc)" >/dev/null 2>&1
    if [ -x udpgw/badvpn-udpgw ]; then
        cp udpgw/badvpn-udpgw /usr/bin/badvpn-udpgw
        chmod +x /usr/bin/badvpn-udpgw
        echo -e "${GR}[ OK ]${NC} badvpn-udpgw built" >&3
    else
        echo -e "${YL}[ WARN ]${NC} badvpn build failed, continuing without udp-custom" >&3
    fi
    cd /tmp && rm -rf badvpn-build
}

badvpn_services() {
    if [ ! -x /usr/bin/badvpn-udpgw ]; then
        echo -e "${YL}[ INFO ]${NC} skipping badvpn services" >&3
        return 0
    fi
    local N
    for P in 7100 7200 7300; do
        case "$P" in
            7100) N=1 ;; 7200) N=2 ;; 7300) N=3 ;;
            *) N=${P:0:1} ;;
        esac
        cat >"/etc/systemd/system/badvpn${N}.service" <<EOF
[Unit]
Description=BadVPN UDPGW $P
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:$P --max-clients 10000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "badvpn${N}.service" >/dev/null 2>&1
        systemctl start "badvpn${N}.service" >/dev/null 2>&1
    done
    echo -e "${GR}[ OK ]${NC} badvpn services (7100/7200/7300) started" >&3
}
# ===== lib-domain.sh =====
#!/bin/bash
# ---------- custom domain prompt (NO free domain feature) ----------
add_domain() {
    print_step "Domain Configuration"
    echo -e "${WH}Please point an A record of your domain to: ${GR}$MYIP${NC}" >&3
    echo -e "${YL}This script does NOT provide a free domain.${NC}" >&3
    echo "" >&3
    while :; do
        echo -ne "${BL}│ ${WH}Input your domain/subdomain : ${NC}" >&3
        IFS= read -r DOMAIN < /dev/tty
        DOMAIN=$(echo "$DOMAIN" | sed 's#^https\?://##' | sed 's#/##' | tr '[:upper:]' '[:lower:]' | xargs)
        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RD}[ ERROR ]${NC} Domain cannot be empty" >&3
        elif [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
            echo -e "${RD}[ ERROR ]${NC} Invalid domain format" >&3
        else
            break
        fi
    done
    echo -e "${GR}[ OK ]${NC} Domain set to: $DOMAIN" >&3
    echo "$DOMAIN" > /etc/xray/domain
}

# ---------- slowdns nameserver (custom, user-managed NS record) ----------
add_dnssub() {
    local SUBD
    while :; do
        echo -ne "${BL}│ ${WH}SlowDNS nameserver${NC} ${YL}(NS record, e.g. ns.$DOMAIN; leave empty to skip slowdns)${NC}: " >&3
        read -r SUBD < /dev/tty
        if [ -z "$SUBD" ]; then
            echo -e "${YL}[ INFO ]${NC} SlowDNS skipped." >&3
            return 0
        fi
        SUBD=$(echo "$SUBD" | tr '[:upper:]' '[:lower:]' | xargs)
        [[ "$SUBD" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] && break
        echo -e "${RD}[ ERROR ]${NC} Invalid NS domain" >&3
    done
    echo "$SUBD" > /etc/xray/dns
    echo -e "${GR}[ OK ]${NC} SlowDNS NS = $SUBD (create an NS record pointing to $MYIP)" >&3
}

# ---------- telegram notification config (optional) ----------
setup_telegram() {
    local TGBOT TGCHAT TGSET
    echo "" >&3
    echo -ne "${BL}│ ${WH}Telegram notification panel (optional)${NC}: ${YL}enable? [y/n]${NC} " >&3
    read -r TGSET < /dev/tty
    if [[ "$TGSET" == "y" || "$TGSET" == "Y" ]]; then
        echo -ne "${BL}│ ${WH}Bot token${NC}: " >&3
        read -r TGBOT < /dev/tty
        echo -ne "${BL}│ ${WH}Chat/Admin ID${NC}: " >&3
        read -r TGCHAT < /dev/tty
        if [[ -n "$TGBOT" && -n "$TGCHAT" ]]; then
            echo "$TGBOT" > /etc/funny/.keybot
            echo "$TGCHAT" > /etc/funny/.chatid
            cat >/etc/mlak/var.txt <<EOF
BOT_TOKEN="$TGBOT"
ADMIN="$TGCHAT"
EOF
            echo -e "${GR}[ OK ]${NC} Telegram notification enabled" >&3
        fi
    fi
}

# ---------- server info files (used by menus) ----------
write_info() {
    mkdir -p /etc/xray /root
    echo "${CITYGEO:-Unknown}" > /etc/xray/city
    echo "${ISP:-Unknown}" > /etc/xray/isp
    echo "${CITYGEO:-Unknown}" > /root/.city
    echo "${REGION:-Unknown}" > /root/.region
    echo "${ISP:-Unknown}" > /root/.isp
    echo -e "${GR}[ INFO ]${NC} server info files written" >&3
}
# ===== lib-xray.sh =====
#!/bin/bash
# ---------- Xray core download + install ----------
install_xray() {
    print_step "Installing Xray-Core"
    local XVER
    XVER=$(curl -s --max-time 30 https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | grep -oE '"tag_name": *"[^"]+"' | head -1 | cut -d'"' -f4)
    [ -z "$XVER" ] && XVER="v26.3.27"
    echo -e "${BL}│ Getting ${WH}$XVER${NC} ..." >&3
    if [ ! -x /usr/local/bin/xray ]; then
        curl -sL --max-time 180 -o /tmp/xray.zip \
            "https://github.com/XTLS/Xray-core/releases/download/${XVER}/Xray-linux-64.zip"
        rm -rf /tmp/xray-core && mkdir -p /tmp/xray-core
        unzip -o -j /tmp/xray-core.zip -d /tmp/xray-core xray geoip.dat geosite.dat >/dev/null 2>&1 \
            || unzip -o -j /tmp/xray.zip -d /tmp/xray-core xray geoip.dat geosite.dat >/dev/null 2>&1
        install -m755 /tmp/xray-core/xray /usr/local/bin/xray
        mkdir -p /usr/local/share/xray
        cp -f /tmp/xray-core/geoip.dat /tmp/xray-core/geosite.dat /usr/local/share/xray/ 2>/dev/null
    fi
    chmod +x /usr/local/bin/xray 2>/dev/null
    echo -e "${GR}[ OK ]${NC} Xray $XVER installed: $(/usr/local/bin/xray version 2>/dev/null | head -1)" >&3
    rm -rf /tmp/xray.zip /tmp/xray-core
}

# ---------- Xray systemd unit ----------
xray_service() {
    cat >/etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/share/xray
Environment=XRAY_LOCATION_ASSET=/usr/local/share/xray
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray.service >/dev/null 2>&1
}

# ---------- Xray config.json (with socks5 inbound added, merged from FN) ----------
xray_config() {
    local UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    cat >/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "error": "/var/log/xray/error.log",
    "access": "/var/log/xray/access.log"
  },
  "api": {
    "services": ["HandlerService", "LoggerService", "StatsService"],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 128,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": "10001",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          { "id": "${UUID}"
#vless
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10002",
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "${UUID}", "alterId": 0
#vmess
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10003",
      "protocol": "trojan",
      "settings": {
        "clients": [
          { "password": "${UUID}"
#trojanws
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10004",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          { "method": "aes-128-gcm", "password": "${UUID}"
#ssws
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/ss-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10005",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          { "id": "${UUID}"
#vlessgrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10006",
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "${UUID}", "alterId": 0
#vmessgrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10007",
      "protocol": "trojan",
      "settings": {
        "clients": [
          { "password": "${UUID}"
#trojangrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "trojan-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10008",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          { "method": "aes-128-gcm", "password": "${UUID}"
#ssgrpc
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "ss-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10009",
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          { "user": "${UUID}", "pass": "${UUID}"
#socksws
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/socks5" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "inboundTag": ["api"], "outboundTag": "direct", "type": "field" },
      { "type": "field", "outboundTag": "blocked", "protocol": ["bittorrent"] },
      { "type": "field", "outboundTag": "blocked", "ip": ["0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "::1/128", "fc00::/7", "fe80::/10"] },
      { "type": "field", "outboundTag": "blocked", "domain": ["geosite:category-ads-all"] },
      { "type": "field", "outboundTag": "direct", "network": "tcp,udp" }
    ]
  },
  "dns": {
    "hosts": {
      "dns.google": "8.8.8.8",
      "dns.pub": "119.29.29.29",
      "dns.alidns.com": "223.5.5.5",
      "geosite:category-ads-all": "127.0.0.1"
    },
    "servers": [
      { "address": "https://1.1.1.1/dns-query", "domains": ["geosite:geolocation-!cn"], "expectIPs": ["geoip:!cn"] },
      "8.8.8.8",
      { "address": "114.114.114.114", "port": 53, "domains": ["geosite:cn", "geosite:category-games@cn"], "expectIPs": ["geoip:cn"], "skipFallback": true },
      { "address": "localhost", "skipFallback": true }
    ]
  }
}
EOF
    chmod 644 /etc/xray/config.json
    echo -e "${GR}[ OK ]${NC} /etc/xray/config.json written (9 inbounds, ws+grpc+socks)" >&3
}
# ===== lib-web.sh =====
#!/bin/bash
# ---------- SSL certificate (acme.sh letsencrypt, self-signed fallback) ----------
issue_cert() {
    print_step "Issuing SSL certificate for $DOMAIN"
    local DOMAIN
    DOMAIN=$(cat /etc/xray/domain)

    # free port 80
    systemctl stop nginx 2>/dev/null; systemctl stop haproxy 2>/dev/null
    systemctl stop apache2 2>/dev/null

    echo -e "${BL}│ installing acme.sh ...${NC}" >&3
    curl -s https://get.acme.sh | sh -s email="admin@$DOMAIN" >/dev/null 2>&1

    echo -e "${BL}│ issuing letsencrypt certificate (standalone) ...${NC}" >&3
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    if ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 \
        --server letsencrypt >/dev/null 2>&1; then
        mkdir -p /etc/xray /etc/nginx/ssl /etc/haproxy
        ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --key-file /etc/xray/xray.key \
            --fullchain-file /etc/xray/xray.crt >/dev/null 2>&1
        echo -e "${GR}[ OK ]${NC} letsencrypt certificate installed" >&3
    else
        echo -e "${YL}[ WARN ]${NC} ACME failed (is the domain pointed here?), using self-signed" >&3
        openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -sha256 \
            -subj "/C=ID/ST=Ok/L=Ok/O=JustVPN/CN=$DOMAIN" \
            -keyout /etc/xray/xray.key -out /etc/xray/xray.crt >/dev/null 2>&1
    fi
    # concat for haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/yha.pem
    chmod 600 /etc/haproxy/yha.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    echo -e "${GR}[ OK ]${NC} yha.pem generated in /etc/haproxy/" >&3
}

# ---------- nginx main config ----------
nginx_conf() {
    cat >/etc/nginx/nginx.conf <<'EOF'
user root;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 16384;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 86400000m;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    types_hash_max_size 2048;
    server_tokens off;

    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
EOF
    rm -f /etc/nginx/sites-enabled/default
    mkdir -p /var/www/html
    echo "<h1 align=center>JustVPN - VPN Panel</h1>" >/var/www/html/index.html
}

# ---------- nginx xray vhost (1010), ovpn (1012), grpc (1013), panel (81) ----------
nginx_vhosts() {
    local DOMAIN
    DOMAIN=$(cat /etc/xray/domain)

    cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 1010 proxy_protocol so_keepalive=on reuseport;
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;
    add_header X-HTTP-LEVEL-HEADER 1;
    add_header X-ANOTHER-HTTP-LEVEL-HEADER 1;
    add_header X-XSS-Protection "1; mode=block";

    location ~ /socks5 {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /socks5 break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10009;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vless {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /vless break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vmess {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /vmess break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /trojan-ws {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /trojan-ws break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /ss-ws {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ss-ws break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ ^/ssh {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ssh break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:22;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ ^/ovpn/ {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ovpn break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10012;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:1194;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ / {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ssh break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:22;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/ovpn.conf <<EOF
server {
    listen 1012 proxy_protocol so_keepalive=on reuseport;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;

    location ~ / {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ovpn break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10012;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:1194;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/grpc.conf <<EOF
server {
    listen 1013 http2 proxy_protocol so_keepalive=on reuseport;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;

    location ~ /vless-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10005;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vmess-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /trojan-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10007;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /ss-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/panel.conf <<EOF
server {
    listen 81 ssl http2 reuseport;
    server_name $DOMAIN;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/html;
    index index.html;
}
EOF
    module_grpc_check
    echo -e "${GR}[ OK ]${NC} nginx vhosts written (1010/1012/1013/81)" >&3
}

# grpc_pass needs ngx_http_v2_module (built-in on Ubuntu nginx) -- ensure loaded
module_grpc_check() {
    nginx -t >/dev/null 2>&1 || true
}

# ---------- nginx systemd enable ----------
nginx_service() {
    systemctl daemon-reload
    systemctl enable nginx >/dev/null 2>&1
}
# ===== lib-haproxy.sh =====
#!/bin/bash
# ---------- HAProxy config (multi-port load balancer) ----------
haproxy_conf() {
    print_step "Configuring HAProxy"
    cat >/etc/haproxy/haproxy.cfg <<'EOF'
# CONFIGURASI LOADBALANCER (JustVPN)
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 1d
    tune.h2.initial-window-size 2147483647
    tune.ssl.default-dh-param 2048

    pidfile /run/haproxy.pid
    chroot /var/lib/haproxy

    user haproxy
    group haproxy
    daemon

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

defaults
    log global
    mode tcp
    option dontlognull
    timeout connect 200ms
    timeout client  300s
    timeout server  300s

frontend multiport
    mode tcp
    bind *:443 tfo
    tcp-request inspect-delay 500ms
    tcp-request content accept if HTTP
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend recir_http if HTTP
    default_backend recir_https

frontend multiports
    mode tcp
    bind abns@haproxy-http accept-proxy tfo
    default_backend recir_https_www

frontend ssl
    mode tcp
    bind *:80 tfo
    bind *:55 tfo
    bind *:8080 tfo
    bind *:2086 tfo
    bind *:8880 tfo
    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo

    tcp-request inspect-delay 500ms
    tcp-request content capture req.ssl_sni len 100
    tcp-request content accept if { req.ssl_hello_type 1 }

    acl chk-02_up hdr(Connection) -i upgrade
    acl chk-02_ws hdr(Upgrade) -i websocket
    acl this_payload payload(0,7) -m bin 5353482d322e30
    acl up-to ssl_fc_alpn -i h2

    use_backend GRUP_FTVPN if up-to
    use_backend FTVPN if chk-02_up chk-02_ws
    use_backend FTVPN if { path_reg -i ^\/(.*) }
    use_backend BOT_FTVPN if this_payload
    default_backend CHANNEL_FTVPN

backend recir_https_www
    mode tcp
    server misssv-bau 127.0.0.1:2223 check

backend FTVPN
    mode http
    server hencet-bau 127.0.0.1:1010 send-proxy check

backend GRUP_FTVPN
    mode tcp
    server hencet-baus 127.0.0.1:1013 send-proxy check

backend CHANNEL_FTVPN
    mode tcp
    balance roundrobin
    server nonok-bau 127.0.0.1:1194 check
    server memek-bau 127.0.0.1:1012 send-proxy check

backend BOT_FTVPN
    mode tcp
    server misv-bau 127.0.0.1:2222 check

backend recir_http
    mode tcp
    server loopback-for-http abns@haproxy-http send-proxy-v2 check

backend recir_https
    mode tcp
    server loopback-for-https abns@haproxy-https send-proxy-v2 check
EOF
    chmod 644 /etc/haproxy/haproxy.cfg
    systemctl daemon-reload
    systemctl enable haproxy >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} haproxy.cfg written (ports 443/80/55/8080/2086/8880)" >&3
}
# ===== lib-services.sh =====
#!/bin/bash
# ---------- SSH config (ports 22/2222/2223) ----------
ssh_config() {
    print_step "Configuring OpenSSH"
    cat >/etc/ssh/sshd_config <<'EOF'
Port 22
Port 2222
Port 2223
Port 53
#AddressFamily any
#ListenAddress 0.0.0.0
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowTcpForwarding yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/banner
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "${GR}[ OK ]${NC} OpenSSH ports 22/2222/2223/53 (53 = JIO5G no payload)" >&3
}

# ---------- Dropbear (143 + 109) ----------
dropbear_config() {
    cat >/etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
    mkdir -p /etc/dropbear
    systemctl daemon-reload
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear 2>/dev/null || true
    echo -e "${GR}[ OK ]${NC} Dropbear ports 143/109" >&3
}

# ---------- Banner (post-login dynamic message is in /etc/profile.d) ----------
write_banner() {
    cat >/etc/banner <<EOF
≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
        JUSTVPN   |   PREMIUM VPN
        $(cat /etc/xray/domain 2>/dev/null)
≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
EOF
    cat >/etc/profile.d/justvpn-motd.sh <<'MOTDEOF'
#!/bin/bash
NC='\033[0m'; CY='\033[1;36m'; WH='\033[1;37m'
if [[ "${SSH_CONNECTION:-}" != "" ]] && [[ -t 1 ]] && [[ "$(whoami)" != "root" ]]; then
    U=$(whoami)
    EXP=""
    LE=$(grep -E "^### ${U} " /etc/ssh/.ssh.db 2>/dev/null | head -1 | awk '{print $3}')
    [ -z "$LE" ] && for F in /etc/vmess/.vmess.db /etc/vless/.vless.db /etc/trojan/.trojan.db /etc/shadowsocks/.shadowsocks.db /etc/socks/.socks.db; do
        LE=$(grep -E "^### ${U} " "$F" 2>/dev/null | head -1 | awk '{print $3}'); [ -n "$LE" ] && break
    done
    if [ -n "$LE" ]; then
        LEFT=$(( ($(date -d "$LE" +%s) - $(date +%s)) / 86400 ))
        [ "$LEFT" -lt 0 ] && LEFT=0
        EXP="${LEFT} days (${LE})"
    else
        EXP="unlimited"
    fi
    Q=$(cat /etc/xray/quota/$U 2>/dev/null)
    [ -z "$Q" ] && Q=0
    if [ "$Q" -gt 0 ]; then
        GB=$(awk "BEGIN{printf \"%.0f\", $Q/1073741824}")
        [ "$GB" -ge 1000 ] && BWD="$(awk "BEGIN{printf \"%.1f\", $GB/1000}")T" || BWD="${GB}Gb"
    else
        BWD="Unlimited"
    fi
    DOM=$(cat /etc/xray/domain 2>/dev/null)
    echo -e "${CY}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${WH}│${NC} ${CY}JustVPN${NC} ${WH}›${NC} ${YL}PREMIUM VPN${NC}              ${WH}│${NC}"
    echo -e "${WH}├──────────────────────────────────────────────┤${NC}"
    echo -e "${CY} Logins:      ${WH}1/100${NC}"
    echo -e "${CY} Expire in:   ${WH}${EXP}${NC}"
    echo -e "${CY} Username:    ${WH}${U}${NC}"
    echo -e "${CY} Bandwidth:   ${WH}${BWD}${NC}"
    echo -e "${WH}├──────────────────────────────────────────────┤${NC}"
    echo -e "                ${CY}script.$DOM${NC}"
    echo -e "${CY}└──────────────────────────────────────────────┘${NC}"
fi
MOTDEOF
    chmod +x /etc/profile.d/justvpn-motd.sh 2>/dev/null
}

# ---------- Squid proxy (3128) ----------
squid_config() {
    local MYIP
    MYIP=$(wget -qO- ipinfo.io/ip 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    cat >/etc/squid/squid.conf <<EOF
# Squid Configuration - JustVPN
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 1-65535
acl Safe_ports port 1-65535
acl CONNECT method CONNECT
acl SSH dst $MYIP
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost
http_access deny all
http_port 3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname $(cat /etc/xray/domain)
EOF
    systemctl daemon-reload
    systemctl enable squid >/dev/null 2>&1
    systemctl restart squid 2>/dev/null || true
    echo -e "${GR}[ OK ]${NC} Squid proxy port 3128" >&3
}

# ---------- Python3 SSH/OVPN websocket proxy ----------
write_ws_py() {
    cat >/usr/bin/ws.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 10015
DEFAULT_HOST = sys.argv[2] if len(sys.argv) > 2 else '127.0.0.1:22'
PASS = ''
BUFLEN = 4096 * 4
TIMEOUT = 60
RESPONSE = b'HTTP/1.1 101 Switching Protocol\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: foo\r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        with self.logLock:
            print(log, flush=True)

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)

    def removeConn(self, conn):
        with self.threadsLock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threadsLock:
            threads = list(self.threads)
            for c in threads:
                c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = b''
        self.server = server

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except Exception:
            pass
        finally:
            self.clientClosed = True
        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except Exception:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            if hostPort == '':
                hostPort = DEFAULT_HOST
            split = self.findHeader(self.client_buffer, 'X-Split')
            if split != '':
                self.client.recv(BUFLEN)
            if hostPort != '':
                passwd = self.findHeader(self.client_buffer, 'X-Pass')
                if len(PASS) != 0 and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith('127.0.0.1') or hostPort.startswith('localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            msg = getattr(e, 'strerror', None) or str(e)
            self.server.printLog('- error: ' + msg)
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(header.encode('utf-8') + b': ')
        if aux == -1:
            return ''
        aux = head.find(b':', aux)
        head = head[aux + 2:]
        aux = head.find(b'\r\n')
        if aux == -1:
            return ''
        try:
            return head[:aux].decode('utf-8')
        except Exception:
            return ''

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i + 1:])
            host = host[:i]
        else:
            port = 22
        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]
        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.connect_target(path)
        self.client.sendall(RESPONSE)
        self.client_buffer = b''
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            break
                    except Exception:
                        error = True
                        break
            if count == TIMEOUT:
                error = True
            if error:
                break

if __name__ == '__main__':
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    while True:
        time.sleep(2)
PYEOF
    chmod +x /usr/bin/ws.py
}

ws_services() {
    cat >/etc/systemd/system/ws.service <<'EOF'
[Unit]
Description=SSH Websocket (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/bin/ws.py 10015 127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    cat >/etc/systemd/system/wsovpn.service <<'EOF'
[Unit]
Description=OpenVPN Websocket (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/bin/ws.py 10012 127.0.0.1:1194
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ws.service >/dev/null 2>&1
    systemctl enable wsovpn.service >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} WS python3 services (10015 ssh / 10012 ovpn)" >&3
}

# ---------- tun.conf (informational) ----------
write_tunconf() {
    cat >/etc/slowdns/tun.conf <<EOF
# verbose level 0=info, 1=verbose, 2=very verbose
verbose: 0
listen:

# // SSH
- target_host: 127.0.0.1
  target_port: 22
  listen_port: 10015

# // OpenVPN
- target_host: 127.0.0.1
  target_port: 1194
  listen_port: 10012
EOF
}

# ---------- OpenVPN (TCP 1194 / UDP 2200) with generated CA ----------
openvpn_setup() {
    print_step "Setting up OpenVPN"
    local DOMAIN PLUGIN
    DOMAIN=$(cat /etc/xray/domain)
    PLUGIN=$(ls /usr/lib/*/openvpn/plugins/openvpn-plugin-auth-pam.so 2>/dev/null | head -1)
    [ -z "$PLUGIN" ] && PLUGIN="/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"

    mkdir -p /etc/openvpn /var/www/html
    # self-contained CA (no external downloads)
    if [ ! -f /etc/openvpn/ca.crt ]; then
        openssl genrsa -out /etc/openvpn/ca.key 2048 >/dev/null 2>&1
        openssl req -x509 -new -key /etc/openvpn/ca.key -days 3650 -sha256 \
            -subj "/C=ID/ST=JustVPN/L=JustVPN/O=JustVPN/CN=JustVPN-CA" \
            -out /etc/openvpn/ca.crt >/dev/null 2>&1
        openssl genrsa -out /etc/openvpn/server.key 2048 >/dev/null 2>&1
        openssl req -new -key /etc/openvpn/server.key \
            -subj "/CN=$DOMAIN" -out /etc/openvpn/server.csr >/dev/null 2>&1
        openssl x509 -req -in /etc/openvpn/server.csr -CA /etc/openvpn/ca.crt \
            -CAkey /etc/openvpn/ca.key -CAcreateserial -days 3650 -sha256 \
            -out /etc/openvpn/server.crt >/dev/null 2>&1
        openssl dhparam -out /etc/openvpn/dh.pem 2048 2>/dev/null &
        dhpw=$!
        sleep 1
        wait $dhpw 2>/dev/null
    fi

    cat >/etc/openvpn/server-tcp.conf <<EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
verify-client-cert none
username-as-common-name
plugin $PLUGIN login
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "route-method exe"
push "route-delay 2"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
management 127.0.0.1 5555
status server-tcp.log
log log-tcp.log
verb 3
cipher none
auth none
EOF

    cat >/etc/openvpn/server-udp.conf <<EOF
port 2200
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
verify-client-cert none
username-as-common-name
plugin $PLUGIN login
server 20.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "route-method exe"
push "route-delay 2"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status server-udp.log
log log-udp.log
verb 3
cipher none
auth none
EOF

    for V in tcp udp ssl ws-ssl; do
        case $V in
            tcp) PORT=1194; PROTO=tcp; EXTRA="" ;;
            udp) PORT=2200; PROTO=udp; EXTRA="" ;;
            ssl) PORT=443;  PROTO=tcp; EXTRA="" ;;
            ws-ssl) PORT=443; PROTO=tcp; EXTRA="socks" ;;
        esac
        cat >/etc/openvpn/$V.ovpn <<EOF
auth-user-pass
client
dev tun
proto $PROTO
remote $DOMAIN $PORT
persist-key
persist-tun
pull
resolv-retry infinite
nobind
user nobody
comp-lzo
remote-cert-tls server
verb 3
mute 2
connect-retry 5 5
connect-retry-max 8080
mute-replay-warnings
redirect-gateway def1
script-security 2
cipher none
auth none
EOF
        if [ "$V" = "ws-ssl" ]; then
            sed -i '/proto tcp/a http-proxy 127.0.0.1 80\nhttp-proxy-retry\n# ws tunnel: route via https port 443 using websocket' /etc/openvpn/$V.ovpn
        fi
        echo "<ca>" >>/etc/openvpn/$V.ovpn
        cat /etc/openvpn/ca.crt >>/etc/openvpn/$V.ovpn
        echo "</ca>" >>/etc/openvpn/$V.ovpn
        cp /etc/openvpn/$V.ovpn /var/www/html/$V.ovpn
    done
    cd /var/www/html && zip -q all-ovpn.zip tcp.ovpn udp.ovpn ssl.ovpn ws-ssl.ovpn 2>/dev/null; cd /
    sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/' /etc/default/openvpn
    systemctl daemon-reload
    systemctl enable openvpn@server-tcp >/dev/null 2>&1
    systemctl enable openvpn@server-udp >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} OpenVPN TCP 1194 / UDP 2200 (certs generated locally)" >&3
}

# ---------- BBR + sysctl ----------
bbrypt() {
    print_step "Enabling BBR + system tuning"
    cat >/etc/sysctl.conf <<EOF
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
fs.file-max=65535000
fs.inotify.max_user_instances=8192
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.somaxconn=65535
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 87380 134217728
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_max_syn_backlog=10240
net.core.netdev_max_backlog=10240
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_mtu_probing=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
    sysctl -p >/dev/null 2>&1
    sysctl --system >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} BBR + tuning applied" >&3
}

# ---------- rc-local ----------
rc_local() {
    cat >/etc/rc.local <<EOF
#!/bin/bash
# JustVPN rc.local
exit 0
EOF
    chmod +x /etc/rc.local
    cat >/etc/systemd/system/rc-local.service <<'EOF'
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable rc-local >/dev/null 2>&1
    systemctl start rc-local 2>/dev/null || true
}

# ---------- iptables (server ports + torrent drop + dns redirect) ----------
iptables_rules() {
    print_step "Writing iptables rules"
    local IFACE
    IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    [ -z "$IFACE" ] && IFACE="eth0"
    mkdir -p /etc/iptables
    cat >/etc/iptables/rules.v4 <<END
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -p tcp -m tcp --dport 10015 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10012 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10011 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10009 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10008 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10007 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10006 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10005 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10004 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10003 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10002 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10001 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10000 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 3128 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 1194 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 222 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 777 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2223 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2222 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 109 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 169 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 88 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 81 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 55 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2086 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8880 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 68 -j ACCEPT
-A INPUT -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --dport 2200 -j ACCEPT
-A INPUT -p udp -m udp --dport 2100 -j ACCEPT
-A INPUT -p udp -m udp --dport 5300 -j ACCEPT
-A INPUT -p udp -m udp --dport 7100 -j ACCEPT
-A INPUT -p udp -m udp --dport 7200 -j ACCEPT
-A INPUT -p udp -m udp --dport 7300 -j ACCEPT
-A FORWARD -m string --string "BitTorrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "BitTorrent protocol" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "peer_id=" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string ".torrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "announce.php?passkey=" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "torrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "announce" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "info_hash" --algo bm --to 65535 -j DROP
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A PREROUTING -i $IFACE -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
-A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE
-A POSTROUTING -s 20.8.0.0/24 -o $IFACE -j MASQUERADE
COMMIT
END
    cat >/etc/iptables/rules.v6 <<'END'
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
END
    systemctl enable netfilter-persistent >/dev/null 2>&1
    netfilter-persistent reload >/dev/null 2>&1 || iptables-restore < /etc/iptables/rules.v4 2>/dev/null
    echo -e "${GR}[ OK ]${NC} iptables rules applied" >&3
}
# ===== lib-slowdns.sh =====
#!/bin/bash
# ---------- SlowDNS (dnstt) install ----------
slowdns_setup() {
    local NSDOMAIN
    if [ ! -f /etc/xray/dns ]; then
        echo -e "${YL}[ INFO ]${NC} SlowDNS nameserver not set, skipping" >&3
        return 0
    fi
    NSDOMAIN=$(cat /etc/xray/dns)
    print_step "Setting up SlowDNS (dnstt) NS=$NSDOMAIN"
    if [ ! -x /etc/slowdns/dnstt-server ]; then
        mkdir -p /etc/slowdns /tmp/dnstt_build
        for B in dnstt-server dnstt-client; do
            if ! curl -sL --max-time 120 -o "/tmp/dnstt_build/$B" \
                "https://dnstt.network/$B-linux-amd64"; then
                echo -e "${RD}[ ERROR ]${NC} failed downloading $B" >&3
                return 1
            fi
        done
        chmod +x /tmp/dnstt_build/dnstt-server /tmp/dnstt_build/dnstt-client
        mv /tmp/dnstt_build/dnstt-server /tmp/dnstt_build/dnstt-client /etc/slowdns/
        rm -rf /tmp/dnstt_build
        if [ ! -f /etc/slowdns/server.pub ]; then
            (cd /etc/slowdns && ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub >/dev/null 2>&1)
        fi
    fi

    cat >/etc/systemd/system/server.service <<EOF
[Unit]
Description=DNSTT Server (SlowDNS - JustVPN)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key $NSDOMAIN 127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    cat >/etc/systemd/system/client.service <<EOF
[Unit]
Description=DNSTT Client (SlowDNS - JustVPN)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/dnstt-client -udp 8.8.8.8:53 -pubkey-file /etc/slowdns/server.pub $NSDOMAIN 127.0.0.1:8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable server.service >/dev/null 2>&1
    systemctl enable client.service >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} SlowDNS services ready (public key in /etc/slowdns/server.pub)" >&3
}
# ===== lib-accs-a.sh =====
#!/bin/bash
# ---------- shared lib /usr/bin/xvn (sourced by all JustVPN menus) ----------
install_xvn() {
    cat >/usr/bin/xvn <<'XVNEOF'
#!/bin/bash
# ================================================
#  JustVPN shared library (UI + core helpers)
# ================================================
NC='\033[0m'; Green="\e[92;1m"; RED="\033[1;31m"; OR='\033[1;93m'
CY='\033[1;36m'; BL='\033[1;34m'; YL='\033[1;33m'; MG='\033[1;35m'; WH='\033[1;37m'
LB='\033[104m'; BW='\033[97m'
LBX='\033[104m\033[1;37m'
LBD='\033[100m\033[1;37m'

# ---- premium unified UI helpers -----------------------------------
# All screens share this visual language:
#   a light-blue rounded panel with a centered title, then
#   cyan-bordered content rows, and a magenta section divider.
xv_top()    { echo -e "${CY}╭────────────────────────────────────────────╮${NC}"; }
xv_mid()    { echo -e "${CY}├────────────────────────────────────────────┤${NC}"; }
xv_bot()    { echo -e "${CY}╰────────────────────────────────────────────╯${NC}"; }
xv_edg()    { echo -ne "${CY}│${NC} "; }
xv_hline()  { echo -e "${CY}──────────────────────────────────────────────${NC}"; }
xv_line()   { echo -e "${CY}──────────────────────────────────────────────${NC}"; }

# Panel with a bold title bar (light-blue bg, white bold text)
xv_title()  {
    local t="$1" n=${#t} w=40 pad
    pad=$(( (w - n) / 2 ))
    printf -v padl '%*s' "$pad" ''
    echo -e "${LBX}╭${padl} $t ${padl}╮${NC}"
}
# Section divider with label
xv_sect()   { echo -e "${MG}━━━━━  $1  ━━━━━${NC}"; }
# Menu item helper: prints "  [N]  label" in a cyan box row
xv_item()   { echo -e "  ${YL}[$1]${NC}  $2"; }

DOM=$(cat /etc/xray/domain 2>/dev/null)
NS=$(cat /etc/xray/dns 2>/dev/null)
PUB=$(cat /etc/slowdns/server.pub 2>/dev/null)
MYIP=$(wget -qO- ipinfo.io/ip 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
ISP=$(cat /root/.isp 2>/dev/null); CITY=$(cat /root/.city 2>/dev/null); REGION=$(cat /root/.region 2>/dev/null)
MODEL=$(grep -w PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//;s/"//g')

KEY=$(cat /etc/funny/.keybot 2>/dev/null)
CHATID=$(cat /etc/funny/.chatid 2>/dev/null)

send_telegram() {
    local msg="$1"
    [ -z "$KEY" ] && [ -f /etc/mlak/var.txt ] && source /etc/mlak/var.txt && KEY="$BOT_TOKEN" && CHATID="$ADMIN"
    [ -z "$KEY" ] && return 1
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${KEY}/sendMessage" \
        -d chat_id="${CHATID}" -d text="${msg}" -d parse_mode="HTML" >/dev/null 2>&1
}

xv_db()   { echo "/etc/${1}/.${1}.db"; }

marker_pfx() { echo '###'; }

marker_lines() {
    case "$1" in
        vmess) echo '#vmess #vmessgrpc' ;;
        vless) echo '#vless #vlessgrpc' ;;
        trojan) echo '#trojanws #trojangrpc' ;;
        shadowsocks) echo '#ssws #ssgrpc' ;;
        socks) echo '#socksws' ;;
    esac
}

gen_id() { echo "$(cat /proc/sys/kernel/random/uuid)"; }
gen_pass() { echo "$(tr </dev/urandom -dc a-zA-Z0-9 | head -c9)"; }

exp_date() { echo "$(date -d "$1 days" +%Y-%m-%d)"; }

restart_xray() {
    systemctl daemon-reload 2>/dev/null
    systemctl restart xray 2>/dev/null
}

xv_input_user() {
    local RE
    RE='^[a-zA-Z0-9_]+$'
    USER=""
    while :; do
        read -rp "  Username : " U
        U=$(echo "$U" | xargs)
        if [[ -z "$U" ]]; then continue; fi
        if [[ ! "$U" =~ $RE ]]; then echo "  Invalid username (a-zA-Z0-9_)"; continue; fi
        if grep -qw "$U" /etc/xray/config.json 2>/dev/null; then
            echo "  Username already exists"; continue
        fi
        USER="$U"; break
    done
}

xv_input_days() {
    DAYS=""
    while :; do
        read -rp "  Expired (days) : " D
        [[ "$D" =~ ^[0-9]+$ ]] && [ "$D" -ge 1 ] && DAYS="$D" && break
        echo "  Invalid days"
    done
    EXP=$(exp_date "$DAYS")
}

xv_quota_ask() {
    read -rp "  Limit Quota (GB, 0=unlimited) : " Q
    Q=$(echo "$Q" | sed 's/[^0-9]*//g'); [ -z "$Q" ] && Q=0
    if [ "$Q" -gt 0 ]; then
        bc_file=/etc/xray/quota/${USER}
        echo "$((Q * 1024 * 1024 * 1024))" > "$bc_file"
    else
        rm -f /etc/xray/quota/${USER}
    fi
}

xv_iplim_ask() {
    read -rp "  Limit IP (0=unlimited)        : " IL
    IL=$(echo "$IL" | sed 's/[^0-9]*//g'); [ -z "$IL" ] && IL=0
    if [ "$IL" -gt 0 ]; then
        echo "$IL" > /etc/xray/iplimit/${USER}
    else
        rm -f /etc/xray/iplimit/${USER}
    fi
}

# account already stored in $USER $EXP; ID set by caller
xv_sed_add() {
    local PROTO="$1" ID="$2" PASS="$3" M BLK
    case "$PROTO" in
        vmess) BLK='},{"id": "'"$ID"'", "alterId": 0, "email": "'"$USER"'"';;
        vless) BLK='},{"id": "'"$ID"'", "email": "'"$USER"'"';;
        trojan) BLK='},{"password": "'"$ID"'", "email": "'"$USER"'"';;
        shadowsocks) BLK='},{"method": "aes-128-gcm", "password": "'"$ID"'", "email": "'"$USER"'"';;
        socks) BLK='},{"user": "'"$USER"'", "pass": "'"$PASS"'", "email": "'"$USER"'"';;
    esac
    for M in $(marker_lines "$PROTO"); do
        sed -i "/^$M\$/a ### $USER $EXP\n$BLK" /etc/xray/config.json
    done
}

xv_db_add() {
    local PROTO="$1" ID="$2"
    echo "### $USER $EXP $ID" >> "$(xv_db "$PROTO")"
}

xv_remove() {
    local PROTO="$1" U="$2" PFX
    PFX=$(marker_pfx "$PROTO")
    sed -i "/^${PFX} ${U} /,/^},{/d" /etc/xray/config.json
    sed -i "/^### ${U} /d" "$(xv_db "$PROTO")"
    rm -f "/etc/xray/quota/${U}" "/etc/xray/iplimit/${U}" \
        "/etc/xray/log-create-${U}.log" "/var/www/html/log-create-${U}.log"
    restart_xray
}

xv_usage() { # xray api total bytes for email
    local U="$1"
    local D V
    D=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10000 \
        -pattern "user>>>${U}>>>traffic>>>downlink" 2>/dev/null \
        | grep -oE 'value="[0-9]+"' | grep -oE '[0-9]+')
    V=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10000 \
        -pattern "user>>>${U}>>>traffic>>>uplink" 2>/dev/null \
        | grep -oE 'value="[0-9]+"' | grep -oE '[0-9]+')
    echo "$(( (${D:-0} + ${V:-0}) ))"
}

fmt_size() { # bytes -> human
    local B="$1"
    if   [ "$B" -ge 1099511627776 ]; then awk "BEGIN{printf \"%.2f TB\", $B/1099511627776}"
    elif [ "$B" -ge 1073741824 ]; then awk "BEGIN{printf \"%.2f GB\", $B/1073741824}"
    elif [ "$B" -ge 1048576 ]; then awk "BEGIN{printf \"%.2f MB\", $B/1048576}"
    elif [ "$B" -ge 1024 ]; then awk "BEGIN{printf \"%.2f KB\", $B/1024}"
    else echo "${B} B"; fi
}

active_ips() { # count distinct ip (/24) of a user seen in last 45s (access.log)
    local U="$1" now ips line ts ip
    now=$(date +%s)
    ips=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        ts=$(echo "$line" | grep -oE '^[0-9]{4}/[0-9]{2}/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | \
            { read d t; date -d "$d $t" +%s; })
        [ -z "$ts" ] && continue
        diff=$(( now - ts ))
        [ "$diff" -ge 0 ] && [ "$diff" -lt 45 ] || continue
        ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sed -n '1p')
        [ -z "$ip" ] && continue
        ip3=$(echo "$ip" | cut -d. -f1-3)
        case " $ips " in
            *" $ip3 "*) ;;
            *) ips="$ips $ip3" ;;
        esac
    done < <(tail -n 800 /var/log/xray/access.log 2>/dev/null | grep -F "email: ${U}")
    [ -n "$ips" ] && echo "$ips" | wc -w || echo 0
}

# ---------- add xray proto ----------
xv_add() {
    local PROTO="$1" ID PASS PASS2 STXT
    local EX CLIENT_EXISTS
    clear
    xv_title "Add $(echo "vmess vless trojan shadowsocks socks" | grep -oE "^$PROTO| $PROTO") Account"
    echo ""
    xv_input_user
    xv_input_days
    xv_quota_ask
    xv_iplim_ask
    ID=$(gen_id)
    if [ "$PROTO" = "socks" ]; then
        PASS=$(gen_pass)
        read -rp "  Socks Password [${PASS}] : " PASS2
        [ -n "$PASS2" ] && PASS="$PASS2"
    fi
    xv_sed_add "$PROTO" "$ID" "$PASS"
    xv_db_add "$PROTO" "$ID"
    restart_xray
    clear
    xv_result "$PROTO" "$ID" "$PASS"
    send_telegram "JustVPN : New $(uc "$PROTO") account ${USER} expired ${EXP}"
}

xv_result() {
    local PROTO="$1" ID="$2" PASS="$3" L
    local b64 link1 link2 link3
    case "$PROTO" in
        vmess)
            L="/vmess"
            b64=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"tls"}' "$USER" "$DOM" "$ID" "$DOM" | base64 -w 0)
            link1="vmess://$b64"
            b64=$(printf '{"v":"2","ps":"%s","add":"%s","port":"80","id":"%s","aid":"0","net":"ws","path":"/vmess","type":"none","host":"%s","tls":"none"}' "$USER" "$DOM" "$ID" "$DOM" | base64 -w 0)
            link2="vmess://$b64"
            b64=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","net":"grpc","path":"vmess-grpc","type":"none","host":"%s","tls":"tls"}' "$USER" "$DOM" "$ID" "$DOM" | base64 -w 0)
            link3="vmess://$b64"
            ;;
        vless)
            link1="vless://${ID}@${DOM}:443?encryption=none&security=tls&sni=${DOM}&type=ws&host=${DOM}&path=%2Fvless#${USER}"
            link2="vless://${ID}@${DOM}:80?encryption=none&security=none&type=ws&host=${DOM}&path=%2Fvless#${USER}"
            link3="vless://${ID}@${DOM}:443?encryption=none&security=tls&sni=${DOM}&type=grpc&serviceName=vless-grpc#${USER}"
            ;;
        trojan)
            link1="trojan://${ID}@${DOM}:443?security=tls&sni=${DOM}&type=ws&host=${DOM}&path=%2Ftrojan-ws#${USER}"
            link2="trojan://${ID}@${DOM}:80?security=none&type=ws&host=${DOM}&path=%2Ftrojan-ws#${USER}"
            link3="trojan://${ID}@${DOM}:443?security=tls&sni=${DOM}&type=grpc&serviceName=trojan-grpc#${USER}"
            ;;
        shadowsocks)
            b64=$(printf 'aes-128-gcm:%s' "$ID" | base64 -w 0)
            link1="ss://${b64}@${DOM}:443?type=ws&path=%2Fss-ws&security=tls&host=${DOM}#${USER}"
            link2="ss://${b64}@${DOM}:80?type=ws&path=%2Fss-ws&security=none&host=${DOM}#${USER}"
            link3="ss://${b64}@${DOM}:443?type=grpc&security=tls&serviceName=ss-grpc#${USER}"
            ;;
        socks)
            b64=$(printf '%s:%s' "$USER" "$PASS" | base64 -w 0)
            link1="socks://${b64}@${DOM}:443?path=%2Fsocks5&security=tls&type=ws&host=${DOM}&sni=${DOM}#${USER}"
            link2="socks://${b64}@${DOM}:80?path=%2Fsocks5&security=none&type=ws&host=${DOM}#${USER}"
            ;;
    esac
    echo -e "${LBX}╭────────────── $(uc "$PROTO") Account ──────────────╮${NC}"
    echo -e "${LBX}│${NC}   Account created successfully ✓             "
    echo -e "${LBX}╰────────────────────────────────────────────────╯${NC}"
    echo ""
    if [ "$PROTO" = "socks" ]; then
        echo -e "  Username   : ${CY}${USER}${NC}"
        echo -e "  Password   : ${CY}${PASS}${NC}"
    else
        echo -e "  User ID    : ${CY}${ID}${NC}"
    fi
    echo -e "  Domain     : ${CY}${DOM}${NC}"
    echo -e "  Port TLS   : 443    Port NTLS : 80, 55, 8080, 2086, 8880"
    echo -e "  Network    : WS / gRPC"
    echo -e "  Path WS    : /vmess /vless /trojan-ws /ss-ws /socks5"
    echo -e "  Expired    : ${RED}${EXP}${NC}"
    echo -e "${MG}──────────────────────────────────────────────${NC}"
    [ -n "$link1" ] && { echo -e "  ${YL}Link TLS ${NC}"; echo -e "  ${CY}$link1${NC}"; echo -e "${MG}──────────────────────────────────────────────${NC}"; }
    [ -n "$link2" ] && { echo -e "  ${YL}Link NTLS${NC}"; echo -e "  ${CY}$link2${NC}"; echo -e "${MG}──────────────────────────────────────────────${NC}"; }
    [ -n "$link3" ] && { echo -e "  ${YL}Link gRPC${NC}"; echo -e "  ${CY}$link3${NC}"; echo -e "${MG}──────────────────────────────────────────────${NC}"; }
    [ -n "$NS" ] && echo -e "  DNSTT NS  : ${CY}$NS${NC} port 53 | PubKey : ${NC}$PUB"
    {
        echo "=== JustVPN $(uc "$PROTO") Account ==="
        echo "Username : $USER"
        if [ "$PROTO" = "socks" ]; then echo "Password : $PASS"; else echo "User ID  : $ID"; fi
        echo "Domain   : $DOM"
        echo "Expired  : $EXP"
        [ -n "$link1" ] && echo "TLS  : $link1"
        [ -n "$link2" ] && echo "NTLS : $link2"
        [ -n "$link3" ] && echo "gRPC : $link3"
    } > "/var/www/html/justvpn-${USER}.txt"
    echo -e "  Text file : ${CY}https://${DOM}:81/justvpn-${USER}.txt${NC}"
    echo ""
}

# ---------- trial ----------
xv_trial() {
    local PROTO="$1" ID PASS
    USER="trial$(date +%H%M%S)"
    DAYS=1; EXP=$(exp_date 1)
    ID=$(gen_id)
    PASS=$(gen_pass)
    rm -f /etc/xray/quota/${USER} /etc/xray/iplimit/${USER}
    xv_sed_add "$PROTO" "$ID" "$PASS"
    xv_db_add "$PROTO" "$ID"
    restart_xray
    clear
    xv_result "$PROTO" "$ID" "$PASS"
}

# ---------- delete xray proto ----------
xv_del() {
    local PROTO="$1" U
    clear
    xv_title "Delete $(uc "$PROTO") Account"
    echo ""
    local list; list=$(grep "^###" "$(xv_db "$PROTO")" 2>/dev/null | awk '{print $2}')
    if [ -z "$list" ]; then echo "  No accounts found"; echo ""; return 0; fi
    echo -e "  ${YL}List users :${NC} $list"
    echo ""
    while :; do
        read -rp "  Username to delete : " U
        U=$(echo "$U" | xargs)
        [ -z "$U" ] && continue
        grep -qw "$U" "$(xv_db "$PROTO")" && break
        echo "  User not found"
    done
    xv_remove "$PROTO" "$U"
    echo -e "  ${Green}Account $U deleted${NC}"
}

# ---------- renew xray proto ----------
xv_renew() {
    local PROTO="$1" U PFX ID
    PFX=$(marker_pfx "$PROTO")
    clear
    xv_title "Renew $(uc "$PROTO") Account"
    echo ""
    local list; list=$(grep "^###" "$(xv_db "$PROTO")" 2>/dev/null | awk '{print $2}')
    if [ -z "$list" ]; then echo "  No accounts found"; return 0; fi
    echo -e "  ${YL}List users :${NC} $list"
    echo ""
    while :; do
        read -rp "  Username to renew : " U
        [ -z "$U" ] && continue
        grep -qw "$U" "$(xv_db "$PROTO")" && break
        echo "  User not found"
    done
    xv_input_days
    sed -i "s|^${PFX} ${U} .*|${PFX} ${U} ${EXP}|" /etc/xray/config.json
    ID=$(awk -v u="$U" '$2==u{print $4; exit}' "$(xv_db "$PROTO")")
    sed -i "s|^### ${U} .*|### ${U} ${EXP} ${ID}|" "$(xv_db "$PROTO")"
    restart_xray
    echo -e "  ${Green}$U now expires on ${RED}$EXP${NC}"
    send_telegram "JustVPN : Renew $(uc "$PROTO") ${U} -> ${EXP}"
}

# ---------- check xray proto ----------
xv_cek() {
    local PROTO="$1" U EXP LEFT QUOTA LIM USED
    clear
    xv_title "Check $(uc "$PROTO") Accounts"
    echo ""
    printf "  %-12s %-12s %-10s %-12s %-8s\n" "USER" "EXPIRED" "DAYS" "QUOTA-USED/LIM" "IPLIM"
    xv_line
    while read -r LINE; do
        [ -z "$LINE" ] && continue
        U=$(echo "$LINE" | awk '{print $2}'); EXP=$(echo "$LINE" | awk '{print $3}')
        LEFT=$(( ($(date -d "$EXP" +%s) - $(date +%s)) / 86400 ))
        [ "$LEFT" -lt 0 ] && LEFT=0
        USE=$(xv_usage "$U")
        QUO=$(cat /etc/xray/quota/$U 2>/dev/null)
        if [ -n "$QUO" ] && [ "$QUO" -gt 0 ]; then
            QUOTA="$(fmt_size "$USE") / $(fmt_size "$QUO")"
        else
            QUOTA="$(fmt_size "$USE") / ∞"
        fi
        LIM=$(cat /etc/xray/iplimit/$U 2>/dev/null)
        [ -z "$LIM" ] && LIM=0
        printf "  %-12s %-12s %-10s %-12s %-8s\n" "$U" "$EXP" "$LEFT" "$QUOTA" "$LIM"
    done <<< "$(grep "^###" "$(xv_db "$PROTO")" 2>/dev/null)"
    echo ""
}

# ================= SSH =================
xv_addssh() {
    local PASS2
    clear
    xv_title "Add SSH & OpenVPN Account"
    echo ""
    xv_input_user
    xv_input_days
    xv_quota_ask
    xv_iplim_ask
    local PASS; PASS=$(gen_pass)
    read -rp "  Password [${PASS}] : " PASS2; [ -n "$PASS2" ] && PASS="$PASS2"
    useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USER" >/dev/null 2>&1
    echo "$USER:$PASS" | chpasswd >/dev/null 2>&1
    echo "### $USER $EXP " >> /etc/ssh/.ssh.db
    restart_xray
    clear
    xv_title "SSH & OpenVPN Account (JustVPN)"
    echo ""
    echo -e "  Username   : ${CY}${USER}${NC}"
    echo -e "  Password   : ${CY}${PASS}${NC}"
    echo -e "  Domain     : ${CY}${DOM}${NC}"
    echo -e "  SSH Port   : 22, 2222, 2223 | Dropbear 143, 109"
    echo -e "  SSH WS     : 443/80 via /ssh (X-Real-Host 127.0.0.1:22)"
    echo -e "  OVPN TCP   : 1194 | OVPN UDP : 2200 (10.8.0.0/24, 20.8.0.0/24)"
    echo -e "  SlowDNS    : ${CY}${NS}${NC} port 53"
    echo -e "  Expired    : ${RED}${EXP}${NC}"
    xv_line
    echo -e "  Config ZIP : ${CY}https://${DOM}:81/all-ovpn.zip${NC}"
    echo ""
    send_telegram "JustVPN : New SSH/OVPN account ${USER} expired ${EXP}"
}

xv_trials() {
    USER="trial$(date +%H%M%S)"
    DAYS=1; EXP=$(exp_date 1)
    local PASS; PASS=$(gen_pass)
    useradd -M -s /bin/false -e "$EXP" "$USER" >/dev/null 2>&1
    echo "$USER:$PASS" | chpasswd >/dev/null 2>&1
    echo "### $USER $EXP " >> /etc/ssh/.ssh.db
    xv_title "Trial SSH & OpenVPN Account"
    echo ""
    echo -e "  Username : ${CY}${USER}${NC}${NC}"
    echo -e "  Password : ${CY}${PASS}${NC}"
    echo -e "  Expired  : ${RED}${EXP}${NC}"
    xv_line; echo ""
}

xv_delssh() {
    local U
    clear
    xv_title "Delete SSH Account"
    echo ""
    local list; list=$(grep "^###" /etc/ssh/.ssh.db 2>/dev/null | awk '{print $2}')
    if [ -z "$list" ]; then echo "  No accounts found"; return 0; fi
    echo -e "  ${YL}List users :${NC} $list"
    echo ""
    while :; do
        read -rp "  Username to delete : " U
        [ -z "$U" ] && continue
        grep -qw "$U" /etc/ssh/.ssh.db && break
        echo "  User not found"
    done
    userdel -f "$U" 2>/dev/null
    sed -i "/^### ${U} /d" /etc/ssh/.ssh.db
    rm -f /etc/xray/quota/$U /etc/xray/iplimit/$U
    echo -e "  ${Green}Account $U deleted${NC}"
}

xv_renewssh() {
    local U
    clear
    xv_title "Renew SSH Account"
    echo ""
    local list; list=$(grep "^###" /etc/ssh/.ssh.db 2>/dev/null | awk '{print $2}')
    if [ -z "$list" ]; then echo "  No accounts found"; return 0; fi
    echo -e "  ${YL}List users :${NC} $list"
    echo ""
    while :; do
        read -rp "  Username to renew : " U
        [ -z "$U" ] && continue
        grep -qw "$U" /etc/ssh/.ssh.db && break
        echo "  User not found"
    done
    xv_input_days
    usermod -e "$EXP" "$U" 2>/dev/null
    sed -i "s|^### ${U} .*|### ${U} ${EXP} |" /etc/ssh/.ssh.db
    echo -e "  ${Green}$U now expires on ${RED}$EXP${NC}"
}

xv_cekssh() {
    clear
    xv_title "Check SSH Accounts"
    echo ""
    printf "  %-12s %-12s %-10s\n" "USER" "EXPIRED" "DAYS"
    xv_line
    while read -r LINE; do
        [ -z "$LINE" ] && continue
        local U EXP LEFT
        U=$(echo "$LINE" | awk '{print $2}'); EXP=$(echo "$LINE" | awk '{print $3}')
        LEFT=$(( ($(date -d "$EXP" +%s) - $(date +%s)) / 86400 ))
        [ "$LEFT" -lt 0 ] && LEFT=0
        printf "  %-12s %-12s %-10s\n" "$U" "$EXP" "$LEFT"
    done <<< "$(grep "^###" /etc/ssh/.ssh.db 2>/dev/null)"
    echo ""
}

uc() { echo "$1" | tr '[:lower:]' '[:upper:]' | sed 's/shadowsocks/SHADOWSOCKS/'; }

# ---------- count total connected users across all vpn services ----------
total_connected() {
    local total=0 n
    # SSH / Dropbear sessions
    n=$(who 2>/dev/null | wc -l); total=$((total + n))
    n=$(ss -tn state established '( sport = :22 or sport = :2222 or sport = :2223 or sport = :143 or sport = :109 )' 2>/dev/null | grep -c 'ESTAB'); total=$((total + n))
    # OpenVPN management interface lines (TCP 1194 / UDP 2200)
    if [ -f /etc/openvpn/server-tcp.log ] || [ -f /etc/openvpn/log-tcp.log ]; then
        n=$(cat /etc/openvpn/server-tcp.log /etc/openvpn/log-tcp.log 2>/dev/null | grep -c '^CLIENT_LIST'); total=$((total + n))
    fi
    # XRay active unique users seen in access.log in last 90s (fast gawk)
    if [ -f /var/log/xray/access.log ]; then
        local now
        now=$(date +%s)
        n=$(tail -n 1200 /var/log/xray/access.log 2>/dev/null \
            | gawk -v now="$now" '
                {
                  if (match($0, /^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/)) {
                    ts = substr($0,1,4) " " substr($0,6,2) " " substr($0,9,2) " " substr($0,12,2) " " substr($0,15,2) " " substr($0,18,2)
                    ep = mktime(ts)
                    if ( (now - ep) >= 0 && (now - ep) < 90 ) {
                      for (i=1;i<=NF;i++) if ($i=="email:") { em=$(i+1); if (!(em in seen)) seen[em]=1 }
                    }
                  }
                }
                END { for (e in seen) c++; print c+0 }')
        total=$((total + ${n:-0}))
    fi
    echo "$total"
}

# ---------- ping latency (lowest of 3 to 1.1.1.1) ----------
net_ping() {
    local ms
    ms=$(ping -c 3 -W 2 1.1.1.1 2>/dev/null | grep -oE 'time=[0-9.]+' | sed 's/time=//' | sort -n | head -1)
    [ -z "$ms" ] && ms=0
    echo "$ms"
}

# ---------- total bandwidth used (vnstat, fallback /proc/net/dev) ----------
net_bandwidth() {
    local b
    b=$(vnstat --oneline 2>/dev/null | awk -F';' '{print $11}' | awk '{$1=$1};1')
    if [ -n "$b" ] && [ "$b" != "-" ]; then
        echo "$b"
        return 0
    fi
    echo "$(awk 'NR>2{rx+=$2; tx+=$10} END{printf "%.2f GB", (rx+tx)/1073741824}' /proc/net/dev 2>/dev/null)"
}
XVNEOF
    chmod +x /usr/bin/xvn
    echo -e "${GR}[ OK ]${NC} shared library /usr/bin/xvn installed" >&3
}
# ===== lib-accs-b1.sh =====
#!/bin/bash
# ---------- thin wrappers for account operations ----------
install_wrappers() {
    while read -r FILE PROTO CMD; do
        printf '#!/bin/bash\nsource /usr/bin/xvn\nxv_%s %s\n' "$CMD" "$PROTO" > "/usr/bin/$FILE"
        chmod +x "/usr/bin/$FILE"
    done <<'WEOF'
add-ws vmess add
trial-ws vmess trial
del-ws vmess del
renew-ws vmess renew
cek-ws vmess cek
add-vless vless add
trial-vl vless trial
del-vless vless del
renew-vless vless renew
cek-vless vless cek
add-tr trojan add
trial-tr trojan trial
del-tr trojan del
renew-tr trojan renew
cek-tr trojan cek
add-ss shadowsocks add
trial-ss shadowsocks trial
del-ss shadowsocks del
renew-ss shadowsocks renew
cek-ss shadowsocks cek
add-socks socks add
trial-socks socks trial
del-socks socks del
renew-socks socks renew
cek-socks socks cek
WEOF

    cat >/usr/bin/add-ssh <<'AEOF'
#!/bin/bash
source /usr/bin/xvn
xv_addssh
AEOF
    cat >/usr/bin/trial-ssh <<'AEOF'
#!/bin/bash
source /usr/bin/xvn
xv_trials
AEOF
    cat >/usr/bin/del-ssh <<'AEOF'
#!/bin/bash
source /usr/bin/xvn
xv_delssh
AEOF
    cat >/usr/bin/renew-ssh <<'AEOF'
#!/bin/bash
source /usr/bin/xvn
xv_renewssh
AEOF
    cat >/usr/bin/cek-ssh <<'AEOF'
#!/bin/bash
source /usr/bin/xvn
xv_cekssh
AEOF
    for F in add-ssh trial-ssh del-ssh renew-ssh cek-ssh; do chmod +x "/usr/bin/$F"; done
    echo -e "${GR}[ OK ]${NC} account wrappers installed" >&3
}
# ===== lib-accs-b2.sh =====
# ---------- protocol managers ----------
install_managers() {
    write_manager_menu() {
        local PROTO="$1" TTL="$2" BIN="$3"
        cat > "/usr/bin/$BIN" <<EOFMGR
#!/bin/bash
source /usr/bin/xvn
clear
xv_title "\$TTL Manager"
echo ""
echo -e "  \${YL}[1]\${NC} Add Account      \${YL}[4]\${NC} Renew"
echo -e "  \${YL}[2]\${NC} Trial Account    \${YL}[5]\${NC} Cek / Limit"
echo -e "  \${YL}[3]\${NC} Delete Account   \${YL}[6]\${NC} Back to menu"
echo ""
echo -ne "  \${WH}Select [ 1 - 6 ] :\${NC} "
read -r M
case \$M in
   1) xv_add $PROTO ;;
   2) xv_trial $PROTO ;;
   3) xv_del $PROTO ;;
   4) xv_renew $PROTO ;;
   5) xv_cek $PROTO ;;
   6) menu ;;
   *) menu ;;
esac
EOFMGR
        chmod +x "/usr/bin/$BIN"
    }
    write_manager_menu vmess "Vmess" mvmess
    write_manager_menu vless "Vless" mvless
    write_manager_menu trojan "Trojan" mtrojan
    write_manager_menu shadowsocks "Shadowsocks" mshadowsocks
    write_manager_menu socks "Socks5" msocks

    cat >/usr/bin/mssh <<'EOFMSSH'
#!/bin/bash
source /usr/bin/xvn
clear
xv_title "SSH & OpenVPN Manager"
echo ""
echo -e "  ${YL}[1]${NC} Add SSH/OVPN   ${YL}[4]${NC} Renew"
echo -e "  ${YL}[2]${NC} Trial          ${YL}[5]${NC} Cek User"
echo -e "  ${YL}[3]${NC} Delete         ${YL}[6]${NC} Back to menu"
echo ""
echo -ne "  ${WH}Select [ 1 - 6 ] :${NC} "
read -r M
case $M in
   1) xv_addssh ;;
   2) xv_trials ;;
   3) xv_delssh ;;
   4) xv_renewssh ;;
   5) xv_cekssh ;;
   6) menu ;;
   *) menu ;;
esac
EOFMSSH
    chmod +x /usr/bin/mssh
    echo -e "${GR}[ OK ]${NC} managers installed (mssh/mvmess/mvless/mtrojan/mshadowsocks/msocks)" >&3
}

# ---------- main menu ----------
install_menu() {
    cat >/usr/bin/menu <<'MENUEOF'
#!/bin/bash
source /usr/bin/xvn
clear
for s in vmess vless trojan shadowsocks socks ssh; do
    mkdir -p /etc/$s
    touch /etc/$s/.$s.db
done
VM=$(grep -c "^###" /etc/vmess/.vmess.db 2>/dev/null)
VL=$(grep -c "^###" /etc/vless/.vless.db 2>/dev/null)
TR=$(grep -c "^###" /etc/trojan/.trojan.db 2>/dev/null)
SS=$(grep -c "^###" /etc/shadowsocks/.shadowsocks.db 2>/dev/null)
SK=$(grep -c "^###" /etc/socks/.socks.db 2>/dev/null)
SH=$(grep -c "^###" /etc/ssh/.ssh.db 2>/dev/null)
CONN=$(total_connected)
PING=$(net_ping)
BWD=$(net_bandwidth)
RAM=$(free -m | awk 'NR==2{printf "%s/%s MB %d%%", $3,$2,$3*100/$2}')
DISK=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
UPT=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
MODEL=$(grep -w PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//;s/"//g')
HW="$(cat /proc/cpuinfo | grep -c '^processor') Core"
xv_title "JustVPN — Main Menu"
xv_top
echo -e "${CY}│${NC}   ${WH}OS :${NC} $MODEL     ${WH}CPU :${NC} $HW"
echo -e "${CY}│${NC}   ${WH}RAM :${NC} $RAM   ${WH}UPTIME :${NC} $UPT"
echo -e "${CY}│${NC}   ${WH}DISK :${NC} $DISK   ${WH}PING :${NC} $PING ms"
echo -e "${CY}│${NC}   ${WH}BANDWIDTH :${NC} $BWD   ${WH}CONNECTED :${NC} ${YL}$CONN${NC}"
echo -e "${CY}│${NC}   ${WH}IP :${NC} $MYIP   ${WH}DOMAIN :${NC} $DOM"
echo -e "${CY}│${NC}   ${WH}NS (slowdns) :${NC} ${NS:-none}"
xv_bot
echo ""
xv_sect "ACCOUNT MENU"
echo ""
printf '%b\n' \
  "   ${YL}[1]${NC}  SSH & OVPN       ${YL}[5]${NC}  Shadowsocks" \
  "   ${YL}[2]${NC}  Vmess            ${YL}[6]${NC}  Socks5" \
  "   ${YL}[3]${NC}  Vless            ${YL}[7]${NC}  Other Settings" \
  "   ${YL}[4]${NC}  Trojan           ${YL}[8]${NC}  ${RD}Exit${NC}"
echo ""
echo -ne "  ${WH}Select [ 1 - 8 ] :${NC} "
read -r M
case $M in
   1) mssh ;;
   2) mvmess ;;
   3) mvless ;;
   4) mtrojan ;;
   5) mshadowsocks ;;
   6) msocks ;;
   7) msettings ;;
   8) echo "Goodbye!"; exit 0 ;;
   *) menu ;;
esac
MENUEOF
    chmod +x /usr/bin/menu
    echo -e "${GR}[ OK ]${NC} main menu installed (menu)" >&3
}
# ===== lib-accs-b3.sh =====
# ---------- expiry auto-removal ----------
install_xp() {
    cat >/usr/bin/xp <<'XPEOF'
#!/bin/bash
source /usr/bin/xvn
now=$(date +%s)
for P in vmess vless trojan shadowsocks socks; do
    while read -r LINE; do
        [ -z "$LINE" ] && continue
        U=$(echo "$LINE" | awk '{print $2}')
        EXP=$(echo "$LINE" | awk '{print $3}')
        e=$(date -d "$EXP" +%s 2>/dev/null) || continue
        if [ $(( now - e )) -ge 0 ]; then
            xv_remove "$P" "$U"
            echo -e "  ${RED}expired${NC} $P : $U"
        fi
    done <<< "$(grep "^###" "$(xv_db "$P")" 2>/dev/null)"
done
while read -r LINE; do
    [ -z "$LINE" ] && continue
    U=$(echo "$LINE" | awk '{print $2}')
    EXP=$(echo "$LINE" | awk '{print $3}')
    e=$(date -d "$EXP" +%s 2>/dev/null) || continue
    if [ $(( now - e )) -ge 0 ]; then
        userdel -f "$U" 2>/dev/null
        sed -i "/^### ${U} /d" /etc/ssh/.ssh.db
        rm -f /etc/xray/quota/$U /etc/xray/iplimit/$U
        echo -e "  ${RED}expired${NC} ssh : $U"
    fi
done <<< "$(grep "^###" /etc/ssh/.ssh.db 2>/dev/null)"
echo -e "  ${Green}Expired accounts cleaned${NC}"
XPEOF
    chmod +x /usr/bin/xp
    echo -e "${GR}[ OK ]${NC} xp (auto-delete expired) installed" >&3
}

# ---------- one-shot multi-login check ----------
install_xraylimit() {
    cat >/usr/bin/xraylimit <<'XLEOF'
#!/bin/bash
source /usr/bin/xvn
echo -e "${OR}  Checking multi-login & quota ...${NC}"
for P in vmess vless trojan shadowsocks socks; do
    while read -r LINE; do
        [ -z "$LINE" ] && continue
        U=$(echo "$LINE" | awk '{print $2}')
        LIM=$(cat /etc/xray/iplimit/$U 2>/dev/null); [ -z "$LIM" ] && LIM=0
        QUO=$(cat /etc/xray/quota/$U 2>/dev/null); [ -z "$QUO" ] && QUO=0
        CNT=$(active_ips "$U")
        USE=$(xv_usage "$U")
        if [ "$LIM" -gt 0 ] && [ "$CNT" -gt "$LIM" ]; then
            echo -e "  ${RED}$U : $CNT/$LIM IP (multi-login)$NC"
            send_telegram "JustVPN : $U uses $CNT IPs (limit $LIM)"
        fi
        if [ "$QUO" -gt 0 ] && [ "$USE" -ge "$QUO" ]; then
            echo -e "  ${RED}$U : quota hit $(fmt_size "$USE") / $(fmt_size "$QUO")$NC"
            send_telegram "JustVPN : $U quota exhausted ($(fmt_size "$USE"))"
        fi
    done <<< "$(grep "^###" "$(xv_db "$P")" 2>/dev/null)"
done
echo -e "  ${Green}done${NC}"
XLEOF
    chmod +x /usr/bin/xraylimit
}

# ---------- interactive killer ----------
install_kills() {
    cat >/usr/bin/kills <<'KEOF'
#!/bin/bash
source /usr/bin/xvn
echo -e "${LBX}╭─────────── Kill Account ───────────╮${NC}"
echo -e "${LBX}│${NC}   Delete a user + close session   "
echo -e "${LBX}╰──────────────────────────────────────╯${NC}"
echo ""
echo -e "  ${YL}Protocols :${NC} vmess / vless / trojan / shadowsocks / socks / ssh"
echo ""
read -rp "  Protocol : " P
read -rp "  Username : " U
case "$P" in
    vmess|vless|trojan|shadowsocks|socks)
        xv_remove "$P" "$U" ;;
    ssh)
        userdel -f "$U" 2>/dev/null
        sed -i "/^### ${U} /d" /etc/ssh/.ssh.db ;;
    *) echo "  Invalid protocol"; exit 1 ;;
esac
pkill -u "$U" 2>/dev/null
echo -e "  ${Green}Account $U killed${NC}"
KEOF
    chmod +x /usr/bin/kills
}

# ---------- uninstall JustVPN (full cleanup) ----------
install_uninstall() {
    cat >/usr/bin/uninstall <<'UNEOF'
#!/bin/bash
source /usr/bin/xvn
echo -e "${RD}╭───────── JustVPN UNINSTALLER ─────────╮${NC}"
echo -e "${RD}│${NC}   Full cleanup — remove everything     "
echo -e "${RD}╰────────────────────────────────────────╯${NC}"
echo ""
echo -e "${YL}This will remove ALL JustVPN services, configs, accounts${NC}"
echo -e "${YL}and installed packages from this server.${NC}"
echo ""
read -rp "  Are you sure? Type 'uninstall' to confirm : " C
[ "$C" != "uninstall" ] && { echo "  Cancelled."; exit 0; }

SVC=(xray nginx haproxy ws wsovpn dropbear openvpn@server-tcp openvpn@server-udp squid xlimitd server client badvpn1 badvpn2 badvpn3 rc-local stunnel4)
echo -e "  ${OR}Stopping & disabling services ...${NC}"
for s in "${SVC[@]}"; do
    systemctl stop "$s" 2>/dev/null
    systemctl disable "$s" 2>/dev/null
done
systemctl daemon-reload

echo -e "  ${OR}Removing justvpn configs & binaries ...${NC}"
rm -rf /etc/xray /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/socks
rm -f /usr/local/bin/xray
rm -rf /usr/local/share/xray
rm -f /usr/bin/ws.py /usr/bin/xvn /usr/bin/menu /usr/bin/msettings
rm -f /usr/bin/run /usr/bin/seres /usr/bin/xraylimit /usr/bin/kills /usr/bin/xp
rm -f /usr/bin/xlimitd /usr/bin/backup /usr/bin/restore /usr/bin/backup-gd /usr/bin/logclean
rm -f /usr/bin/speedtest-go /usr/bin/autoreboot /usr/bin/dnschanger /usr/bin/bbrplus
rm -f /etc/stunnel/stunnel.conf /etc/xray/funny.pem
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /usr/bin/mssh /usr/bin/mvmess /usr/bin/mvless /usr/bin/mtrojan /usr/bin/mshadowsocks /usr/bin/msocks
for F in add-ws trial-ws del-ws renew-ws cek-ws add-vless trial-vl del-vless renew-vless cek-vless add-tr trial-tr del-tr renew-tr cek-tr add-ss trial-ss del-ss renew-ss cek-ss add-socks trial-socks del-socks renew-socks cek-socks add-ssh trial-ssh del-ssh renew-ssh cek-ssh; do
    rm -f "/usr/bin/$F"
done
rm -rf /etc/slowdns /etc/funny /etc/mlak /etc/iptables/rules.v4 /etc/iptables/rules.v6
rm -f /etc/haproxy/yha.pem
rm -f /var/www/html/*.ovpn /var/www/html/all-ovpn.zip /var/www/html/justvpn-*.txt
rm -rf /etc/systemd/system/ws.service /etc/systemd/system/wsovpn.service
rm -rf /etc/systemd/system/xlimitd.service /etc/systemd/system/badvpn*.service
rm -rf /etc/systemd/system/server.service /etc/systemd/system/client.service
systemctl daemon-reload

echo -e "  ${OR}Removing installed packages ...${NC}"
apt-get purge -y nginx nginx-common haproxy dropbear openvpn squid stunnel4 php php-cli php-fpm php-mysql php-xml php-curl vnstat >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "  ${OR}Removing cron + banner ...${NC}"
sed -i '/JustVPN setup/,+2d' /etc/crontab 2>/dev/null
rm -f /etc/banner

echo -e "  ${GR}Cleanup done. You may reboot the server.${NC}"
echo ""
read -rp "  Press Enter to exit " x
exit 0
UNEOF
    chmod +x /usr/bin/uninstall
    echo -e "${GR}[ OK ]${NC} uninstaller installed" >&3
}

# ---------- restart all services ----------
install_seres() {
    cat >/usr/bin/seres <<'SEOF'
#!/bin/bash
source /usr/bin/xvn
clear
echo -e "${LBX}╭───────── Restart All Services ─────────╮${NC}"
echo -e "${LBX}│${NC}   Restarting every JustVPN service   "
echo -e "${LBX}╰────────────────────────────────────────╯${NC}"
echo ""
SVC=(xray nginx haproxy ws wsovpn dropbear openvpn@server-tcp openvpn@server-udp squid xlimitd server client badvpn1 badvpn2 badvpn3 cron ssh stunnel4)
for s in "${SVC[@]}"; do
    systemctl restart "$s" 2>/dev/null
    echo -e "  ${CY}restart${NC} $s ${Green}[OK]$NC"
done
systemctl daemon-reload
SEOF
    chmod +x /usr/bin/seres
}

# ---------- status dashboard ----------
install_run() {
    cat >/usr/bin/run <<'RUNEOF'
#!/bin/bash
source /usr/bin/xvn
clear
VM=$(grep -c "^###" /etc/vmess/.vmess.db 2>/dev/null)
SH=$(grep -c "^###" /etc/ssh/.ssh.db 2>/dev/null)
st() { systemctl is-active "$1" 2>/dev/null | grep -q active && echo -e "${Green}● Online${NC}" || echo -e "${RED}● Offline${NC}"; }
xv_title "Server Status"
echo ""
xv_top
echo -e "${CY}│${NC}  ${WH}Xray        :${NC} $(st xray)          ${WH}Nginx :${NC} $(st nginx)"
echo -e "${CY}│${NC}  ${WH}HAProxy     :${NC} $(st haproxy)       ${WH}Dropbear :${NC} $(st dropbear)"
echo -e "${CY}│${NC}  ${WH}Ws          :${NC} $(st ws)            ${WH}Ws-Ovpn :${NC} $(st wsovpn)"
echo -e "${CY}│${NC}  ${WH}Stunnel    :${NC} $(st stunnel4)"
echo -e "${CY}│${NC}  ${WH}OpenVPN-TCP :${NC} $(st openvpn@server-tcp)   ${WH}OpenVPN-UDP :${NC} $(st openvpn@server-udp)"
echo -e "${CY}│${NC}  ${WH}Squid       :${NC} $(st squid)         ${WH}Limitd :${NC} $(st xlimitd)"
echo -e "${CY}│${NC}  ${WH}SlowDNS     :${NC} $(st server)        ${WH}Badvpn :${NC} $(st badvpn1)"
echo -e "${CY}│${NC}  ${WH}Domain      :${NC} $DOM"
echo -e "${CY}│${NC}  ${WH}IP          :${NC} $MYIP"
echo -e "${CY}│${NC}  ${WH}SSH :${NC} $SH   ${WH}VMESS :${NC} $VM"
xv_bot
echo ""
echo -ne "  ${WH}Press Enter to back${NC} "
read -r x
menu
RUNEOF
    chmod +x /usr/bin/run
    echo -e "${GR}[ OK ]${NC} status dashboard (run) installed" >&3
}
# ===== lib-accs-b4.sh =====
# ---------- settings menu ----------
install_msettings() {
    cat >/usr/bin/msettings <<'MSEOF'
#!/bin/bash
source /usr/bin/xvn
clear
while :; do
    xv_title "Settings / Tools"
    echo ""
    echo -e "  ${YL}[1]${NC} Server Status Dashboard (run)"
    echo -e "  ${YL}[2]${NC} Restart All Services (seres)"
    echo -e "  ${YL}[3]${NC} Check Multi-Login & Quota (xraylimit)"
    echo -e "  ${YL}[4]${NC} Kill Account (kills)"
    echo -e "  ${YL}[5]${NC} Auto-Delete Expired Now (xp)"
    echo -e "  ${YL}[6]${NC} Clean Logs (logclean)"
    echo -e "  ${YL}[7]${NC} Backup Data (backup)"
    echo -e "  ${YL}[8]${NC} Restore Data (restore)"
    echo -e "  ${YL}[9]${NC} Backup to Google Drive (backup-gd)"
    echo -e "  ${YL}[10]${NC} Telegram Bot & Notif Setup"
    echo -e "  ${YL}[11]${NC} Speedtest by Ookla"
    echo -e "  ${YL}[12]${NC} Set Auto Reboot"
    echo -e "  ${YL}[13]${NC} DNS Changer"
    echo -e "  ${YL}[14]${NC} BBRPLUS (v1.4.0)"
    echo -e "  ${RD}[15]${NC} Uninstall JustVPN"
    echo -e "  ${YL}[16]${NC} Back to menu"
    echo ""
    echo -ne "  ${WH}Select [ 1 - 16 ] :${NC} "
    read -r M
    case $M in
        1) run ;;
        2) seres ;;
        3) xraylimit; echo ""; read -rp "  Press Enter to back " x ;;
        4) kills; read -rp "  Press Enter to back " x ;;
        5) xp; echo ""; read -rp "  Press Enter to back " x ;;
        6) logclean ;;
        7) backup ;;
        8) restore ;;
        9) backup-gd ;;
        10) tasket ;;
        11) speedtest-go ;;
        12) autoreboot ;;
        13) dnschanger ;;
        14) bbrplus ;;
        15) uninstall ;;
        16) menu ;;
        *) echo "  Invalid option"; sleep 1 ;;
    esac
done
MSEOF
    chmod +x /usr/bin/msettings
    echo -e "${GR}[ OK ]${NC} settings menu (msettings) installed" >&3
}

# ---------- telegram bot/key setup ----------
install_tasket() {
    cat >/usr/bin/tasket <<'TSEOF'
#!/bin/bash
source /usr/bin/xvn
mkdir -p /etc/funny /etc/mlak
echo -e "${OR}  Telegram notification setup${NC}"
echo ""
read -rp "  Bot Token (leave empty to skip) : " BT
read -rp "  Chat/Group ID                   : " CID
if [ -n "$BT" ] && [ -n "$CID" ]; then
    echo "$BT" > /etc/funny/.keybot
    echo "$CID" > /etc/funny/.chatid
    grep -q '^BOT_TOKEN' /etc/mlak/var.txt 2>/dev/null || echo "BOT_TOKEN=$BT" >> /etc/mlak/var.txt
    grep -q '^ADMIN' /etc/mlak/var.txt 2>/dev/null || echo "ADMIN=$CID" >> /etc/mlak/var.txt
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${BT}/sendMessage" -d chat_id="${CID}" -d text="JustVPN : bot active" >/dev/null 2>&1
    echo -e "  ${Green}Telegram enabled${NC}"
else
    rm -f /etc/funny/.keybot /etc/funny/.chatid
    echo -e "  ${RED}Telegram disabled${NC}"
fi
read -rp "  Press Enter to back " x
msettings
TSEOF
    chmod +x /usr/bin/tasket
}

# ---------- clean logs ----------
install_logclean() {
    cat >/usr/bin/logclean <<'LCEOF'
#!/bin/bash
source /usr/bin/xvn
echo -e "${OR}  Cleaning logs ...${NC}"
find /var/log -name "*.log" -type f -delete 2>/dev/null
find /var/log/xray -type f -delete 2>/dev/null
: > /var/log/xray/access.log 2>/dev/null
truncate -s 0 /var/log/syslog 2>/dev/null
truncate -s 0 /var/log/auth.log 2>/dev/null
history -c 2>/dev/null
systemctl restart xray 2>/dev/null
echo -e "  ${Green}Logs cleaned, access.log reset${NC}"
LCEOF
    chmod +x /usr/bin/logclean
}
# ===== lib-accs-b5.sh =====
# ---------- backup / restore / gdrive ----------
install_backup() {
    cat >/usr/bin/backup <<'BKEOF'
#!/bin/bash
source /usr/bin/xvn
D=/root/backup
mkdir -p "$D"
BN="backup-$(date +%Y-%m-%d_%H%M%S).zip"
echo -e "${OR}  Backing up JustVPN data ...${NC}"
zip -qr "$D/$BN" \
    /etc/xray/config.json /etc/xray/domain /etc/xray/dns 2>/dev/null
zip -qur "$D/$BN" /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/socks /etc/ssh 2>/dev/null
zip -qur "$D/$BN" /etc/xray/quota /etc/xray/iplimit 2>/dev/null
zip -qur "$D/$BN" /etc/funny /etc/mlak 2>/dev/null
zip -qur "$D/$BN" /etc/slowdns 2>/dev/null
zip -qur "$D/$BN" /etc/haproxy/yha.pem /etc/letsencrypt 2>/dev/null
zip -qur "$D/$BN" /etc/openvpn /etc/dropbear 2>/dev/null
zip -qur "$D/$BN" /etc/passwd /etc/shadow /etc/group 2>/dev/null
SIZE=$(du -h "$D/$BN" | awk '{print $1}')
echo -e "  ${Green}Backup saved :${NC} $D/$BN (${SIZE})"
echo ""
read -rp "  Backup to Google Drive too? [y/N] : " G
if [ "$G" = "y" ] || [ "$G" = "Y" ]; then /usr/bin/backup-gd "$D/$BN"; fi
read -rp "  Press Enter to back " x
msettings
BKEOF
    cat >/usr/bin/restore <<'RSEOF'
#!/bin/bash
source /usr/bin/xvn
D=/root/backup
mkdir -p "$D"
echo -e "${OR}  Available backups in $D :${NC}"
ls -1 "$D"/*.zip 2>/dev/null || { echo "  No backups found"; read -rp "  Press Enter to back " x; msettings; exit 0; }
echo ""
read -rp "  Backup file name (or Enter for newest) : " F
[ -z "$F" ] && F=$(ls -1t "$D"/*.zip 2>/dev/null | head -1)
[ -f "$F" ] || F="$D/$F"
[ -f "$F" ] || { echo "  Not found"; read -rp "  Press Enter to back " x; msettings; exit 0; }
echo -e "  ${OR}Restoring ${F} ...${NC}"
cd /
unzip -o "$F" >/dev/null 2>&1
systemctl restart xray nginx haproxy 2>/dev/null
echo -e "  ${Green}Restore done, services restarted${NC}"
read -rp "  Press Enter to back " x
msettings
RSEOF
    chmod +x /usr/bin/backup /usr/bin/restore
    echo -e "${GR}[ OK ]${NC} backup / restore installed" >&3
}

install_backup_gd() {
    cat >/usr/bin/backup-gd <<'BGEOF'
#!/bin/bash
source /usr/bin/xvn
BN="$1"
[ -z "$BN" ] && BN=$(ls -1t /root/backup/*.zip 2>/dev/null | head -1)
[ -z "$BN" ] && { echo "  No backup to upload"; exit 1; }
if ! command -v rclone >/dev/null 2>&1; then
    echo -e "  ${OR}Installing rclone ...${NC}"
    curl -sSL -o /tmp/rclone.zip https://downloads.rclone.org/rclone-current-linux-amd64.zip >/dev/null 2>&1
    if [ -f /tmp/rclone.zip ]; then
        cd /tmp && unzip -oq rclone.zip && cp rclone-*/rclone /usr/bin/rclone 2>/dev/null && chmod +x /usr/bin/rclone && rm -rf /tmp/rclone*
    fi
fi
if ! command -v rclone >/dev/null 2>&1; then
    echo -e "  ${RED}rclone install failed, install manually: https://rclone.org${NC}"
    exit 1
fi
if ! rclone lsd jvd_gdrive: >/dev/null 2>&1; then
    echo -e "  ${OR}Setup Google Drive remote 'jvd_gdrive' (first time only):${NC}"
    rclone config config
fi
rclone copy "$BN" jvd_gdrive:JustVPN-Backup 2>/dev/null \
    && echo -e "  ${Green}Uploaded to Google Drive :${NC} JustVPN-Backup/$(basename "$BN")" \
    || echo -e "  ${RED}Upload failed (rclone config? remote name 'jvd_gdrive'?)${NC}"
echo ""
read -rp "  Press Enter to back " x
msettings
BGEOF
    chmod +x /usr/bin/backup-gd
    echo -e "${GR}[ OK ]${NC} backup-gd (Google Drive) installed" >&3
}
# ===== lib-accs-b6.sh =====
# ---------- xlimitd daemon (quota + ip-limit enforcer) ----------
install_daemons() {
    cat >/usr/bin/xlimitd <<'XDEOF'
#!/bin/bash
source /usr/bin/xvn
mkdir -p /etc/xray/.warn
while true; do
    for P in vmess vless trojan shadowsocks socks; do
        while read -r LINE; do
            [ -z "$LINE" ] && continue
            U=$(echo "$LINE" | awk '{print $2}')
            LIM=$(cat /etc/xray/iplimit/$U 2>/dev/null); [ -z "$LIM" ] && LIM=0
            QUO=$(cat /etc/xray/quota/$U 2>/dev/null); [ -z "$QUO" ] && QUO=0
            USE=$(xv_usage "$U")
            if [ "$QUO" -gt 0 ] && [ "$USE" -ge "$QUO" ]; then
                send_telegram "JustVPN : $U quota exhausted → removed ($(fmt_size "$USE"))"
                xv_remove "$P" "$U"
                rm -f /etc/xray/.warn/$U
                continue
            fi
            CNT=$(active_ips "$U")
            if [ "$LIM" -gt 0 ] && [ "$CNT" -gt "$LIM" ]; then
                W=$(cat /etc/xray/.warn/$U 2>/dev/null); W=$((W+1))
                echo "$W" > /etc/xray/.warn/$U
                if [ "$W" -ge 2 ]; then
                    send_telegram "JustVPN : $U multi-login exceeded ($CNT/$LIM) → removed"
                    xv_remove "$P" "$U"
                    rm -f /etc/xray/.warn/$U
                else
                    send_telegram "JustVPN : WARNING $U : $CNT/$LIM IP dipakai bersamaan"
                fi
            else
                rm -f /etc/xray/.warn/$U
            fi
        done <<< "$(grep "^###" "$(xv_db "$P")" 2>/dev/null)"
    done
    sleep 30
done
XDEOF
    chmod +x /usr/bin/xlimitd
    cat >/etc/systemd/system/xlimitd.service <<'SUEOF'
[Unit]
Description=JustVPN Quota & IP-Limit enforcer
After=network.target xray.service

[Service]
Type=simple
ExecStart=/usr/bin/xlimitd
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SUEOF
    systemctl daemon-reload 2>/dev/null
    systemctl enable xlimitd 2>/dev/null
    echo -e "${GR}[ OK ]${NC} xlimitd daemon (quota + iplimit) installed" >&3
}

# ---------- cron ----------
install_cron() {
    grep -q 'JustVPN setup' /etc/crontab 2>/dev/null && return 0
    cat >>/etc/crontab <<'CEOF'

#JustVPN setup
* * * * * root /usr/bin/xp >/dev/null 2>&1
30 2 * * * root /usr/bin/backup >/dev/null 2>&1
CEOF
    echo -e "${GR}[ OK ]${NC} cron installed (xp autodelete, daily backup)" >&3
}
# ===== lib-accs-b7.sh =====
# ---------- Speedtest (Ookla/speedtest-cli) ----------
install_speedtest_tool() {
    if ! command -v speedtest >/dev/null 2>&1; then
        pip3 install -q speedtest-cli >/dev/null 2>&1 || pip install -q speedtest-cli >/dev/null 2>&1
    fi
    cat >/usr/bin/speedtest-go <<'SPEOF'
#!/bin/bash
source /usr/bin/xvn
if ! command -v speedtest >/dev/null 2>&1; then
    echo -e "  ${RED}speedtest not installed. Run: pip3 install speedtest-cli${NC}"
    exit 1
fi
clear
xv_title "Speedtest"
echo ""
speedtest --secure
echo ""
echo -ne "  ${WH}Press Enter to back${NC} "
read -r x
clear
SPEOF
    chmod +x /usr/bin/speedtest-go
    echo -e "${GR}[ OK ]${NC} speedtest (speedtest-go) installed" >&3
}

# ---------- Set Auto Reboot ----------
install_autoreboot() {
    cat >/usr/bin/autoreboot <<'AREOF'
#!/bin/bash
source /usr/bin/xvn
clear
cur=$(grep -oE 'shutdown -r.*' /etc/crontab 2>/dev/null | head -1 | grep -oE '[0-9]+ [0-9]+ \* \* \*' | awk '{print $1":"$2}')
if [ -n "$cur" ]; then
    STAT="Enabled (daily at ${cur})"
else
    STAT="Disabled"
fi
xv_title "Set Auto Reboot"
echo ""
echo -e "  ${WH}Current auto-reboot :${NC} ${YL}$STAT${NC}"
echo ""
echo -e "  Enter reboot hour in 24h format (0-23), or 99 to disable."
echo -ne "  ${WH}Hour [99=off] :${NC} "
read -r H
# strip any existing shutdown line, keep base cron
sed -i '/shutdown -r/d' /etc/crontab 2>/dev/null
case "$H" in
    99|"" )
        echo -e "  ${Green}Auto-reboot disabled${NC}" ;;
    [0-9]|[01][0-9]|2[0-3] )
        MIN=$(printf '%02d' "$((RANDOM % 60))")
        sed -i '/JustVPN setup/,$d' /etc/crontab 2>/dev/null
        cat >>/etc/crontab <<CEOF2
#JustVPN setup
* * * * * root /usr/bin/xp >/dev/null 2>&1
30 2 * * * root /usr/bin/backup >/dev/null 2>&1
${MIN} ${H} * * * root /sbin/shutdown -r "${H}:${MIN}" >/dev/null 2>&1
CEOF2
        echo -e "  ${Green}Daily auto-reboot set at ${H}:${MIN}${NC}" ;;
    * )
        echo -e "  ${RED}Invalid hour${NC}" ;;
esac
echo ""
echo -ne "  ${WH}Press Enter to back${NC} "
read -r x
clear
AREOF
    chmod +x /usr/bin/autoreboot
    echo -e "${GR}[ OK ]${NC} auto-reboot (autoreboot) installed" >&3
}

# ---------- DNS Changer ----------
install_dnschanger() {
    cat >/usr/bin/dnschanger <<'DNSEOF'
#!/bin/bash
source /usr/bin/xvn
clear
xv_title "DNS Changer"
echo ""
echo -e "  ${YL}[1]${NC}  Google (8.8.8.8 / 8.8.4.4)"
echo -e "  ${YL}[2]${NC}  Cloudflare (1.1.1.1 / 1.0.0.1)"
echo -e "  ${YL}[3]${NC}  Quad9 (9.9.9.9 / 149.112.112.112)"
echo -e "  ${YL}[4]${NC}  OpenDNS (208.67.222.222 / 208.67.220.220)"
echo -e "  ${YL}[5]${NC}  Custom"
echo -e "  ${YL}[6]${NC}  Back"
echo ""
echo -ne "  ${WH}Select [ 1 - 6 ] :${NC} "
read -r M
case "$M" in
    1) D1=8.8.8.8;  D2=8.8.4.4 ;;
    2) D1=1.1.1.1;  D2=1.0.0.1 ;;
    3) D1=9.9.9.9;  D2=149.112.112.112 ;;
    4) D1=208.67.222.222; D2=208.67.220.220 ;;
    5) read -rp "  Primary DNS : " D1; read -rp "  Secondary DNS : " D2 ;;
    6) clear; msettings; exit 0 ;;
    *) clear; dnschanger; exit 0 ;;
esac
[ -z "$D1" ] && D1=8.8.8.8
[ -z "$D2" ] && D2=8.8.4.4
rm -f /etc/resolv.conf
cat >/etc/resolv.conf <<EOF
nameserver $D1
nameserver $D2
EOF
chattr +i /etc/resolv.conf 2>/dev/null
echo -e "  ${Green}DNS set to $D1 / $D2${NC}"
echo ""
read -rp "  Press Enter to back " x
clear
DNSEOF
    chmod +x /usr/bin/dnschanger
    echo -e "${GR}[ OK ]${NC} DNS changer (dnschanger) installed" >&3
}

# ---------- BBRPLUS (optional, downloads tcp.sh by Chikage0o0) ----------
# Auto kernel install is risky on a live box; this offers the official v1.4.0 menu.
install_bbrplus() {
    cat >/usr/bin/bbrplus <<'BBEOF'
#!/bin/bash
source /usr/bin/xvn
clear
xv_title "BBRPLUS v1.4.0 (Chikage0o0)"
echo ""
echo -e "  ${WH}Current TCP congestion control :${NC} ${YL}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)${NC}"
echo -e "  ${WH}Current kernel                 :${NC} ${YL}$(uname -r)${NC}"
echo ""
echo -e "  ${OR}BBRplus uses the 4.14.129-bbrplus kernel (requires install + reboot).${NC}"
echo -e "  ${OR}On modern kernels recent BBR is often already best. Proceed at your own risk.${NC}"
echo ""
echo -ne "  ${WH}Download & run tcp.sh v1.4.0 ? [y/N] :${NC} "
read -r ans
[ "$ans" != "y" ] && [ "$ans" != "Y" ] && { clear; msettings; exit 0; }
cd /tmp || exit 1
wget -N --no-check-certificate -O tcp.sh \
    "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" >/dev/null 2>&1
[ -s tcp.sh ] || { echo -e "  ${RED}Download failed${NC}"; read -rp "  Press Enter to back " x; clear; msettings; exit 1; }
chmod +x tcp.sh
bash tcp.sh
rm -f /tmp/tcp.sh
clear
BBEOF
    chmod +x /usr/bin/bbrplus
    echo -e "${GR}[ OK ]${NC} bbrplus tool installed" >&3
}

# ---------- Stunnel4 (222 / 777) ----------
stunnel_config() {
    if [ ! -f /etc/xray/funny.pem ]; then
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -sha256 \
            -subj "/C=ID/ST=JustVPN/L=JustVPN/O=JustVPN/CN=$(cat /etc/xray/domain 2>/dev/null)" \
            -keyout /etc/xray/funny.pem -out /etc/xray/funny.pem >/dev/null 2>&1
        chmod 600 /etc/xray/funny.pem
    fi
    cat >/etc/stunnel/stunnel.conf <<'STEOF'
cert = /etc/xray/funny.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[openssh]
accept = 777
connect = 127.0.0.1:22

[dropbear]
accept = 222
connect = 127.0.0.1:109
STEOF
    systemctl daemon-reload
    systemctl enable stunnel4 >/dev/null 2>&1
    systemctl restart stunnel4 2>/dev/null || true
    echo -e "${GR}[ OK ]${NC} Stunnel4 ports 222/777 (openssh 777, dropbear 222)" >&3
}

# ===== lib-order.sh =====
#!/bin/bash
# ---------- start all enabled services ----------
start_all() {
    print_step "Starting all JustVPN services"
    for s in ssh dropbear squid xray nginx haproxy ws wsovpn stunnel4 \
        openvpn@server-tcp openvpn@server-udp xlimitd \
        rc-local server client badvpn1 badvpn2 badvpn3; do
        systemctl enable "$s" >/dev/null 2>&1
        systemctl start "$s" >/dev/null 2>&1
        if systemctl is-active "$s" 2>/dev/null | grep -q active; then
            echo -e "  ${GR}●${NC} $s ${Green}active${NC}" >&3
        else
            echo -e "  ${RD}○${NC} $s ${RED}failed${NC} (see /var/log/justvpn-setup.log)" >&3
        fi
    done
}

# ---------- final summary panel ----------
install_finish() {
    local DOMAIN NS PUB
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
    NS=$(cat /etc/xray/dns 2>/dev/null)
    PUB=$(cat /etc/slowdns/server.pub 2>/dev/null)
    clear >&3
    echo "" >&3
    echo -e "$BL ╭──────────────────────────────────────────────────╮$NC" >&3
    echo -e "$BL │${NC}  ${GR}✓ INSTALL SUCCESSFUL — JustVPN${NC}             $BL│$NC" >&3
    echo -e "$BL ├──────────────────────────────────────────────────┤$NC" >&3
    echo -e "$BL │${NC}  Domain        : ${CY}${DOMAIN}${NC}                     $BL│$NC" >&3
    echo -e "$BL │${NC}  SSH           : 22, 2222, 2223, 53. Dropbear 143, 109 $BL│$NC" >&3
    echo -e "$BL │${NC}  Stunnel       : 777 (ssh), 222 (dropbear)             $BL│$NC" >&3
    echo -e "$BL │${NC}  WS            : 80, 443 (ssh-ws / vmess / vless /$BL│$NC" >&3
    echo -e "$BL │${NC}                  trojan / ss / socks5 path)        $BL│$NC" >&3
    echo -e "$BL │${NC}  XRay gRPC     : 443 (vless/vmess/trojan/ss grpc)  $BL│$NC" >&3
    echo -e "$BL │${NC}  Other http    : 55, 8080, 2086, 8880 (same as 80) $BL│$NC" >&3
    echo -e "$BL │${NC}  UDPGW BadVPN  : 7100, 7200, 7300                 $BL│$NC" >&3
    echo -e "$BL │${NC}  OpenVPN       : TCP 1194, UDP 2200, SSL 443       $BL│$NC" >&3
    echo -e "$BL │${NC}  Squid proxy   : 3128                             $BL│$NC" >&3
    echo -e "$BL │${NC}  SlowDNS NS    : ${NS:-none}${NC}  port 53               $BL│$NC" >&3
    echo -e "$BL │${NC}  SlowDNS Pub   : ${PUB:-none}${NC}" >&3
    echo -e "$BL ├──────────────────────────────────────────────────┤$NC" >&3
    echo -e "$BL │${NC}  MENU : ${WH}menu${NC}  (or ssh / vmess / trojan...) $BL│$NC" >&3
    echo -e "$BL │${NC}  Panel: ${CY}https://${DOMAIN}:81${NC} (info + ovpn zip) $BL│$NC" >&3
    echo -e "$BL │${NC}  Text : ${CY}https://${DOMAIN}:81/justvpn-USER.txt${NC}  $BL│$NC" >&3
    echo -e "$BL │${NC}  Backups in /root/backup (backup / restore / backup-gd)$BL│$NC" >&3
    echo -e "$BL ╰──────────────────────────────────────────────────╯$NC" >&3
    echo -e "${GR}  Reboot recommended to finalize. Type 'menu' after reboot.${NC}" >&3
    echo "" >&3
}

# ---------- main install ----------
main() {
    banner
    is_root
    check_ubuntu_version
    check_vz
    make_folder_xray

    updatePackages
    insDepedency

    add_domain
    write_info
    add_dnssub
    setup_telegram

    install_xray
    xray_service
    xray_config
    issue_cert
    haproxy_conf

    ssh_config
    dropbear_config
    write_banner
    squid_config
    write_ws_py
    write_tunconf
    ws_services
    openvpn_setup
    bbrypt
    rc_local
    iptables_rules

    nginx_conf
    nginx_vhosts
    nginx_service

    slowdns_setup
    install_badvpn
    badvpn_services
    stunnel_config

    install_xvn
    install_wrappers
    install_managers
    install_menu
    install_xp
    install_xraylimit
    install_kills
    install_seres
    install_run
    install_uninstall
    install_msettings
    install_tasket
    install_logclean
    install_speedtest_tool
    install_autoreboot
    install_dnschanger
    install_bbrplus
    install_backup
    install_backup_gd
    install_daemons
    install_cron

    start_all
    install_finish
}

main "$@"