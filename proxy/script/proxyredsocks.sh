#!/usr/bin/env bash
set -euo pipefail

# Configuration
PORT_HTTP=12345           # Redsocks listening port for HTTP (http-relay)
PORT_CONNECT=12346        # Redsocks listening port for HTTPS and generic TCP (http-connect)
PORT_DNS=1053             # Redsocks tcpdns local UDP listening port
CHAIN=REDSOCKS            # iptables chain name
SERVICE=redsocks          # systemd service name
PROXY_IP="${2:-}"         # Proxy server IP address (passed as argument)

# Reserved/private networks that should bypass the proxy
RESERVED_NETS=(
  0.0.0.0/8
  10.0.0.0/8
  100.64.0.0/10           # Tailscale CGNAT range
  127.0.0.0/8
  169.254.0.0/16
  172.16.0.0/12
  192.168.0.0/16
  224.0.0.0/4
  240.0.0.0/4
)

resolve_proxy_ip() {
  local ip="${PROXY_IP:-}"

  if [[ -n "$ip" ]]; then
    printf '%s\n' "$ip"
    return 0
  fi

  local proxy_url
  proxy_url=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key httpProxy 2>/dev/null || true)
  if [[ -n "$proxy_url" ]]; then
    ip=$(printf '%s' "$proxy_url" | sed -E 's|https?://([^:@]*:)?([^:@]*@)?||; s|:.*||')
  fi

  if [[ -z "$ip" ]]; then
    echo "[!] Usage: proxyredsocks enable <PROXY_IP>"
    echo "    or configure KDE system proxy first"
    exit 1
  fi

  printf '%s\n' "$ip"
}

rewrite_conf() {
  local ip
  ip="$(resolve_proxy_ip)"

  echo "[*] Using proxy http://edcguest:edcguest@$ip:3128"

  sed \
    -e "s/__PROXY_IP__/${ip}/g" \
    /etc/redsocks.conf.template > /etc/redsocks.conf.new

  mv /etc/redsocks.conf.new /etc/redsocks.conf
}

setup_system_dns() {
  # Direct systemd-resolved to use local redsocks tcpdns forwarder on all default-route interfaces
  local ifaces
  ifaces=$(ip -o route show default 2>/dev/null | awk '{print $5}' | sort -u || true)
  for iface in $ifaces; do
    resolvectl dns "$iface" "127.0.0.1:$PORT_DNS" 2>/dev/null || true
  done
  resolvectl flush-caches 2>/dev/null || true
}

restore_system_dns() {
  local ifaces
  ifaces=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v "lo" || true)
  for iface in $ifaces; do
    resolvectl revert "$iface" 2>/dev/null || true
  done
  resolvectl flush-caches 2>/dev/null || true
}

show_status() {
  # Check if redsocks service is running
  echo -n "Service: "
  systemctl is-active $SERVICE || true

  if [[ $EUID -ne 0 ]]; then
    echo "(run as root to see iptables rules and DNS status)"
  else
    echo ""
    echo "=== NAT OUTPUT chain ==="
    local output_rules
    output_rules="$(iptables -t nat -L OUTPUT -n --line-numbers 2>/dev/null | grep -iE "redsocks|1053" || true)"
    if [[ -n "$output_rules" ]]; then
      echo "$output_rules"
    else
      echo "(no REDSOCKS rules)"
    fi

    echo ""
    echo "=== NAT PREROUTING chain ==="
    local prerouting_rules
    prerouting_rules="$(iptables -t nat -L PREROUTING -n --line-numbers 2>/dev/null | grep -iE "redsocks|1053" || true)"
    if [[ -n "$prerouting_rules" ]]; then
      echo "$prerouting_rules"
    else
      echo "(no REDSOCKS rules)"
    fi

    echo ""
    echo "=== REDSOCKS chain ==="
    local chain_rules
    chain_rules="$(iptables -t nat -L $CHAIN -n --line-numbers 2>/dev/null || true)"
    if [[ -n "$chain_rules" ]]; then
      echo "$chain_rules"
    else
      echo "(chain does not exist)"
    fi

    echo ""
    echo "=== DNS Status (resolvectl) ==="
    resolvectl status 2>/dev/null | grep -E "Link|DNS Server" | head -10 || true

    if [[ "$(systemctl is-active "$SERVICE" 2>/dev/null || true)" == "active" ]] && \
       [[ -z "${output_rules:-}" && -z "${prerouting_rules:-}" && -z "${chain_rules:-}" ]]; then
      echo ""
      echo "[!] Service is active but no REDSOCKS NAT rules are installed."
      echo "    Run: sudo /usr/local/sbin/proxyredsocks enable"
    fi
  fi
}

