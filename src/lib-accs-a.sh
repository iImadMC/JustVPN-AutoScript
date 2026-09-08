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