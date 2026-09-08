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