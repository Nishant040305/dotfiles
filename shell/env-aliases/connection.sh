connection() {
    local action="$1"
    local glob="$2"

    local regex="${glob//\*/.*}"
    regex="^${regex}$"

    local conn
    conn=$(nmcli -t -f NAME connection show | grep -Ei -- "$regex" | head -n1)

    [[ -n $conn ]] || {
        echo "No connection matching '$glob'"
        return 1
    }

    echo "$action: $conn"

    case "$action" in
        enable)  nmcli connection up "$conn" ;;
        disable) nmcli connection down "$conn" ;;
        *)
            echo "Usage: connection {enable|disable} <pattern>"
            return 1
            ;;
    esac
}
