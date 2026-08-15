MODULE="$HOME/.dotfiles/proxy"

SBIN_DIR="/usr/local/sbin"
BIN_DIR="/usr/local/bin"
POLKIT_DIR="/etc/polkit-1/rules.d"
SYSTEMD_DIR="/etc/systemd/system"

# Install CLI scripts
sudo install -m755 -o root -g root "$MODULE/script/proxyredsocks.sh" "$SBIN_DIR/proxyredsocks"
sudo install -m755 -o root -g root "$MODULE/script/masquerade.sh" "$SBIN_DIR/masquerade"

# Install polkit rules
sudo install -m644 -o root -g root "$MODULE/rules/90-proxyredsocks.rules.js" "$POLKIT_DIR/90-proxyredsocks.rules"
sudo install -m644 -o root -g root "$MODULE/rules/90-masquerade.rules.js" "$POLKIT_DIR/90-masquerade.rules"

# Install redsocks configuration
sudo install -m644 -o root -g root "$MODULE/config/redsocks.conf.template" /etc/redsocks.conf.template

# Install redsocks2
sudo install -Dm755 "$MODULE/bin/redsocks2" "$BIN_DIR/redsocks"

# Install systemd service
sudo install -Dm644 "$MODULE/redsocks.service" "$SYSTEMD_DIR/redsocks.service"

# Start the services
sudo systemctl daemon-reload
sudo systemctl enable redsocks
sudo systemctl restart polkit
