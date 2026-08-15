FORWARD_WIFI_IF="wlp2s0"
FORWARD_ETHER_IF="enp3s0f3u4"

# Leave empty to allow the entire Ethernet LAN
FORWARD_TARGET_IP=""

IPFORWARD_COMMENT="ipforward"

ipforward() {
    local cmd="${1:-status}"

    case "$cmd" in
        enable)
            sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null

            sudo iptables -t nat -C POSTROUTING \
                -o "$FORWARD_ETHER_IF" \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j MASQUERADE 2>/dev/null ||
            sudo iptables -t nat -A POSTROUTING \
                -o "$FORWARD_ETHER_IF" \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j MASQUERADE

            if [[ -n "$FORWARD_TARGET_IP" ]]; then
                sudo iptables -C FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -d "$FORWARD_TARGET_IP" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT 2>/dev/null ||
                sudo iptables -A FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -d "$FORWARD_TARGET_IP" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT
            else
                sudo iptables -C FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT 2>/dev/null ||
                sudo iptables -A FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT
            fi

            sudo iptables -C FORWARD \
                -i "$FORWARD_ETHER_IF" \
                -o "$FORWARD_WIFI_IF" \
                -m conntrack --ctstate ESTABLISHED,RELATED \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j ACCEPT 2>/dev/null ||
            sudo iptables -A FORWARD \
                -i "$FORWARD_ETHER_IF" \
                -o "$FORWARD_WIFI_IF" \
                -m conntrack --ctstate ESTABLISHED,RELATED \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j ACCEPT

            echo "✓ Forwarding enabled"
            ;;
        disable)
            while sudo iptables -t nat -D POSTROUTING \
                -o "$FORWARD_ETHER_IF" \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j MASQUERADE 2>/dev/null; do :; done

            if [[ -n "$FORWARD_TARGET_IP" ]]; then
                while sudo iptables -D FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -d "$FORWARD_TARGET_IP" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT 2>/dev/null; do :; done
            else
                while sudo iptables -D FORWARD \
                    -i "$FORWARD_WIFI_IF" \
                    -o "$FORWARD_ETHER_IF" \
                    -m conntrack --ctstate NEW,ESTABLISHED,RELATED \
                    -m comment --comment "$IPFORWARD_COMMENT" \
                    -j ACCEPT 2>/dev/null; do :; done
            fi

            while sudo iptables -D FORWARD \
                -i "$FORWARD_ETHER_IF" \
                -o "$FORWARD_WIFI_IF" \
                -m conntrack --ctstate ESTABLISHED,RELATED \
                -m comment --comment "$IPFORWARD_COMMENT" \
                -j ACCEPT 2>/dev/null; do :; done

            sudo sysctl -w net.ipv4.ip_forward=0 >/dev/null

            echo "✓ Forwarding disabled"
            ;;
        restart)
            ipforward disable
            ipforward enable
            ;;
        status)
            echo "IP forwarding : $(< /proc/sys/net/ipv4/ip_forward)"
            echo

            echo "Custom NAT:"
            sudo iptables -t nat -S POSTROUTING | grep -F -- "--comment $IPFORWARD_COMMENT" || echo "  disabled"

            echo
            echo "Custom FORWARD:"
            sudo iptables -S FORWARD | grep -F -- "--comment $IPFORWARD_COMMENT" || echo "  disabled"
            ;;
    esac
}
