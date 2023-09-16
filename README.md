# mullvad-vps-chaining
Use your vps as a Mullvad VPN with additional features using a Wireguard chaining

## Features
- Use vps to connect Mullvad VPN (other wireguard vpns are supported too)
- Use Multi-Hop in your phone (when your mullvad wireguard configuration is set to use Multi-Hop)
- Use Tor-Proxy with Tor Over VPN

## How to install
- Download install.sh to your vps
- Download wireguard configuration file with Mullvad wireGuard configuration file generator. (platform: linux)
- Execute with `sudo bash install.sh` or `chmod +x install.sh; sudo ./install.sh`
- Open the wireguard configuration file and paste it as a reference.
