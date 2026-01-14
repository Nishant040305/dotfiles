#!/usr/bin/env bash
# =============================================================================
# Redsocks System-wide Proxy Manager
# =============================================================================
# This script manages system-wide TCP traffic redirection through redsocks,
# enabling transparent proxying for applications that don't support proxy settings.
#
# Installation:
#   sudo install -m 755 -o root -g root ~/.dotfiles/misc/proxyredsocks.zsh /usr/local/sbin/proxyredsocks
#
# Requires:
#   - redsocks service installed and configured
#   - iptables (netfilter)
#   - sudo/root privileges
#   - polkit rules configured (see: 90-proxyredsocks.rules.js)
#
# Usage:
#   proxyredsocks on      - Enable system-wide transparent proxy
#   proxyredsocks off     - Disable system-wide transparent proxy
#   proxyredsocks status  - Check if redsocks service is active
# =============================================================================

set -euo pipefail

# Configuration
PORT=12345              # Redsocks listening port
CHAIN=REDSOCKS          # iptables chain name
SERVICE=redsocks        # systemd service name

case "$1" in

  on)
    # Start the redsocks service
    systemctl start $SERVICE

    # Create or flush the custom iptables chain
    iptables -t nat -N $CHAIN 2>/dev/null || true
    iptables -t nat -F $CHAIN

    # Exclude private/reserved networks from redirection (whitelist)
    # Traffic to these networks bypasses the proxy
    for net in \
      0.0.0.0/8 \
      10.0.0.0/8 \
      127.0.0.0/8 \
      169.254.0.0/16 \
      172.16.0.0/12 \
      192.168.0.0/16 \
      224.0.0.0/4 \
      240.0.0.0/4; do
      iptables -t nat -A $CHAIN -d $net -j RETURN
    done

    # Redirect all other TCP traffic to redsocks port
    iptables -t nat -A $CHAIN -p tcp -j REDIRECT --to-port $PORT
    
    # Link the custom chain to the OUTPUT chain for local traffic
    iptables -t nat -C OUTPUT -p tcp -j $CHAIN 2>/dev/null || \
      iptables -t nat -A OUTPUT -p tcp -j $CHAIN

    # Block QUIC/UDP 443 to prevent direct HTTPS connections bypassing proxy
    iptables -C OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A OUTPUT -p udp --dport 443 -j DROP
    ;;

  off)
    # Remove OUTPUT chain link
    iptables -t nat -D OUTPUT -p tcp -j $CHAIN 2>/dev/null || true
    
    # Flush and remove the custom chain
    iptables -t nat -F $CHAIN 2>/dev/null || true
    iptables -t nat -X $CHAIN 2>/dev/null || true
    
    # Re-enable QUIC/UDP 443
    iptables -D OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || true
    
    # Stop the redsocks service
    systemctl stop $SERVICE
    ;;

  status)
    # Check if redsocks service is running
    systemctl is-active $SERVICE
    ;;

  *)
    echo "Usage: proxyredsocks {on|off|status}"
    exit 1
esac
