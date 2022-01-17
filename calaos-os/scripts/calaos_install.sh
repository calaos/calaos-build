#!/bin/sh

# Usage : install.sh [destination] [livecd_disk]
set -e

NOCOLOR='\033[0m'
CYAN='\033[0;36m'

function info()
{
    echo -e "${CYAN}$@${NOCOLOR}"
}

function parse_cmdline()
{
    # Parse command line and LABEL variable
    set -- $(cat /proc/cmdline)
    for x in "$@"; do
        case "$x" in
            LABEL=*)
                eval "${x}"
            ;;
        esac
    done
}

parse_cmdline

if [ $LABEL == "live-efi" ]; then
    info "--> Install in UEFI mode"
else
    info "--> Install in BIOS mode"
fi

info "--> Installing $2 on destination $1"

destination=$1
origin=$2

origin_esp=${origin}1
origin_rootfs=${origin}2

destination_esp=${destination}1
destination_swap=${destination}2
destination_rootfs=${destination}3

# Deleting partition table
info "--> Deleting partition table on ${destination}"
dd if=/dev/zero of=${destination} bs=512 count=35 > /dev/null


if [ $LABEL == "live-efi" ]; then
    info "--> Creating GPT partition table"
    parted -s ${destination} mklabel gpt > /dev/null
    parted -s ${destination} mkpart "efi" fat32 1MiB 513MiB > /dev/null
    parted -s ${destination} mkpart "swap" linux-swap 513MiB 2.5GiB > /dev/null
    parted -s ${destination} mkpart "calaos" ext4 2.5GiB 100% > /dev/null
    parted -s ${destination} set 1 esp on > /dev/null
    parted -s ${destination} set 2 boot on > /dev/null
    parted -s ${destination} print
else
    info "--> Creating Bios partition table"
    parted -s ${destination} mklabel msdos  > /dev/null > /dev/null
    parted -s ${destination} mkpart primary fat32 1MiB 513MiB > /dev/null
    parted -s ${destination} mkpart primary linux-swap 513MiB 2.5GiB > /dev/null
    parted -s ${destination} mkpart primary ext4 2.5GiB 100% > /dev/null
    parted -s ${destination} set 1 esp on > /dev/null
    parted -s ${destination} set 2 boot on > /dev/null
    parted -s ${destination} print
fi

info "--> Formating partitions"
mkfs.vfat -F32 ${destination_esp} > /dev/null
mkswap ${destination_swap}
mkfs.ext4 -F ${destination_rootfs}


info "--> Copy rootfs from live usb"
mkdir -p /mnt/origin_rootfs /mnt/destination_rootfs
mount ${origin_rootfs} /mnt/origin_rootfs
mount ${destination_rootfs} /mnt/destination_rootfs
rsync -ah --info=progress2 /mnt/origin_rootfs/ /mnt/destination_rootfs
rm -rf /mnt/destination_rootfs/.calaos-live
genfstab -U /mnt/destination_rootfs >> /mnt/destination_rootfs/etc/fstab

mkdir -p /mnt/destination_esp
mount ${destination_esp} /mnt/destination_esp

info "--> Copy Kernel and Initramfs"
cp /boot/initramfs-linux.img  /mnt/destination_esp
cp /boot/vmlinuz-linux /mnt/destination_esp

if [ $LABEL == "live-efi" ]; then
    info "--> Creating EFI partition"

    bootctl --path /mnt/destination_esp install
    cat << EOF > /mnt/destination_esp/loader/loader.conf
default calaos.conf
timeout 5
console-mode max
editor yes
EOF

    cat << EOF > /mnt/destination_esp/loader/entries/calaos.conf
title   Calaos
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root="PARTLABEL=calaos" rw
EOF

else
    info "--> Creating Boot partition"
    mkdir -p /mnt/destination_esp/syslinux
    cp /usr/lib/syslinux/bios/*.c32 /mnt/destination_esp/syslinux/
    extlinux --install /mnt/destination_esp/syslinux
    dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/bios/mbr.bin of=$destination

    cat << EOF > /mnt/destination_esp/syslinux/syslinux.cfg
ALLOWOPTIONS 1
DEFAULT boot
TIMEOUT 50
PROMPT 0
ui vesamenu.c32
menu title Select kernel options and boot kernel
menu tabmsg Press [Tab] to edit, [Return] to select
menu background splash.lss

LABEL start
    MENU LABEL Start Calaos OS
    LINUX ../vmlinuz-linux
    APPEND rootwait rw quiet
    INITRD ../initramfs-linux.img

LABEL hdt
	MENU LABEL Hardware Info
	COM32 hdt.c32

LABEL reboot
	MENU LABEL Reboot
	COM32 reboot.c32

LABEL poweroff
	MENU LABEL Power Off
	COM32 poweroff.c32
EOF

    cp /boot/syslinux/splash.lss /mnt/destination_esp/syslinux/
fi

info "--> Unmouting all partitions"
umount /mnt/destination_esp
umount /mnt/destination_rootfs
umount /mnt/origin_rootfs

info "--> Check destination rootfs"
e2fsck -f ${destination_rootfs} -y


info "--> Installation successfull, you can no reboot"