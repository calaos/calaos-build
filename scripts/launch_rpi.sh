#!/bin/bash
set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

disk=$outdir/calaos-os.sdimg

esp_start=$(fdisk -lu $disk | grep calaos-os.sdimg1 | awk '{ print $2 }')
esp_end=$(fdisk -lu $disk | grep calaos-os.sdimg1 | awk '{ print $3 }')
efi_disk=$(losetup --offset $((512 * esp_start)) --sizelimit $((512 * esp_end)) --show --find ${disk})

info "--> Mount Boot"
boot_mnt=$outdir/boot_mount
mkdir -p $boot_mnt
mount -t vfat $efi_disk $boot_mnt

qemu-system-aarch64 \
    -M raspi3b \
    -cpu cortex-a72 \
    -append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=/dev/mmcblk0p2 rootdelay=1 init=/lib/systemd/systemd silent" \
    -dtb $outdir/boot_mount/bcm2710-rpi-3-b-plus.dtb \
    -sd $disk \
    -kernel $outdir/boot_mount/kernel8.img \
    -m 1G -smp 4 \
    -serial mon:stdio \
    -usb -device usb-mouse -device usb-kbd \
    -device usb-net,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::6443-:6443 \

umount $boot_mnt