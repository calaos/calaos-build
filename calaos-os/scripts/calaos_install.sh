#!/bin/sh

# Usage : install.sh [destination] [livecd_disk]
set -e

NOCOLOR='\033[0m'
CYAN='\033[0;36m'

function info()
{
    echo -e "${CYAN}$@${NOCOLOR}"
}

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

info "--> Creating efi partition"
# Create GPT partition table
parted -s ${destination} mklabel gpt > /dev/null
# Create ESP fat32 partition for EFI (512MiB)
parted ${destination} mkpart "efi" fat32 1MiB 513MiB > /dev/null
parted ${destination} set 1 esp on > /dev/null
# Create Swap partition (2GiB)
parted -s ${destination} mkpart "swap" linux-swap 513MiB 2.5GiB
# Create partition for Rootfs
parted ${destination} mkpart "calaos" ext4 2.5GiB 100%

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


info "--> Creating EFI partition"
mkdir -p /mnt/destination_esp
mount ${destination_esp} /mnt/destination_esp
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

info "--> Copy Kernel and Initramfs"
cp /boot/initramfs-linux.img  /mnt/destination_esp
cp /boot/vmlinuz-linux /mnt/destination_esp

info "--> Unmouting all partitions"
umount /mnt/destination_esp
umount /mnt/destination_rootfs
umount /mnt/origin_rootfs

info "--> Check destination rootfs"
e2fsck -f ${destination_rootfs} -y


info "--> Installation successfull, you can no reboot"