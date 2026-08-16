#!/usr/bin/env bash
set -euo pipefail

PORT_HTTP=12345
PORT_CONNECT=12346

CHAIN="REDSOCKS"
SERVICE="redsocks"

PROXY_IP="${2:-}"

RESERVED_NETS=(
    0.0.0.0/8
    10.0.0.0/8
    100.64.0.0/10
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
        return
    fi

    local proxy_url

    proxy_url="$(
        kreadconfig6 \
            --file kioslaverc \
            --group "Proxy Settings" \
            --key httpProxy \
            2>/dev/null || true
    )"

    if [[ -n "$proxy_url" ]]; then
        # Strip scheme
        proxy_url="${proxy_url#http://}"
        proxy_url="${proxy_url#https://}"

        # Strip credentials
        proxy_url="${proxy_url##*@}"

        # Strip port
        ip="${proxy_url%%:*}"
    fi

    if [[ -z "$ip" ]]; then
        echo "[!] Proxy IP not provided."
        echo "    Usage:"
        echo "      sudo $0 enable <PROXY_IP>"
        exit 1
    fi

    printf '%s\n' "$ip"
}

rewrite_conf() {
    local ip
    ip="$(resolve_proxy_ip)"

    echo "[*] Proxy: http://edcguest:edcguest@${ip}:3128"

    sed \
        -e "s/__PROXY_IP__/${ip}/g" \
        /etc/redsocks.conf.template \
        > /etc/redsocks.conf.new

    mv /etc/redsocks.conf.new /etc/redsocks.conf
}

create_chain() {
    iptables -t nat -N "$CHAIN" 2>/dev/null || true
    iptables -t nat -F "$CHAIN"
}

remove_chain() {
    iptables -t nat -D OUTPUT \
        -p tcp \
        -j "$CHAIN" 2>/dev/null || true

    iptables -t nat -D PREROUTING \
        -p tcp \
        -j "$CHAIN" 2>/dev/null || true

    iptables -t nat -F "$CHAIN" 2>/dev/null || true
    iptables -t nat -X "$CHAIN" 2>/dev/null || true
}

configure_chain() {

    # Never proxy traffic to the proxy itself.
    local proxy_ip
    proxy_ip="$(resolve_proxy_ip)"

    iptables -t nat -A "$CHAIN" \
        -d "$proxy_ip" \
        -j RETURN

    # Tailscale
    iptables -t nat -A "$CHAIN" \
        -o tailscale0 \
        -j RETURN 2>/dev/null || true

    # Private/reserved networks
    for net in "${RESERVED_NETS[@]}"; do
        iptables -t nat -A "$CHAIN" \
            -d "$net" \
            -j RETURN
    done

    # HTTP
    iptables -t nat -A "$CHAIN" \
        -p tcp \
        --dport 80 \
        -j REDIRECT \
        --to-ports "$PORT_HTTP"

    # HTTPS only
    iptables -t nat -A "$CHAIN" \
        -p tcp \
        --dport 443 \
        -j REDIRECT \
        --to-ports "$PORT_CONNECT"
}

install_hooks() {

    # Local machine traffic
    iptables -t nat -C OUTPUT \
        -p tcp \
        -j "$CHAIN" 2>/dev/null || \
    iptables -t nat -A OUTPUT \
        -p tcp \
        -j "$CHAIN"

    # Forwarded/hotspot traffic
    iptables -t nat -C PREROUTING \
        -p tcp \
        -j "$CHAIN" 2>/dev/null || \
    iptables -t nat -A PREROUTING \
        -p tcp \
        -j "$CHAIN"
}

configure_firewall() {

    # Force HTTPS applications away from QUIC.
    iptables -C OUTPUT \
        -p udp \
        --dport 443 \
        -j DROP 2>/dev/null || \
    iptables -A OUTPUT \
        -p udp \
        --dport 443 \
        -j DROP

    iptables -C FORWARD \
        -p udp \
        --dport 443 \
        -j DROP 2>/dev/null || \
    iptables -A FORWARD \
        -p udp \
        --dport 443 \
        -j DROP

    # Block TCP Private DNS for forwarded clients.
    iptables -C FORWARD \
        -p tcp \
        --dport 853 \
        -j REJECT \
        --reject-with tcp-reset 2>/dev/null || \
    iptables -A FORWARD \
        -p tcp \
        --dport 853 \
        -j REJECT \
        --reject-with tcp-reset
}

remove_firewall() {

    iptables -D OUTPUT \
        -p udp \
        --dport 443 \
        -j DROP 2>/dev/null || true

    iptables -D FORWARD \
        -p udp \
        --dport 443 \
        -j DROP 2>/dev/null || true

    iptables -D FORWARD \
        -p tcp \
        --dport 853 \
        -j REJECT \
        --reject-with tcp-reset 2>/dev/null || true
}

show_status() {

    echo "=== Service ==="
    systemctl is-active "$SERVICE" || true

    echo
    echo "=== Redsocks listeners ==="
    ss -lntp | grep -E ":(${PORT_HTTP}|${PORT_CONNECT})" || \
        echo "No redsocks listeners found."

    echo
    echo "=== NAT OUTPUT ==="
    iptables -t nat -L OUTPUT -n --line-numbers |
        grep -E "$CHAIN" || \
        echo "No REDSOCKS OUTPUT rule."

    echo
    echo "=== NAT PREROUTING ==="
    iptables -t nat -L PREROUTING -n --line-numbers |
        grep -E "$CHAIN" || \
        echo "No REDSOCKS PREROUTING rule."

    echo
    echo "=== REDSOCKS chain ==="
    iptables -t nat -L "$CHAIN" -n --line-numbers \
        2>/dev/null || \
        echo "Chain does not exist."

    echo
    echo "=== DNS ==="
    resolvectl status 2>/dev/null |
        grep -E "DNS Servers|DNS Domain" || true
}

enable() {

    rewrite_conf

    echo "[*] Starting redsocks..."
    systemctl restart "$SERVICE"

    echo "[*] Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1 >/dev/null

    echo "[*] Creating REDSOCKS chain..."
    create_chain

    echo "[*] Configuring REDSOCKS chain..."
    configure_chain

    echo "[*] Installing NAT hooks..."
    install_hooks

    echo "[*] Configuring firewall..."
    configure_firewall

    echo
    echo "[+] Redsocks enabled."
    echo
    echo "HTTP  : TCP/80  -> 127.0.0.1:${PORT_HTTP}"
    echo "HTTPS : TCP/443 -> 127.0.0.1:${PORT_CONNECT}"
}

disable() {

    echo "[*] Removing NAT hooks..."
    remove_chain

    echo "[*] Removing firewall rules..."
    remove_firewall

    echo "[*] Stopping redsocks..."
    systemctl stop "$SERVICE"

    echo
    echo "[+] Redsocks disabled."
}

case "${1:-}" in

    enable)
        enable
        ;;

    disable)
        disable
        ;;

    status)
        show_status
        ;;

    *)
        echo "Usage:"
        echo "  sudo $0 enable <PROXY_IP>"
        echo "  sudo $0 disable"
        echo "  sudo $0 status"
        exit 1
        ;;
esac