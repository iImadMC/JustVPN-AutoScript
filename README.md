# JustVPN

Premium VPN autoscript for Ubuntu 20.04 / 22.04 / 24.04 (x64).

## Install

```bash
curl -fsSL <raw-url-to-setup.sh> -o setup.sh && bash setup.sh
```

## Services & Ports

| Service | Port |
|---|---|
| OpenSSH | 22, 2222, 2223, 53 (JIO5G no payload) |
| Dropbear | 109, 143 |
| SSH Websocket | 80, 443 |
| Stunnel4 (SSL) | 222 (dropbear), 777 (ssh) |
| BadVPN UDPGW | 7100, 7200, 7300 |
| Nginx Panel | 81 |
| Vmess / Vless / Trojan / Shadowsocks WS | TLS 443, none-TLS 80 |
| Vmess / Vless / Trojan / Shadowsocks gRPC | 443 |
| OpenVPN | TCP 1194, UDP 2200 |
| Squid Proxy | 3128 |
| SlowDNS (dnstt) | UDP 53 |

## Features

- Unified premium CLI menus (`menu`)
- Account managers: SSH / Vmess / Vless / Trojan / Shadowsocks / Socks5
- Quota + IP-limit enforcement daemon (xlimitd)
- Auto-delete expired users (cron)
- Daily auto backup
- Speedtest (Ookla), Set Auto Reboot, DNS Changer
- BBR + kernel tuning (optional BBRPLUS v1.4.0)
- Telegram notifications
- Backup / Restore / Google Drive

## Build

```bash
bash build.sh   # concatenates src/*.sh into setup.sh + syntax check
```

## Notes

- Requires a domain pointed to the server for Xray + SSL (letsencrypt).
- SlowDNS requires a registered NS subdomain.