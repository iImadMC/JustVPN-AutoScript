#!/bin/bash
# ---------- SSH config (ports 22/2222/2223) ----------
ssh_config() {
    print_step "Configuring OpenSSH"
    cat >/etc/ssh/sshd_config <<'EOF'
Port 22
Port 2222
Port 2223
Port 53
#AddressFamily any
#ListenAddress 0.0.0.0
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowTcpForwarding yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/banner
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
    echo -e "${GR}[ OK ]${NC} OpenSSH ports 22/2222/2223/53 (53 = JIO5G no payload)" >&3
}

# ---------- Dropbear (143 + 109) ----------
dropbear_config() {
    cat >/etc/default/dropbear <<'EOF'
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RECEIVE_WINDOW=65536
EOF
    mkdir -p /etc/dropbear
    systemctl daemon-reload
    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear 2>/dev/null || true
    echo -e "${GR}[ OK ]${NC} Dropbear ports 143/109" >&3
}

# ---------- Banner (post-login dynamic message is in /etc/profile.d) ----------
write_banner() {
    cat >/etc/banner <<EOF
≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
        JUSTVPN   |   PREMIUM VPN
        $(cat /etc/xray/domain 2>/dev/null)
≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
EOF
    cat >/etc/profile.d/justvpn-motd.sh <<'MOTDEOF'
#!/bin/bash
NC='\033[0m'; CY='\033[1;36m'; WH='\033[1;37m'
if [[ "${SSH_CONNECTION:-}" != "" ]] && [[ -t 1 ]] && [[ "$(whoami)" != "root" ]]; then
    U=$(whoami)
    EXP=""
    LE=$(grep -E "^### ${U} " /etc/ssh/.ssh.db 2>/dev/null | head -1 | awk '{print $3}')
    [ -z "$LE" ] && for F in /etc/vmess/.vmess.db /etc/vless/.vless.db /etc/trojan/.trojan.db /etc/shadowsocks/.shadowsocks.db /etc/socks/.socks.db; do
        LE=$(grep -E "^### ${U} " "$F" 2>/dev/null | head -1 | awk '{print $3}'); [ -n "$LE" ] && break
    done
    if [ -n "$LE" ]; then
        LEFT=$(( ($(date -d "$LE" +%s) - $(date +%s)) / 86400 ))
        [ "$LEFT" -lt 0 ] && LEFT=0
        EXP="${LEFT} days (${LE})"
    else
        EXP="unlimited"
    fi
    Q=$(cat /etc/xray/quota/$U 2>/dev/null)
    [ -z "$Q" ] && Q=0
    if [ "$Q" -gt 0 ]; then
        GB=$(awk "BEGIN{printf \"%.0f\", $Q/1073741824}")
        [ "$GB" -ge 1000 ] && BWD="$(awk "BEGIN{printf \"%.1f\", $GB/1000}")T" || BWD="${GB}Gb"
    else
        BWD="Unlimited"
    fi
    DOM=$(cat /etc/xray/domain 2>/dev/null)
    echo -e "${CY}┌──────────────────────────────────────────────┐${NC}"
    echo -e "${WH}│${NC} ${CY}JustVPN${NC} ${WH}›${NC} ${YL}PREMIUM VPN${NC}              ${WH}│${NC}"
    echo -e "${WH}├──────────────────────────────────────────────┤${NC}"
    echo -e "${CY} Logins:      ${WH}1/100${NC}"
    echo -e "${CY} Expire in:   ${WH}${EXP}${NC}"
    echo -e "${CY} Username:    ${WH}${U}${NC}"
    echo -e "${CY} Bandwidth:   ${WH}${BWD}${NC}"
    echo -e "${WH}├──────────────────────────────────────────────┤${NC}"
    echo -e "                ${CY}script.$DOM${NC}"
    echo -e "${CY}└──────────────────────────────────────────────┘${NC}"
fi
MOTDEOF
    chmod +x /etc/profile.d/justvpn-motd.sh 2>/dev/null
}

# ---------- Squid proxy (3128) ----------
squid_config() {
    local MYIP
    MYIP=$(wget -qO- ipinfo.io/ip 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null)
    cat >/etc/squid/squid.conf <<EOF
# Squid Configuration - JustVPN
acl manager proto cache_object
acl localhost src 127.0.0.1/32 ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl SSL_ports port 1-65535
acl Safe_ports port 1-65535
acl CONNECT method CONNECT
acl SSH dst $MYIP
http_access allow SSH
http_access allow manager localhost
http_access deny manager
http_access allow localhost
http_access deny all
http_port 3128
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname $(cat /etc/xray/domain)
EOF
    systemctl daemon-reload
    systemctl enable squid >/dev/null 2>&1
    systemctl restart squid 2>/dev/null || true
    echo -e "${GR}[ OK ]${NC} Squid proxy port 3128" >&3
}

