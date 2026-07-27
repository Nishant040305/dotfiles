# scrcpy to cast phone screen with rock-solid stability & low latency
# Hardware setup: OnePlus Nord (Qualcomm Snapdragon) -> Lenovo (Intel Iris Xe GPU)
# Connection: USB 3.0 cable
# Requires: Full FFmpeg from RPM Fusion (not ffmpeg-free)

android() {
    # --- Crash prevention ---
    # Kill any orphaned scrcpy-server from a previous crash to get a clean session.
    adb shell pkill -f scrcpy-server 2>/dev/null

    # Whitelist Daijishou against OxygenOS battery optimization so Android doesn't
    # kill the virtual display surface mid-game.
    adb shell dumpsys deviceidle whitelist +com.magneticchen.daijishou 2>/dev/null

    # --- Encoder ---
    # H.265 via Qualcomm HW encoder -> decoded by Intel QSV or native FFmpeg HEVC on laptop.
    # H.265 is ~40% more efficient than H.264 at same bitrate.

    # --- Latency tuning ---
    # 1. 1280x720 virtual display: halves pixel count vs 1080p. The Snapdragon encoder
    #    was choking at 1080p60 (4fps stalls -> frame jumps + queued input lag).
    #    720p keeps the encoder comfortably in real-time = consistent frames = no jumps.
    # 2. 5M bitrate: right-sized for 720p. Over-allocating bitrate (8M) wastes encoder
    #    time filling bits that don't improve visual quality at this resolution.
    # 3. 45fps cap: sustainable ceiling the encoder can hold without boom-bust cycles.
    #    (60fps caused alternating 4fps/60fps swings = the "frame jump" feel)
    # 4. --audio-buffer=30: tighter than 80ms now that we have a proper decoder.

    scrcpy \
        --video-codec=h265 \
        --video-encoder='c2.qti.hevc.encoder' \
        --audio-codec=opus \
        --audio-buffer=30 \
        --render-driver=opengl \
        --video-bit-rate=5M \
        --max-fps=45 \
        --keyboard=uhid \
        --mouse=uhid \
        --new-display=1280x720/200 \
        --turn-screen-off \
        --stay-awake \
        --start-app=com.magneticchen.daijishou \
        --fullscreen \
        --print-fps
}