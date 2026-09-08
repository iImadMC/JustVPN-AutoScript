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