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