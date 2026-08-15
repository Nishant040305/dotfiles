#!/usr/bin/env bash
set -euo pipefail

# Configuration
VPN_IF="${2:-tun0}"         # VPN tunnel interface
HOTSPOT_IF="${3:-wlp2s0}"   # Hotspot/Wi-Fi interface

case "${1:-}" in

  enable)
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Allow forwarded traffic between hotspot and VPN
    iptables -C FORWARD -i $HOTSPOT_IF -o $VPN_IF -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i $HOTSPOT_IF -o $VPN_IF -j ACCEPT
    iptables -C FORWARD -i $VPN_IF -o $HOTSPOT_IF -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i $VPN_IF -o $HOTSPOT_IF -m state --state RELATED,ESTABLISHED -j ACCEPT

    # Masquerade outgoing traffic on VPN interface
    iptables -t nat -C POSTROUTING -o $VPN_IF -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o $VPN_IF -j MASQUERADE

    # Block QUIC/UDP 443 for forwarded traffic
    iptables -C FORWARD -p udp --dport 443 -j DROP 2>/dev/null || \
      iptables -A FORWARD -p udp --dport 443 -j DROP

    echo "[*] Masquerade enabled ($HOTSPOT_IF → $VPN_IF)"
    ;;

  disable)
    # Remove forwarding rules
    iptables -D FORWARD -i $HOTSPOT_IF -o $VPN_IF -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i $VPN_IF -o $HOTSPOT_IF -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

    # Remove masquerade
    iptables -t nat -D POSTROUTING -o $VPN_IF -j MASQUERADE 2>/dev/null || true

    # Remove QUIC block
    iptables -D FORWARD -p udp --dport 443 -j DROP 2>/dev/null || true

    echo "[*] Masquerade disabled"
    ;;

  status)
    echo "=== IP Forwarding ==="
    cat /proc/sys/net/ipv4/ip_forward

    if [[ $EUID -ne 0 ]]; then
      echo "(run as root to see iptables rules)"
    else
      echo ""
      echo "=== FORWARD chain ==="
      iptables -L FORWARD -n --line-numbers 2>/dev/null | grep -E "$VPN_IF|$HOTSPOT_IF|DROP.*443" || echo "(no masquerade rules)"

      echo ""
      echo "=== NAT POSTROUTING ==="
      iptables -t nat -L POSTROUTING -n --line-numbers 2>/dev/null | grep -i masquerade || echo "(no MASQUERADE rules)"
    fi
    ;;

  *)
    echo "[!] Usage: masquerade {enable|disable|status} [VPN_IF] [HOTSPOT_IF]"
    echo "  Defaults: VPN_IF=tun0, HOTSPOT_IF=wlp2s0"
    exit 1
esac
