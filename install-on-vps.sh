#!/bin/sh
apt update && apt upgrade -y
apt install wireguard iptables netfilter-persistent -y
(umask 077 && printf "[Interface]\nPrivateKey= " | tee /etc/wireguard/wg0.conf > /dev/null)
wg genkey | tee -a /etc/wireguard/wg0.conf | wg pubkey | tee /etc/wireguard/publickey
sysctl -w net.ipv4.ip_forward=1 >> /etc/sysctl.conf && sysctl -p && sysctl --system
# By default drop traffic
iptables -P FORWARD DROP

# Allow traffic on specified ports
iptables -A FORWARD -i eth0 -o wg0 -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i eth0 -o wg0 -p tcp --syn --dport 443 -m conntrack --ctstate NEW -j ACCEPT

# Allow traffic between wg0 and eth0
iptables -A FORWARD -i wg0 -o eth0 -m conntrack --cstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i wg0 -o eth0 -m conntrack --cstate ESTABLISHED,RELATED -j ACCEPT

# Forward traffic from eth0 to wg0 on specified ports
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 192.168.4.2
iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j DNAT --to-destination 192.168.4.2

# Forward traffic back to eth0 from wg0 on specified ports
iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 80 -d 192.168.4.2 -j SNAT --to-source 192.168.4.1
iptables -t nat -A POSTROUTING -o wg0 -p tcp --dport 443 -d 192.168.4.2 -j SNAT --to-source 192.168.4.1
apt install iptables-persistent -y
