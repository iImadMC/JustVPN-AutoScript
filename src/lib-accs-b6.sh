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