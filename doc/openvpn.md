# Proton VPN / Open VPN

Place your credentials file at: `~/.dotfiles/vpn/.config/openvpn/credentials/vpn.auth`

Format:
```bash
username
password
```

Import an [OVPN file](https://account.protonvpn.com/downloads):
```bash
nmcli connection import type openvpn file "path/to/file.ovpn"
```

After importing, verify proxy and protonvpn credentials are present.
If not, adjust the connection from GNOME settings or nmcli:
```bash
nmcli connection show "connection name" -s
nmcli connection modify "connection name" <key> <value>
```