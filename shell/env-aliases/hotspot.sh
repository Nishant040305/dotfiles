# Toggle hotspot
hotspot() {
    case "$1" in
        enable)
            nmcli connection up Nishant-hotspot
            ;;
        disable)
            nmcli connection down Nishant-hotspot
            ;;
        *)
            echo "Usage: hotspot {enable|disable}"
            return 1
            ;;
    esac
}
