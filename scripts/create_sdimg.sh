#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

cp -r /boot/ $outdir

disk=$outdir/calaos-os.sdimg

info "--> Create empty calaos-os.sdimg"
rm -rf $disk
truncate -s 4G $disk

parted -s ${disk} mklabel msdos
parted -s ${disk} mkpart primary fat32 1MiB 100MiB
parted -s ${disk} mkpart primary ext4 101MiB 100%
parted -s ${disk} set 1 esp on
parted -s ${disk} set 2 boot on
parted -s ${disk} print

#find EFI partition layout and setup loop device
esp_start=$(fdisk -lu $disk | grep calaos-os.sdimg1 | awk '{ print $2 }')
esp_end=$(fdisk -lu $disk | grep calaos-os.sdimg1 | awk '{ print $3 }')
efi_disk=$(losetup --offset $((512 * esp_start)) --sizelimit $((512 * esp_end)) --show --find ${disk})

#find rootfs partition layout and setup loop device
rootfs_start=$(fdisk -lu $disk | grep calaos-os.sdimg2 | awk '{ print $3 }')
rootfs_end=$(fdisk -lu $disk | grep calaos-os.sdimg2 | awk '{ print $4 }')
rootfs_disk=$(losetup --offset $((512 * rootfs_start)) --sizelimit $((512 * rootfs_end)) --show --find ${disk})

info "--> Format EFI partition"
mkfs.vfat $efi_disk

info "--> Format Rootfs partition"
mkfs.ext4 $rootfs_disk

uuid_rootfs=$(blkid -s UUID -o value ${rootfs_disk})
info "--> rootfs UUID=${uuid_rootfs}"

info "--> Mount rootfs"
rootfs_mnt=$outdir/rootfs_mount


rm -rf $rootfs_mnt
mkdir $rootfs_mnt
mount -t ext4 $rootfs_disk $rootfs_mnt

info "--> Mount Boot"
boot_mnt=$outdir/boot_mount
mkdir -p $boot_mnt
mount -t vfat $efi_disk $boot_mnt

info "--> Extract rootfs"
tar xf $outdir/calaos-os.rootfs.tar -C $rootfs_mnt
#remove the docker file on rootfs
rm -f $rootfs_mnt/.dockerenv

info "--> Move boot content"
mv $outdir/rootfs_mount/boot/* $boot_mnt/

#setup hostname. It does not work from within docker
echo "calaos-os" > $rootfs_mnt/etc/hostname

#create a file to know we are booting a live image
touch $rootfs_mnt/.calaos-live

info "--> Umount disks"
umount $boot_mnt
umount $rootfs_mnt
losetup --detach $efi_disk
losetup --detach $rootfs_disk

green "--> Calaos OS image is created: $outdir/calaos-os.sdimg"
