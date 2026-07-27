# Reboot directly into Windows
winboot() {
    sudo grub2-reboot 'Windows Boot Manager (on /dev/nvme0n1p1)' && reboot
}
