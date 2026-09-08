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