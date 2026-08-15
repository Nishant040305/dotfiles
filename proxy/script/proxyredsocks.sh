#!/usr/bin/env bash
set -euo pipefail

# Configuration
PORT=12345              # Redsocks listening port
CHAIN=REDSOCKS          # iptables chain name
SERVICE=redsocks        # systemd service name
PROXY_IP="${2:-}"       # Proxy server IP address (passed as argument)

# Reserved/private networks that should bypass the proxy
RESERVED=(
  0.0.0.0/8
  10.0.0.0/8
  100.64.0.0/10         # Tailscale CGNAT range
  127.0.0.0/8
  169.254.0.0/16
  172.16.0.0/12
  192.168.0.0/16
  224.0.0.0/4
  240.0.0.0/4
)

rewrite_conf() {
  if [[ -z "$PROXY_IP" ]]; then
    echo "[!] Usage: proxyredsocks enable <PROXY_IP>"
    exit 1
  fi

  echo "[*] Using proxy http://edcguest:edcguest@$PROXY_IP:3128"

  sed \
    -e "s/__PROXY_IP__/${PROXY_IP}/g" \
    /etc/redsocks.conf.template > /etc/redsocks.conf.new

  mv /etc/redsocks.conf.new /etc/redsocks.conf
}

case "${1:-}" in

  enable)
    # Start the redsocks service
    rewrite_conf
    systemctl start $SERVICE

    # Enable IP forwarding (required for hotspot NAT)
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Create or flush the custom iptables chain
    iptables -t nat -N $CHAIN 2>/dev/null || true
    iptables -t nat -F $CHAIN

    # Bypass all traffic sent through the Tailscale interface
    iptables -t nat -A $CHAIN -o tailscale0 -j RETURN

    # Exclude private/reserved networks from redirection (whitelist)
    # Traffic to these networks bypasses the proxy
<<<<<<< HEAD:proxy/proxyredsocks.sh
    for net in "${RESERVED_NETS[@]}"; do
=======
    for net in "${RESERVED[@]}"; do
>>>>>>> aryan/master:proxy/script/proxyredsocks.sh
      iptables -t nat -A $CHAIN -d $net -j RETURN
    done

    # Redirect all other TCP traffic to redsocks port
    iptables -t nat -A $CHAIN -p tcp -j REDIRECT --to-port $PORT
    
    # Link the custom chain to the OUTPUT chain for local traffic
    iptables -t nat -C OUTPUT -p tcp -j $CHAIN 2>/dev/null || \
      iptables -t nat -A OUTPUT -p tcp -j $CHAIN

    # Link the custom chain to the PREROUTING chain for hotspot/forwarded traffic
<<<<<<< HEAD:proxy/proxyredsocks.sh
    # This is what makes phone traffic (via hotspot) go through redsocks
=======
>>>>>>> aryan/master:proxy/script/proxyredsocks.sh
    iptables -t nat -C PREROUTING -p tcp -j $CHAIN 2>/dev/null || \
      iptables -t nat -A PREROUTING -p tcp -j $CHAIN

    # Block QUIC/UDP 443 to prevent direct HTTPS connections bypassing proxy
<<<<<<< HEAD:proxy/proxyredsocks.sh
    # For local traffic (laptop)
    iptables -C OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A OUTPUT -p udp --dport 443 -j DROP
    # For forwarded traffic (hotspot clients)
    iptables -C FORWARD -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A FORWARD -p udp --dport 443 -j DROP

    echo "[*] Redsocks enabled for local + hotspot traffic"
=======
    # For local traffic
    iptables -C OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A OUTPUT -p udp --dport 443 -j DROP
    # For forwarded traffic
    iptables -C FORWARD -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A FORWARD -p udp --dport 443 -j DROP

    echo "[*] Redsocks enabled"
>>>>>>> aryan/master:proxy/script/proxyredsocks.sh
    ;;

  disable)
    # Remove OUTPUT chain link
    iptables -t nat -D OUTPUT -p tcp -j $CHAIN 2>/dev/null || true

    # Remove PREROUTING chain link (hotspot traffic)
    iptables -t nat -D PREROUTING -p tcp -j $CHAIN 2>/dev/null || true
    
    # Flush and remove the custom chain
    iptables -t nat -F $CHAIN 2>/dev/null || true
    iptables -t nat -X $CHAIN 2>/dev/null || true
    
    # Re-enable QUIC/UDP 443
    iptables -D OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || true
    iptables -D FORWARD -p udp --dport 443 -j DROP 2>/dev/null || true
    
    # Stop the redsocks service
    systemctl stop $SERVICE

    echo "[*] Redsocks disabled"
    ;;

  status)
    # Check if redsocks service is running
    echo -n "Service: "
    systemctl is-active $SERVICE || true

<<<<<<< HEAD:proxy/proxyredsocks.sh
    echo ""
    echo "=== NAT OUTPUT chain ==="
    iptables -t nat -L OUTPUT -n --line-numbers 2>/dev/null | grep -i redsocks || echo "(no REDSOCKS rules)"

    echo ""
    echo "=== NAT PREROUTING chain ==="
    iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | grep -i redsocks || echo "(no REDSOCKS rules)"

    echo ""
    echo "=== REDSOCKS chain ==="
    iptables -t nat -L $CHAIN -n --line-numbers 2>/dev/null || echo "(chain does not exist)"
=======
    if [[ $EUID -ne 0 ]]; then
      echo "(run as root to see iptables rules)"
    else
      echo ""
      echo "=== NAT OUTPUT chain ==="
      iptables -t nat -L OUTPUT -n --line-numbers 2>/dev/null | grep -i redsocks || echo "(no REDSOCKS rules)"

      echo ""
      echo "=== NAT PREROUTING chain ==="
      iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | grep -i redsocks || echo "(no REDSOCKS rules)"

      echo ""
      echo "=== REDSOCKS chain ==="
      iptables -t nat -L $CHAIN -n --line-numbers 2>/dev/null || echo "(chain does not exist)"
    fi
>>>>>>> aryan/master:proxy/script/proxyredsocks.sh
    ;;

  *)
    echo "[!] Usage: proxyredsocks {enable|disable|status}"
    exit 1
esac
