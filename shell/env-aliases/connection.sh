# Connection settings

CONNECTION_RETRY_DELAY=1
CONNECTION_RETRY_DELAY_MAX=30
CONNECTION_CHECK_INTERVAL=10

connection() {
    local action="$1"
    local glob="$2"

    if [[ -z "$action" || -z "$glob" ]]; then
        echo "Usage: connection {enable|disable|up|down|force} <pattern>"
        return 1
    fi

    case "$action" in
        up)     action="enable" ;;
        down)   action="disable" ;;
        enable|disable|force) ;;
        *)
            echo "Usage: connection {enable|disable|up|down|force} <pattern>"
            return 1
            ;;
    esac

    local regex="${glob//\*/.*}"
    regex="^${regex}$"

    local conn
    conn=$(nmcli -t -f NAME connection show | grep -Ei -- "$regex" | head -n1)

    [[ -n $conn ]] || {
        echo "No connection matching '$glob'"
        return 1
    }

    if [[ "$action" == "force" ]]; then
        echo "force: $conn"

        local delay=$CONNECTION_RETRY_DELAY

        while true; do
            if nmcli -t -f NAME connection show --active |
                grep -Fxq "$conn"; then
                sleep "$CONNECTION_CHECK_INTERVAL"
                delay=$CONNECTION_RETRY_DELAY
                continue
            fi

            echo "disconnected: $conn"
            echo "retrying in ${delay}s..."

            sleep "$delay"

            if nmcli connection up "$conn"; then
                echo "connected: $conn"
                delay=$CONNECTION_RETRY_DELAY
            else
                echo "connection failed"

                delay=$((delay * 2))
                (( delay > CONNECTION_RETRY_DELAY_MAX )) &&
                    delay=$CONNECTION_RETRY_DELAY_MAX
            fi
        done
    fi

    echo "$action: $conn"

    case "$action" in
        enable)  nmcli connection up "$conn" ;;
        disable) nmcli connection down "$conn" ;;
    esac
}

alias conn='connection'