case "${1:-}" in

  enable)
    # Start the redsocks service
    rewrite_conf
    systemctl restart $SERVICE

    # Enable IP forwarding (required for hotspot NAT)
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Create or flush the custom iptables chain
    iptables -t nat -N $CHAIN 2>/dev/null || true
    iptables -t nat -F $CHAIN

    # Bypass all traffic sent through the Tailscale interface
    iptables -t nat -A $CHAIN -o tailscale0 -j RETURN

    # Exclude private/reserved networks from redirection (whitelist)
    for net in "${RESERVED_NETS[@]}"; do
      iptables -t nat -A $CHAIN -d "$net" -j RETURN
    done

    # Port 80 (HTTP) -> http-relay instance (port 12345)
    iptables -t nat -A $CHAIN -p tcp --dport 80 -j REDIRECT --to-ports $PORT_HTTP

    # All other TCP (HTTPS, TCP DNS, etc.) -> http-connect instance (port 12346)
    iptables -t nat -A $CHAIN -p tcp -j REDIRECT --to-ports $PORT_CONNECT
    
    # Link the custom chain to the OUTPUT chain for local traffic
    iptables -t nat -C OUTPUT -p tcp -j $CHAIN 2>/dev/null || \
      iptables -t nat -A OUTPUT -p tcp -j $CHAIN

    # Link the custom chain to the PREROUTING chain for hotspot/forwarded traffic
    iptables -t nat -C PREROUTING -p tcp -j $CHAIN 2>/dev/null || \
      iptables -t nat -A PREROUTING -p tcp -j $CHAIN

    # Redirect UDP port 53 to redsocks tcpdns forwarder (port 1053)
    iptables -t nat -C OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS 2>/dev/null || \
      iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS
    iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS 2>/dev/null || \
      iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS

    # Configure local system DNS resolver (systemd-resolved)
    setup_system_dns

    # Block QUIC/UDP 443 to force browsers to fall back to standard TCP HTTPS
    iptables -C OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A OUTPUT -p udp --dport 443 -j DROP
    iptables -C FORWARD -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A FORWARD -p udp --dport 443 -j DROP

    echo "[*] Redsocks enabled for local + hotspot traffic (HTTP, HTTPS, DNS)"
    ;;

  disable)
    # Remove OUTPUT & PREROUTING chain links
    iptables -t nat -D OUTPUT -p tcp -j $CHAIN 2>/dev/null || true
    iptables -t nat -D PREROUTING -p tcp -j $CHAIN 2>/dev/null || true

    # Remove UDP 53 DNS redirection
    iptables -t nat -D OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS 2>/dev/null || true
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports $PORT_DNS 2>/dev/null || true
    
    # Flush and remove the custom chain
    iptables -t nat -F $CHAIN 2>/dev/null || true
    iptables -t nat -X $CHAIN 2>/dev/null || true
    
    # Restore system DNS settings
    restore_system_dns

    # Re-enable QUIC/UDP 443
    iptables -D OUTPUT -p udp --dport 443 -j DROP 2>/dev/null || true
    iptables -D FORWARD -p udp --dport 443 -j DROP 2>/dev/null || true
    
    # Stop the redsocks service
    systemctl stop $SERVICE

    echo "[*] Redsocks disabled"
    ;;

  status)
    show_status
    ;;

  *)
    echo "[!] Usage: proxyredsocks {enable|disable|status} [PROXY_IP]"
    exit 1
esac
