#!/bin/bash
# Role-based UFW firewall rules applied on vpn-gw

sudo ufw default deny incoming
sudo ufw default deny routed
sudo ufw default allow outgoing

# WireGuard VPN entry on outer interface (enp0s1)
sudo ufw allow in on enp0s1 to any port 51820 proto udp

# Management SSH from host MacBook only (blocks external client VM outside VPN)
sudo ufw allow in on enp0s1 from 192.168.64.1 to any port 22 proto tcp

# Admin-only SSH over WireGuard VPN (developers .2 and .3 are blocked)
sudo ufw allow in on wg0 from 172.28.20.10 to any port 22 proto tcp

# Allow VPN users to reach ONLY gitlab (172.28.10.10) on ports 443 (HTTPS) and 22 (Git SSH)
sudo ufw route allow in on wg0 out on enp0s2 from 172.28.20.0/24 to 172.28.10.10 port 443 proto tcp
sudo ufw route allow in on wg0 out on enp0s2 from 172.28.20.0/24 to 172.28.10.10 port 22 proto tcp

# Allow gitlab to SCP daily backups off-machine to vpn-gw over private interface (enp0s2)
sudo ufw allow in on enp0s2 from 172.28.10.10 to any port 22 proto tcp

sudo ufw --force enable
sudo ufw status numbered
