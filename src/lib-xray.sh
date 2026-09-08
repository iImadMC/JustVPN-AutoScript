#!/bin/bash
# ---------- Xray core download + install ----------
install_xray() {
    print_step "Installing Xray-Core"
    local XVER
    XVER=$(curl -s --max-time 30 https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | grep -oE '"tag_name": *"[^"]+"' | head -1 | cut -d'"' -f4)
    [ -z "$XVER" ] && XVER="v26.3.27"
    echo -e "${BL}│ Getting ${WH}$XVER${NC} ..." >&3
    if [ ! -x /usr/local/bin/xray ]; then
        curl -sL --max-time 180 -o /tmp/xray.zip \
            "https://github.com/XTLS/Xray-core/releases/download/${XVER}/Xray-linux-64.zip"
        rm -rf /tmp/xray-core && mkdir -p /tmp/xray-core
        unzip -o -j /tmp/xray-core.zip -d /tmp/xray-core xray geoip.dat geosite.dat >/dev/null 2>&1 \
            || unzip -o -j /tmp/xray.zip -d /tmp/xray-core xray geoip.dat geosite.dat >/dev/null 2>&1
        install -m755 /tmp/xray-core/xray /usr/local/bin/xray
        mkdir -p /usr/local/share/xray
        cp -f /tmp/xray-core/geoip.dat /tmp/xray-core/geosite.dat /usr/local/share/xray/ 2>/dev/null
    fi
    chmod +x /usr/local/bin/xray 2>/dev/null
    echo -e "${GR}[ OK ]${NC} Xray $XVER installed: $(/usr/local/bin/xray version 2>/dev/null | head -1)" >&3
    rm -rf /tmp/xray.zip /tmp/xray-core
}

# ---------- Xray systemd unit ----------
xray_service() {
    cat >/etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/share/xray
Environment=XRAY_LOCATION_ASSET=/usr/local/share/xray
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=51200

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xray.service >/dev/null 2>&1
}

# ---------- Xray config.json (with socks5 inbound added, merged from FN) ----------
xray_config() {
    local UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    cat >/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "error": "/var/log/xray/error.log",
    "access": "/var/log/xray/access.log"
  },
  "api": {
    "services": ["HandlerService", "LoggerService", "StatsService"],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 128,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10000,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": "10001",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          { "id": "${UUID}"
#vless
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10002",
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "${UUID}", "alterId": 0
#vmess
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10003",
      "protocol": "trojan",
      "settings": {
        "clients": [
          { "password": "${UUID}"
#trojanws
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10004",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          { "method": "aes-128-gcm", "password": "${UUID}"
#ssws
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/ss-ws" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10005",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          { "id": "${UUID}"
#vlessgrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10006",
      "protocol": "vmess",
      "settings": {
        "clients": [
          { "id": "${UUID}", "alterId": 0
#vmessgrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10007",
      "protocol": "trojan",
      "settings": {
        "clients": [
          { "password": "${UUID}"
#trojangrpc
          }
        ]
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "trojan-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10008",
      "protocol": "shadowsocks",
      "settings": {
        "clients": [
          { "method": "aes-128-gcm", "password": "${UUID}"
#ssgrpc
          }
        ],
        "network": "tcp,udp"
      },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "ss-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": "10009",
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          { "user": "${UUID}", "pass": "${UUID}"
#socksws
          }
        ]
      },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/socks5" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "inboundTag": ["api"], "outboundTag": "direct", "type": "field" },
      { "type": "field", "outboundTag": "blocked", "protocol": ["bittorrent"] },
      { "type": "field", "outboundTag": "blocked", "ip": ["0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "169.254.0.0/16", "172.16.0.0/12", "192.0.0.0/24", "192.0.2.0/24", "192.168.0.0/16", "198.18.0.0/15", "198.51.100.0/24", "203.0.113.0/24", "::1/128", "fc00::/7", "fe80::/10"] },
      { "type": "field", "outboundTag": "blocked", "domain": ["geosite:category-ads-all"] },
      { "type": "field", "outboundTag": "direct", "network": "tcp,udp" }
    ]
  },
  "dns": {
    "hosts": {
      "dns.google": "8.8.8.8",
      "dns.pub": "119.29.29.29",
      "dns.alidns.com": "223.5.5.5",
      "geosite:category-ads-all": "127.0.0.1"
    },
    "servers": [
      { "address": "https://1.1.1.1/dns-query", "domains": ["geosite:geolocation-!cn"], "expectIPs": ["geoip:!cn"] },
      "8.8.8.8",
      { "address": "114.114.114.114", "port": 53, "domains": ["geosite:cn", "geosite:category-games@cn"], "expectIPs": ["geoip:cn"], "skipFallback": true },
      { "address": "localhost", "skipFallback": true }
    ]
  }
}
EOF
    chmod 644 /etc/xray/config.json
    echo -e "${GR}[ OK ]${NC} /etc/xray/config.json written (9 inbounds, ws+grpc+socks)" >&3
}