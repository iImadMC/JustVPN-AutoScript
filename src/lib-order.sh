#!/bin/bash
# ---------- start all enabled services ----------
start_all() {
    print_step "Starting all JustVPN services"
    for s in ssh dropbear squid xray nginx haproxy ws wsovpn stunnel4 \
        openvpn@server-tcp openvpn@server-udp xlimitd \
        rc-local server client badvpn1 badvpn2 badvpn3; do
        systemctl enable "$s" >/dev/null 2>&1
        systemctl start "$s" >/dev/null 2>&1
        if systemctl is-active "$s" 2>/dev/null | grep -q active; then
            echo -e "  ${GR}●${NC} $s ${Green}active${NC}" >&3
        else
            echo -e "  ${RD}○${NC} $s ${RED}failed${NC} (see /var/log/justvpn-setup.log)" >&3
        fi
    done
}

# ---------- final summary panel ----------
install_finish() {
    local DOMAIN NS PUB
    DOMAIN=$(cat /etc/xray/domain 2>/dev/null)
    NS=$(cat /etc/xray/dns 2>/dev/null)
    PUB=$(cat /etc/slowdns/server.pub 2>/dev/null)
    clear >&3
    echo "" >&3
    echo -e "$BL ╭──────────────────────────────────────────────────╮$NC" >&3
    echo -e "$BL │${NC}  ${GR}✓ INSTALL SUCCESSFUL — JustVPN${NC}             $BL│$NC" >&3
    echo -e "$BL ├──────────────────────────────────────────────────┤$NC" >&3
    echo -e "$BL │${NC}  Domain        : ${CY}${DOMAIN}${NC}                     $BL│$NC" >&3
    echo -e "$BL │${NC}  SSH           : 22, 2222, 2223, 53. Dropbear 143, 109 $BL│$NC" >&3
    echo -e "$BL │${NC}  Stunnel       : 777 (ssh), 222 (dropbear)             $BL│$NC" >&3
    echo -e "$BL │${NC}  WS            : 80, 443 (ssh-ws / vmess / vless /$BL│$NC" >&3
    echo -e "$BL │${NC}                  trojan / ss / socks5 path)        $BL│$NC" >&3
    echo -e "$BL │${NC}  XRay gRPC     : 443 (vless/vmess/trojan/ss grpc)  $BL│$NC" >&3
    echo -e "$BL │${NC}  Other http    : 55, 8080, 2086, 8880 (same as 80) $BL│$NC" >&3
    echo -e "$BL │${NC}  UDPGW BadVPN  : 7100, 7200, 7300                 $BL│$NC" >&3
    echo -e "$BL │${NC}  OpenVPN       : TCP 1194, UDP 2200, SSL 443       $BL│$NC" >&3
    echo -e "$BL │${NC}  Squid proxy   : 3128                             $BL│$NC" >&3
    echo -e "$BL │${NC}  SlowDNS NS    : ${NS:-none}${NC}  port 53               $BL│$NC" >&3
    echo -e "$BL │${NC}  SlowDNS Pub   : ${PUB:-none}${NC}" >&3
    echo -e "$BL ├──────────────────────────────────────────────────┤$NC" >&3
    echo -e "$BL │${NC}  MENU : ${WH}menu${NC}  (or ssh / vmess / trojan...) $BL│$NC" >&3
    echo -e "$BL │${NC}  Panel: ${CY}https://${DOMAIN}:81${NC} (info + ovpn zip) $BL│$NC" >&3
    echo -e "$BL │${NC}  Text : ${CY}https://${DOMAIN}:81/justvpn-USER.txt${NC}  $BL│$NC" >&3
    echo -e "$BL │${NC}  Backups in /root/backup (backup / restore / backup-gd)$BL│$NC" >&3
    echo -e "$BL ╰──────────────────────────────────────────────────╯$NC" >&3
    echo -e "${GR}  Reboot recommended to finalize. Type 'menu' after reboot.${NC}" >&3
    echo "" >&3
}

# ---------- main install ----------
main() {
    banner
    is_root
    check_ubuntu_version
    check_vz
    make_folder_xray

    updatePackages
    insDepedency

    add_domain
    write_info
    add_dnssub
    setup_telegram

    install_xray
    xray_service
    xray_config
    issue_cert
    haproxy_conf

    ssh_config
    dropbear_config
    write_banner
    squid_config
    write_ws_py
    write_tunconf
    ws_services
    openvpn_setup
    bbrypt
    rc_local
    iptables_rules

    nginx_conf
    nginx_vhosts
    nginx_service

    slowdns_setup
    install_badvpn
    badvpn_services
    stunnel_config

    install_xvn
    install_wrappers
    install_managers
    install_menu
    install_xp
    install_xraylimit
    install_kills
    install_seres
    install_run
    install_uninstall
    install_msettings
    install_tasket
    install_logclean
    install_speedtest_tool
    install_autoreboot
    install_dnschanger
    install_bbrplus
    install_backup
    install_backup_gd
    install_daemons
    install_cron

    start_all
    install_finish
}

main "$@"