# ---------- Python3 SSH/OVPN websocket proxy ----------
write_ws_py() {
    cat >/usr/bin/ws.py <<'PYEOF'
#!/usr/bin/env python3
import socket, threading, select, sys, time

LISTENING_ADDR = '0.0.0.0'
LISTENING_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 10015
DEFAULT_HOST = sys.argv[2] if len(sys.argv) > 2 else '127.0.0.1:22'
PASS = ''
BUFLEN = 4096 * 4
TIMEOUT = 60
RESPONSE = b'HTTP/1.1 101 Switching Protocol\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: foo\r\n\r\n'

class Server(threading.Thread):
    def __init__(self, host, port):
        threading.Thread.__init__(self)
        self.running = False
        self.host = host
        self.port = port
        self.threads = []
        self.threadsLock = threading.Lock()
        self.logLock = threading.Lock()

    def run(self):
        self.soc = socket.socket(socket.AF_INET)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.soc.settimeout(2)
        self.soc.bind((self.host, int(self.port)))
        self.soc.listen(0)
        self.running = True
        try:
            while self.running:
                try:
                    c, addr = self.soc.accept()
                    c.setblocking(1)
                except socket.timeout:
                    continue
                conn = ConnectionHandler(c, self, addr)
                conn.start()
                self.addConn(conn)
        finally:
            self.running = False
            self.soc.close()

    def printLog(self, log):
        with self.logLock:
            print(log, flush=True)

    def addConn(self, conn):
        with self.threadsLock:
            if self.running:
                self.threads.append(conn)

    def removeConn(self, conn):
        with self.threadsLock:
            if conn in self.threads:
                self.threads.remove(conn)

    def close(self):
        self.running = False
        with self.threadsLock:
            threads = list(self.threads)
            for c in threads:
                c.close()

class ConnectionHandler(threading.Thread):
    def __init__(self, socClient, server, addr):
        threading.Thread.__init__(self)
        self.clientClosed = False
        self.targetClosed = True
        self.client = socClient
        self.client_buffer = b''
        self.server = server

    def close(self):
        try:
            if not self.clientClosed:
                self.client.shutdown(socket.SHUT_RDWR)
                self.client.close()
        except Exception:
            pass
        finally:
            self.clientClosed = True
        try:
            if not self.targetClosed:
                self.target.shutdown(socket.SHUT_RDWR)
                self.target.close()
        except Exception:
            pass
        finally:
            self.targetClosed = True

    def run(self):
        try:
            self.client_buffer = self.client.recv(BUFLEN)
            hostPort = self.findHeader(self.client_buffer, 'X-Real-Host')
            if hostPort == '':
                hostPort = DEFAULT_HOST
            split = self.findHeader(self.client_buffer, 'X-Split')
            if split != '':
                self.client.recv(BUFLEN)
            if hostPort != '':
                passwd = self.findHeader(self.client_buffer, 'X-Pass')
                if len(PASS) != 0 and passwd == PASS:
                    self.method_CONNECT(hostPort)
                elif len(PASS) != 0 and passwd != PASS:
                    self.client.send(b'HTTP/1.1 400 WrongPass!\r\n\r\n')
                elif hostPort.startswith('127.0.0.1') or hostPort.startswith('localhost'):
                    self.method_CONNECT(hostPort)
                else:
                    self.client.send(b'HTTP/1.1 403 Forbidden!\r\n\r\n')
            else:
                self.client.send(b'HTTP/1.1 400 NoXRealHost!\r\n\r\n')
        except Exception as e:
            msg = getattr(e, 'strerror', None) or str(e)
            self.server.printLog('- error: ' + msg)
        finally:
            self.close()
            self.server.removeConn(self)

    def findHeader(self, head, header):
        aux = head.find(header.encode('utf-8') + b': ')
        if aux == -1:
            return ''
        aux = head.find(b':', aux)
        head = head[aux + 2:]
        aux = head.find(b'\r\n')
        if aux == -1:
            return ''
        try:
            return head[:aux].decode('utf-8')
        except Exception:
            return ''

    def connect_target(self, host):
        i = host.find(':')
        if i != -1:
            port = int(host[i + 1:])
            host = host[:i]
        else:
            port = 22
        (soc_family, soc_type, proto, _, address) = socket.getaddrinfo(host, port)[0]
        self.target = socket.socket(soc_family, soc_type, proto)
        self.targetClosed = False
        self.target.connect(address)

    def method_CONNECT(self, path):
        self.connect_target(path)
        self.client.sendall(RESPONSE)
        self.client_buffer = b''
        self.doCONNECT()

    def doCONNECT(self):
        socs = [self.client, self.target]
        count = 0
        error = False
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                error = True
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is self.target:
                                self.client.send(data)
                            else:
                                while data:
                                    byte = self.target.send(data)
                                    data = data[byte:]
                            count = 0
                        else:
                            break
                    except Exception:
                        error = True
                        break
            if count == TIMEOUT:
                error = True
            if error:
                break

if __name__ == '__main__':
    server = Server(LISTENING_ADDR, LISTENING_PORT)
    server.start()
    while True:
        time.sleep(2)
PYEOF
    chmod +x /usr/bin/ws.py
}

