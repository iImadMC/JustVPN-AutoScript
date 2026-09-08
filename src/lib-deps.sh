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