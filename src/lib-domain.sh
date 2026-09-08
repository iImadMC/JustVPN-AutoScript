#!/bin/bash
# ---------- custom domain prompt (NO free domain feature) ----------
add_domain() {
    print_step "Domain Configuration"
    echo -e "${WH}Please point an A record of your domain to: ${GR}$MYIP${NC}" >&3
    echo -e "${YL}This script does NOT provide a free domain.${NC}" >&3
    echo "" >&3
    while :; do
        echo -ne "${BL}│ ${WH}Input your domain/subdomain : ${NC}" >&3
        IFS= read -r DOMAIN < /dev/tty
        DOMAIN=$(echo "$DOMAIN" | sed 's#^https\?://##' | sed 's#/##' | tr '[:upper:]' '[:lower:]' | xargs)
        if [[ -z "$DOMAIN" ]]; then
            echo -e "${RD}[ ERROR ]${NC} Domain cannot be empty" >&3
        elif [[ ! "$DOMAIN" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]]; then
            echo -e "${RD}[ ERROR ]${NC} Invalid domain format" >&3
        else
            break
        fi
    done
    echo -e "${GR}[ OK ]${NC} Domain set to: $DOMAIN" >&3
    echo "$DOMAIN" > /etc/xray/domain
}

# ---------- slowdns nameserver (custom, user-managed NS record) ----------
add_dnssub() {
    local SUBD
    while :; do
        echo -ne "${BL}│ ${WH}SlowDNS nameserver${NC} ${YL}(NS record, e.g. ns.$DOMAIN; leave empty to skip slowdns)${NC}: " >&3
        read -r SUBD < /dev/tty
        if [ -z "$SUBD" ]; then
            echo -e "${YL}[ INFO ]${NC} SlowDNS skipped." >&3
            return 0
        fi
        SUBD=$(echo "$SUBD" | tr '[:upper:]' '[:lower:]' | xargs)
        [[ "$SUBD" =~ ^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$ ]] && break
        echo -e "${RD}[ ERROR ]${NC} Invalid NS domain" >&3
    done
    echo "$SUBD" > /etc/xray/dns
    echo -e "${GR}[ OK ]${NC} SlowDNS NS = $SUBD (create an NS record pointing to $MYIP)" >&3
}

# ---------- telegram notification config (optional) ----------
setup_telegram() {
    local TGBOT TGCHAT TGSET
    echo "" >&3
    echo -ne "${BL}│ ${WH}Telegram notification panel (optional)${NC}: ${YL}enable? [y/n]${NC} " >&3
    read -r TGSET < /dev/tty
    if [[ "$TGSET" == "y" || "$TGSET" == "Y" ]]; then
        echo -ne "${BL}│ ${WH}Bot token${NC}: " >&3
        read -r TGBOT < /dev/tty
        echo -ne "${BL}│ ${WH}Chat/Admin ID${NC}: " >&3
        read -r TGCHAT < /dev/tty
        if [[ -n "$TGBOT" && -n "$TGCHAT" ]]; then
            echo "$TGBOT" > /etc/funny/.keybot
            echo "$TGCHAT" > /etc/funny/.chatid
            cat >/etc/mlak/var.txt <<EOF
BOT_TOKEN="$TGBOT"
ADMIN="$TGCHAT"
EOF
            echo -e "${GR}[ OK ]${NC} Telegram notification enabled" >&3
        fi
    fi
}

# ---------- server info files (used by menus) ----------
write_info() {
    mkdir -p /etc/xray /root
    echo "${CITYGEO:-Unknown}" > /etc/xray/city
    echo "${ISP:-Unknown}" > /etc/xray/isp
    echo "${CITYGEO:-Unknown}" > /root/.city
    echo "${REGION:-Unknown}" > /root/.region
    echo "${ISP:-Unknown}" > /root/.isp
    echo -e "${GR}[ INFO ]${NC} server info files written" >&3
}