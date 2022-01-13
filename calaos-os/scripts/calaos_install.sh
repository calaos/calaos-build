#!/bin/sh

# Usage : install.sh [device] [file.hddimg]

echo "Installing $2 on device $1"

disk=$1
from=$2

# Deleting partition table
dd if=/dev/zero of=${disk} bs=512 count=35

# Create ESP fat32 partition for EFI (512MiB)
parted -s ${disk} mklabel gpt
parted ${disk} mkpart "efi" fat32 1MiB 513MiB
mkfs.vfat -F32 ${disk}1
parted ${disk} set 1 boot on

# Create Swap partition (2GiB)
parted -s ${disk} mkpart "swap" linux-swap 513MiB 2.5GiB

# Create partition for Rootfs
parted ${disk} mkpart "calaos" ext4 2.5GiB 100%

# Installing rootfs.img on new partition
mkdir -p /mnt/from
mount ${from} /mnt/from
pv -tpreb /mnt/from/rootfs.img  | dd of=${disk}3 bs=64M
e2fsck -f ${disk}3 -y
resize2fs ${disk}3
umount ${from}

mkdir -p /mnt/efi
mount ${disk}1 /mnt/efi
bootctl --path /mnt/efi install

cat << EOF > /mnt/efi/loader/loader.conf
default calaos.conf
timeout 5
console-mode max
editor yes
EOF
 
cat << EOF > /mnt/efi/loader/entries/calaos.conf
title   Calaos
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root="LABEL=calaos" rw
EOF

mkinitcpio /mnt/efi/vmlinuz-linux -c /etc/mkinitcpio.conf -g /mnt/efi/initramfs-linux.img -k `ls /usr/lib/modules`
umount /mnt/efi

