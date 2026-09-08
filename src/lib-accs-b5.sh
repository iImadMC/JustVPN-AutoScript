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