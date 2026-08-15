#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE="$SCRIPT_DIR"

SBIN_DIR="/usr/local/sbin"
BIN_DIR="/usr/local/bin"
POLKIT_DIR="/etc/polkit-1/rules.d"
SYSTEMD_DIR="/usr/local/lib/systemd/system"

echo "[*] Installing proxy & redsocks components..."

# Ensure system user 'redsocks' exists
if ! id -u redsocks &>/dev/null; then
    echo "[*] Creating system user 'redsocks'..."
    sudo useradd -r -s /sbin/nologin -d /var/empty redsocks
fi

# Install CLI scripts
sudo install -m755 -o root -g root "$MODULE/script/proxyredsocks.sh" "$SBIN_DIR/proxyredsocks"
sudo install -m755 -o root -g root "$MODULE/script/masquerade.sh" "$SBIN_DIR/masquerade"

# Install polkit rules for passwordless execution
sudo install -m644 -o root -g root "$MODULE/rules/90-proxyredsocks.rules.js" "$POLKIT_DIR/90-proxyredsocks.rules"
sudo install -m644 -o root -g root "$MODULE/rules/90-masquerade.rules.js" "$POLKIT_DIR/90-masquerade.rules"

# Install redsocks configuration template
sudo install -m644 -o root -g root "$MODULE/config/redsocks.conf.template" /etc/redsocks.conf.template

# Ensure an initial /etc/redsocks.conf exists if not present
if [[ ! -f /etc/redsocks.conf ]]; then
    echo "[*] Initializing /etc/redsocks.conf from template..."
    sudo sed 's/__PROXY_IP__/172.31.100.25/g' /etc/redsocks.conf.template | sudo tee /etc/redsocks.conf > /dev/null
    sudo chmod 644 /etc/redsocks.conf
fi

# Install redsocks2 binary and symlinks
sudo install -Dm755 "$MODULE/bin/redsocks2" "$BIN_DIR/redsocks2"
sudo ln -sf redsocks2 "$BIN_DIR/redsocks"

# Install systemd service unit
sudo rm -f /etc/systemd/system/redsocks.service
sudo install -Dm644 "$MODULE/redsocks.service" "$SYSTEMD_DIR/redsocks.service"

# Reload systemd and polkit
sudo systemctl daemon-reload
sudo systemctl enable redsocks.service
sudo systemctl restart polkit

echo "[✓] Installation complete! Ready to use via: proxy redsocks enable"
