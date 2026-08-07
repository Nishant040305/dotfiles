# scrcpy to cast phone screen
android() {
    adb devices
    local device_id
    device_id=$(adb devices | grep -w "device" | grep -v "List of" | head -n1 | awk '{print $1}')

    if [ -z "$device_id" ]; then
        echo "[!] No active online ADB device found."
        return 1
    fi

    local extra_flags=(-s "$device_id")
    # AOA keyboard requires a physical USB connection
    if [[ "$device_id" != *:* ]]; then
        extra_flags+=("--keyboard=aoa" "--mouse=uhid")
    fi

    if [ "${1:-}" = "virtual" ] || [ "${1:-}" = "daijishou" ]; then
        # Secondary Virtual Display Mode (Daijishou emulator launcher)
        scrcpy \
                "${extra_flags[@]}" \
                --video-bit-rate=32M \
                --max-fps=60 \
                --render-driver=vulkan \
                --turn-screen-off \
                --fullscreen \
                --flex-display \
                --new-display=1920x1080/200 \
                --start-app=com.magneticchen.daijishou
    else
        # Phone to PC System Mirroring (Default: Mirrors actual phone screen to PC)
        scrcpy \
                "${extra_flags[@]}" \
                --video-bit-rate=32M \
                --max-fps=60 \
DISPLAY=127.0.0.1:0 ssh -X Nishant@10.42.0.1 code
                --render-driver=vulkan
    fi
}

