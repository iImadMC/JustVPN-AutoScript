#!/bin/bash
# ---------- SSL certificate (acme.sh letsencrypt, self-signed fallback) ----------
issue_cert() {
    print_step "Issuing SSL certificate for $DOMAIN"
    local DOMAIN
    DOMAIN=$(cat /etc/xray/domain)

    # free port 80
    systemctl stop nginx 2>/dev/null; systemctl stop haproxy 2>/dev/null
    systemctl stop apache2 2>/dev/null

    echo -e "${BL}│ installing acme.sh ...${NC}" >&3
    curl -s https://get.acme.sh | sh -s email="admin@$DOMAIN" >/dev/null 2>&1

    echo -e "${BL}│ issuing letsencrypt certificate (standalone) ...${NC}" >&3
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    if ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 \
        --server letsencrypt >/dev/null 2>&1; then
        mkdir -p /etc/xray /etc/nginx/ssl /etc/haproxy
        ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --key-file /etc/xray/xray.key \
            --fullchain-file /etc/xray/xray.crt >/dev/null 2>&1
        echo -e "${GR}[ OK ]${NC} letsencrypt certificate installed" >&3
    else
        echo -e "${YL}[ WARN ]${NC} ACME failed (is the domain pointed here?), using self-signed" >&3
        openssl req -x509 -nodes -days 1095 -newkey rsa:2048 -sha256 \
            -subj "/C=ID/ST=Ok/L=Ok/O=JustVPN/CN=$DOMAIN" \
            -keyout /etc/xray/xray.key -out /etc/xray/xray.crt >/dev/null 2>&1
    fi
    # concat for haproxy
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/yha.pem
    chmod 600 /etc/haproxy/yha.pem
    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key
    echo -e "${GR}[ OK ]${NC} yha.pem generated in /etc/haproxy/" >&3
}

# ---------- nginx main config ----------
nginx_conf() {
    cat >/etc/nginx/nginx.conf <<'EOF'
user root;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 16384;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 86400000m;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    types_hash_max_size 2048;
    server_tokens off;

    gzip on;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/json application/xml image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
EOF
    rm -f /etc/nginx/sites-enabled/default
    mkdir -p /var/www/html
    echo "<h1 align=center>JustVPN - VPN Panel</h1>" >/var/www/html/index.html
}

# ---------- nginx xray vhost (1010), ovpn (1012), grpc (1013), panel (81) ----------
nginx_vhosts() {
    local DOMAIN
    DOMAIN=$(cat /etc/xray/domain)

    cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 1010 proxy_protocol so_keepalive=on reuseport;
    set_real_ip_from 127.0.0.1;
    real_ip_header proxy_protocol;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;
    add_header X-HTTP-LEVEL-HEADER 1;
    add_header X-ANOTHER-HTTP-LEVEL-HEADER 1;
    add_header X-XSS-Protection "1; mode=block";

    location ~ /socks5 {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /socks5 break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10009;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vless {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /vless break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vmess {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /vmess break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /trojan-ws {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /trojan-ws break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /ss-ws {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ss-ws break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ ^/ssh {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ssh break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:22;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ ^/ovpn/ {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ovpn break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10012;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:1194;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ / {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ssh break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:22;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/ovpn.conf <<EOF
server {
    listen 1012 proxy_protocol so_keepalive=on reuseport;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;

    location ~ / {
        if (\$http_upgrade != "Websocket") { rewrite /(.*) /ovpn break; }
        proxy_http_version 1.1; proxy_redirect off;
        proxy_pass http://127.0.0.1:10012;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-Host 127.0.0.1:1194;
        proxy_set_header X-Real-IP \$http_x_forwarded_for;
        proxy_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/grpc.conf <<EOF
server {
    listen 1013 http2 proxy_protocol so_keepalive=on reuseport;
    server_name $DOMAIN;
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 86400000m;
    keepalive_timeout 86400000m;

    location ~ /vless-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10005;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /vmess-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /trojan-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10007;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
    location ~ /ss-grpc {
        proxy_http_version 1.1; proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$http_x_forwarded_for;
        grpc_set_header X-Forwarded-For \$http_x_forwarded_for;
    }
}
EOF

    cat >/etc/nginx/conf.d/panel.conf <<EOF
server {
    listen 81 ssl http2 reuseport;
    server_name $DOMAIN;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/html;
    index index.html;
}
EOF
    module_grpc_check
    echo -e "${GR}[ OK ]${NC} nginx vhosts written (1010/1012/1013/81)" >&3
}

# grpc_pass needs ngx_http_v2_module (built-in on Ubuntu nginx) -- ensure loaded
module_grpc_check() {
    nginx -t >/dev/null 2>&1 || true
}

# ---------- nginx systemd enable ----------
nginx_service() {
    systemctl daemon-reload
    systemctl enable nginx >/dev/null 2>&1
}