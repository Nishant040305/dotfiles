# Toggle hotspot
hotspot() {
    case "$1" in
        enable)
            nmcli connection up Hotspot
            ;;
        disable)
            nmcli connection down Hotspot
            ;;
        *)
            echo "Usage: hotspot {enable|disable}"
            return 1
            ;;
    esac
}
