#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "[-] Please run as root"
  exit
fi

echo "[!] Installing Dependencies"
apt-get install -y wireguard resolvconf

read -rp "[?] Mullvad Client Private Key (PrivateKey = ...): " -e MULLVAD_CLIENT_PRIVATE_KEY # Can extract from mullvad wireguard config file; PrivateKey = ...; AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
read -rp "[?] Mullvad Client Public Key: " -e -i $(echo $MULLVAD_CLIENT_PRIVATE_KEY | wg pubkey) MULLVAD_CLIENT_PUBLIC_KEY
read -rp "[?] Mullvad Server Public Key (PublicKey = ...): " -e MULLVAD_SERVER_PUBLIC_KEY # Can extract from mullvad wireguard config file; PublicKey = ...;  AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
read -rp "[?] Mullvad Server DNS: " -e -i "10.64.0.1" MULLVAD_SERVER_DNS
read -rp "[?] Mullvad Internal Address (Address = ...): " -e MULLVAD_INTERNAL_ADDRESS # Can extract from mullvad wireguard config file; Address = ...; 10.11.12.13/32
read -rp "[?] Mullvad External Endpoint (Endpoint = ...): " -e MULLVAD_EXTERNAL_ENDPOINT # Can extract from mullvad wireguard config file; Endpoint = ...; 1.2.3.4:51820
read -rp "[?] Local Client Private Key: " -e -i $(wg genkey) LOCAL_CLIENT_PRIVATE_KEY
read -rp "[?] Local Client Public Key: " -e -i $(echo $LOCAL_CLIENT_PRIVATE_KEY | wg pubkey) LOCAL_CLIENT_PUBLIC_KEY
read -rp "[?] Local Server Address: " -e -i $(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1) LOCAL_SERVER_ADDRESS
read -rp "[?] Local Server Listening Port: " -e -i "51820" LOCAL_SERVER_LISTENING_PORT
read -rp "[?] Local Server Listening Address: " -e -i "10.10.10.10/32" LOCAL_SERVER_LISTENING_ADDRESS

read -rp "[?] Enable Tor? (y/n): " -e -i "y" TOR_ENABLE
if [[ "$TOR_ENABLE" == "y" ]]; then
  echo "[!] Installing Tor"
  apt-get install -y tor
  echo "[!] Set Tor SocksPort to $(echo $MULLVAD_INTERNAL_ADDRESS | cut -d/ -f1):9050"
  mv -f /etc/tor/torrc /etc/tor/torrc.bak
  echo "SocksPort $(echo $MULLVAD_INTERNAL_ADDRESS | cut -d/ -f1):9050" > /etc/tor/torrc
  echo "[!] Restarting Tor"
  systemctl restart tor
  echo "[+] You can connect to Tor with socks5 proxy at $(echo $MULLVAD_INTERNAL_ADDRESS | cut -d/ -f1):9050 when vpn connected"
fi


echo "[!] Wireguard Setup"
echo "[Interface]
PrivateKey = $MULLVAD_CLIENT_PRIVATE_KEY
Address = $MULLVAD_INTERNAL_ADDRESS
DNS = $MULLVAD_SERVER_DNS
PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -I OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -D OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT

ListenPort = $LOCAL_SERVER_LISTENING_PORT
PostUp = echo 1 > /proc/sys/net/ipv4/ip_forward
PostUp = iptables -t nat -A POSTROUTING -s $(echo $LOCAL_SERVER_LISTENING_ADDRESS | cut -d/ -f1) -j SNAT --to-source $(echo $MULLVAD_INTERNAL_ADDRESS | cut -d/ -f1)
PostUp = iptables -I OUTPUT -p udp --dport \$(wg show %i listen-port) -j ACCEPT && ip6tables -I OUTPUT -p udp --dport \$(wg show %i listen-port) -j ACCEPT
PreDown = iptables -D OUTPUT -p udp --dport \$(wg show %i listen-port) -j ACCEPT && ip6tables -D OUTPUT -p udp --dport \$(wg show %i listen-port) -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $(echo $LOCAL_SERVER_LISTENING_ADDRESS | cut -d/ -f1) -j SNAT --to-source $(echo $MULLVAD_INTERNAL_ADDRESS | cut -d/ -f1)
PostDown = echo 0 > /proc/sys/net/ipv4/ip_forward

[Peer]
PublicKey = $MULLVAD_SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $MULLVAD_EXTERNAL_ENDPOINT

[Peer]
PublicKey = $LOCAL_CLIENT_PUBLIC_KEY
AllowedIps = $LOCAL_SERVER_LISTENING_ADDRESS" > /etc/wireguard/wg0.conf


WIREGUARD_CONFIG="[Interface]
PrivateKey = $LOCAL_CLIENT_PRIVATE_KEY
Address = $LOCAL_SERVER_LISTENING_ADDRESS
DNS = $MULLVAD_SERVER_DNS

# If you are on Linux uncomment it to enable Kill Switch feature
# PostUp = iptables -I OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -I OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
# PreDown = iptables -D OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT && ip6tables -D OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT

[Peer]
PublicKey = $MULLVAD_CLIENT_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = $LOCAL_SERVER_ADDRESS:$LOCAL_SERVER_LISTENING_PORT"

echo "$WIREGUARD_CONFIG" > wireguard.conf
echo "[+] Wireguard config file to connect VPS
# Save this file to your local machine and connect with wireguard'
$WIREGUARD_CONFIG
"

echo "[!] Firewall Setup"
# ufw allow 51820/udp
# ufw allow from 10.0.0.0/8
ufw disable

echo "[+] Can destroy ssh connection now. Connect VPN with wireguard config and then connect ssh with $MULLVAD_INTERNAL_ADDRESS"
systemctl enable --now wg-quick@wg0
