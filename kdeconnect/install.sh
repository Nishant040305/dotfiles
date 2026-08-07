#!/usr/bin/env bash
set -euo pipefail

# Install KDE Connect firewall sudoers rule
# Allows the firewall-cmd to run without password prompt on shell startup

DIR="$(cd "$(dirname "$0")" && pwd)"

sudo install -m 440 -o root -g root "$DIR/sudoers-kdeconnect" /etc/sudoers.d/kdeconnect

# Validate the sudoers file
if sudo visudo -c -f /etc/sudoers.d/kdeconnect; then
    echo "[+] Sudoers file valid."
else
    echo "[!] Sudoers syntax error — removing broken file."
    sudo rm /etc/sudoers.d/kdeconnect
    exit 1
fi
