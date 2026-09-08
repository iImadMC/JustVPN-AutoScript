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
