#!/bin/bash
# ---------- SlowDNS (dnstt) install ----------
slowdns_setup() {
    local NSDOMAIN
    if [ ! -f /etc/xray/dns ]; then
        echo -e "${YL}[ INFO ]${NC} SlowDNS nameserver not set, skipping" >&3
        return 0
    fi
    NSDOMAIN=$(cat /etc/xray/dns)
    print_step "Setting up SlowDNS (dnstt) NS=$NSDOMAIN"
    if [ ! -x /etc/slowdns/dnstt-server ]; then
        mkdir -p /etc/slowdns /tmp/dnstt_build
        for B in dnstt-server dnstt-client; do
            if ! curl -sL --max-time 120 -o "/tmp/dnstt_build/$B" \
                "https://dnstt.network/$B-linux-amd64"; then
                echo -e "${RD}[ ERROR ]${NC} failed downloading $B" >&3
                return 1
            fi
        done
        chmod +x /tmp/dnstt_build/dnstt-server /tmp/dnstt_build/dnstt-client
        mv /tmp/dnstt_build/dnstt-server /tmp/dnstt_build/dnstt-client /etc/slowdns/
        rm -rf /tmp/dnstt_build
        if [ ! -f /etc/slowdns/server.pub ]; then
            (cd /etc/slowdns && ./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub >/dev/null 2>&1)
        fi
    fi

    cat >/etc/systemd/system/server.service <<EOF
[Unit]
Description=DNSTT Server (SlowDNS - JustVPN)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/dnstt-server -udp :5300 -privkey-file /etc/slowdns/server.key $NSDOMAIN 127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    cat >/etc/systemd/system/client.service <<EOF
[Unit]
Description=DNSTT Client (SlowDNS - JustVPN)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/etc/slowdns/dnstt-client -udp 8.8.8.8:53 -pubkey-file /etc/slowdns/server.pub $NSDOMAIN 127.0.0.1:8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable server.service >/dev/null 2>&1
    systemctl enable client.service >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} SlowDNS services ready (public key in /etc/slowdns/server.pub)" >&3
}