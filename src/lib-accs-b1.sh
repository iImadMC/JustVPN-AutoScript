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