ws_services() {
    cat >/etc/systemd/system/ws.service <<'EOF'
[Unit]
Description=SSH Websocket (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/bin/ws.py 10015 127.0.0.1:22
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    cat >/etc/systemd/system/wsovpn.service <<'EOF'
[Unit]
Description=OpenVPN Websocket (JustVPN)
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/bin/ws.py 10012 127.0.0.1:1194
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ws.service >/dev/null 2>&1
    systemctl enable wsovpn.service >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} WS python3 services (10015 ssh / 10012 ovpn)" >&3
}

# ---------- tun.conf (informational) ----------
write_tunconf() {
    cat >/etc/slowdns/tun.conf <<EOF
# verbose level 0=info, 1=verbose, 2=very verbose
verbose: 0
listen:

# // SSH
- target_host: 127.0.0.1
  target_port: 22
  listen_port: 10015

# // OpenVPN
- target_host: 127.0.0.1
  target_port: 1194
  listen_port: 10012
EOF
}

# ---------- OpenVPN (TCP 1194 / UDP 2200) with generated CA ----------
openvpn_setup() {
    print_step "Setting up OpenVPN"
    local DOMAIN PLUGIN
    DOMAIN=$(cat /etc/xray/domain)
    PLUGIN=$(ls /usr/lib/*/openvpn/plugins/openvpn-plugin-auth-pam.so 2>/dev/null | head -1)
    [ -z "$PLUGIN" ] && PLUGIN="/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"

    mkdir -p /etc/openvpn /var/www/html
    # self-contained CA (no external downloads)
    if [ ! -f /etc/openvpn/ca.crt ]; then
        openssl genrsa -out /etc/openvpn/ca.key 2048 >/dev/null 2>&1
        openssl req -x509 -new -key /etc/openvpn/ca.key -days 3650 -sha256 \
            -subj "/C=ID/ST=JustVPN/L=JustVPN/O=JustVPN/CN=JustVPN-CA" \
            -out /etc/openvpn/ca.crt >/dev/null 2>&1
        openssl genrsa -out /etc/openvpn/server.key 2048 >/dev/null 2>&1
        openssl req -new -key /etc/openvpn/server.key \
            -subj "/CN=$DOMAIN" -out /etc/openvpn/server.csr >/dev/null 2>&1
        openssl x509 -req -in /etc/openvpn/server.csr -CA /etc/openvpn/ca.crt \
            -CAkey /etc/openvpn/ca.key -CAcreateserial -days 3650 -sha256 \
            -out /etc/openvpn/server.crt >/dev/null 2>&1
        openssl dhparam -out /etc/openvpn/dh.pem 2048 2>/dev/null &
        dhpw=$!
        sleep 1
        wait $dhpw 2>/dev/null
    fi

    cat >/etc/openvpn/server-tcp.conf <<EOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
verify-client-cert none
username-as-common-name
plugin $PLUGIN login
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "route-method exe"
push "route-delay 2"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
management 127.0.0.1 5555
status server-tcp.log
log log-tcp.log
verb 3
cipher none
auth none
EOF

    cat >/etc/openvpn/server-udp.conf <<EOF
port 2200
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
verify-client-cert none
username-as-common-name
plugin $PLUGIN login
server 20.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "route-method exe"
push "route-delay 2"
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status server-udp.log
log log-udp.log
verb 3
cipher none
auth none
EOF

    for V in tcp udp ssl ws-ssl; do
        case $V in
            tcp) PORT=1194; PROTO=tcp; EXTRA="" ;;
            udp) PORT=2200; PROTO=udp; EXTRA="" ;;
            ssl) PORT=443;  PROTO=tcp; EXTRA="" ;;
            ws-ssl) PORT=443; PROTO=tcp; EXTRA="socks" ;;
        esac
        cat >/etc/openvpn/$V.ovpn <<EOF
auth-user-pass
client
dev tun
proto $PROTO
remote $DOMAIN $PORT
persist-key
persist-tun
pull
resolv-retry infinite
nobind
user nobody
comp-lzo
remote-cert-tls server
verb 3
mute 2
connect-retry 5 5
connect-retry-max 8080
mute-replay-warnings
redirect-gateway def1
script-security 2
cipher none
auth none
EOF
        if [ "$V" = "ws-ssl" ]; then
            sed -i '/proto tcp/a http-proxy 127.0.0.1 80\nhttp-proxy-retry\n# ws tunnel: route via https port 443 using websocket' /etc/openvpn/$V.ovpn
        fi
        echo "<ca>" >>/etc/openvpn/$V.ovpn
        cat /etc/openvpn/ca.crt >>/etc/openvpn/$V.ovpn
        echo "</ca>" >>/etc/openvpn/$V.ovpn
        cp /etc/openvpn/$V.ovpn /var/www/html/$V.ovpn
    done
    cd /var/www/html && zip -q all-ovpn.zip tcp.ovpn udp.ovpn ssl.ovpn ws-ssl.ovpn 2>/dev/null; cd /
    sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/' /etc/default/openvpn
    systemctl daemon-reload
    systemctl enable openvpn@server-tcp >/dev/null 2>&1
    systemctl enable openvpn@server-udp >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} OpenVPN TCP 1194 / UDP 2200 (certs generated locally)" >&3
}

# ---------- BBR + sysctl ----------
bbrypt() {
    print_step "Enabling BBR + system tuning"
    cat >/etc/sysctl.conf <<EOF
net.core.default_qdisc=cake
net.ipv4.tcp_congestion_control=bbr
net.ipv4.ip_forward=1
fs.file-max=65535000
fs.inotify.max_user_instances=8192
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.somaxconn=65535
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 87380 134217728
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_max_syn_backlog=10240
net.core.netdev_max_backlog=10240
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_mtu_probing=1
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
    sysctl -p >/dev/null 2>&1
    sysctl --system >/dev/null 2>&1
    echo -e "${GR}[ OK ]${NC} BBR + tuning applied" >&3
}

# ---------- rc-local ----------
rc_local() {
    cat >/etc/rc.local <<EOF
#!/bin/bash
# JustVPN rc.local
exit 0
EOF
    chmod +x /etc/rc.local
    cat >/etc/systemd/system/rc-local.service <<'EOF'
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=oneshot
ExecStart=/etc/rc.local
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable rc-local >/dev/null 2>&1
    systemctl start rc-local 2>/dev/null || true
}

# ---------- iptables (server ports + torrent drop + dns redirect) ----------
iptables_rules() {
    print_step "Writing iptables rules"
    local IFACE
    IFACE=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    [ -z "$IFACE" ] && IFACE="eth0"
    mkdir -p /etc/iptables
    cat >/etc/iptables/rules.v4 <<END
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -p tcp -m tcp --dport 10015 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10012 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10011 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10009 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10008 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10007 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10006 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10005 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10004 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10003 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10002 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10001 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 10000 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 3128 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 1194 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 222 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 777 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2223 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2222 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 143 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 109 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 169 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 88 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 81 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 55 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2086 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8880 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 68 -j ACCEPT
-A INPUT -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --dport 2200 -j ACCEPT
-A INPUT -p udp -m udp --dport 2100 -j ACCEPT
-A INPUT -p udp -m udp --dport 5300 -j ACCEPT
-A INPUT -p udp -m udp --dport 7100 -j ACCEPT
-A INPUT -p udp -m udp --dport 7200 -j ACCEPT
-A INPUT -p udp -m udp --dport 7300 -j ACCEPT
-A FORWARD -m string --string "BitTorrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "BitTorrent protocol" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "peer_id=" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string ".torrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "announce.php?passkey=" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "torrent" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "announce" --algo bm --to 65535 -j DROP
-A FORWARD -m string --string "info_hash" --algo bm --to 65535 -j DROP
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A PREROUTING -i $IFACE -p udp -m udp --dport 53 -j REDIRECT --to-ports 5300
-A POSTROUTING -s 10.8.0.0/24 -o $IFACE -j MASQUERADE
-A POSTROUTING -s 20.8.0.0/24 -o $IFACE -j MASQUERADE
COMMIT
END
    cat >/etc/iptables/rules.v6 <<'END'
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
END
    systemctl enable netfilter-persistent >/dev/null 2>&1
    netfilter-persistent reload >/dev/null 2>&1 || iptables-restore < /etc/iptables/rules.v4 2>/dev/null
    echo -e "${GR}[ OK ]${NC} iptables rules applied" >&3
}