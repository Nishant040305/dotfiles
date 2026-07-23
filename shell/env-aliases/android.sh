# scrcpy to cast phone screen
android() {
    adb devices
	scrcpy \
	        --video-bit-rate=32M \
	        --max-fps=60 \
	        --keyboard=aoa \
	        --mouse=uhid \
	        --render-driver=vulkan \
	        --turn-screen-off \
	        --fullscreen \
	        --flex-display \
	        --new-display=1920x1080/200 \
	        --start-app=com.magneticchen.daijishou
}
