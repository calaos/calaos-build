#!/bin/bash

set -e

version="$1"

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

major=$(grep loop /proc/devices | cut -c3)
for index in 0 1 2 3 4 5 6 7 8 9;
do
    if [ ! -e /dev/loop$index ]; then
        mknod /dev/loop$index b $major $index
    fi
done

cp -r /boot/ $outdir

disk=$outdir/calaos-os-${TARGET_ARCH}-v${version}.hddimg

info "--> Create empty calaos-os-${version}.hddimg"
rm -rf $disk
truncate -s 4G $disk

parted -s ${disk} mklabel msdos
parted -s ${disk} mkpart primary fat32 1MiB 100MiB
parted -s ${disk} mkpart primary ext4 101MiB 100%
parted -s ${disk} set 1 esp on
parted -s ${disk} set 2 boot on
parted -s ${disk} print

#find EFI partition layout and setup loop device
esp_start=$(fdisk -lu $disk | grep '\.hddimg1' | awk '{ print $2 }')
esp_end=$(fdisk -lu $disk | grep '\.hddimg1' | awk '{ print $3 }')
efi_disk=$(losetup --offset $((512 * esp_start)) --sizelimit $((512 * esp_end)) --show --find ${disk})

#find rootfs partition layout and setup loop device
rootfs_start=$(fdisk -lu $disk | grep '\.hddimg2' | awk '{ print $3 }')
rootfs_end=$(fdisk -lu $disk | grep '\.hddimg2' | awk '{ print $4 }')
rootfs_disk=$(losetup --offset $((512 * rootfs_start)) --sizelimit $((512 * rootfs_end)) --show --find ${disk})

echo "ESP partition:"
echo "esp_start = $esp_start"
echo "esp_end = $esp_end"
echo "efi_disk = $efi_disk"
echo ""
echo "Root partition:"
echo "rootfs_start = $rootfs_start"
echo "rootfs_end = $rootfs_end"
echo "rootfs_disk = $rootfs_disk"

info "--> Format EFI partition $efi_disk"
mkfs.vfat $efi_disk

info "--> Format Rootfs partition $rootfs_disk"
mkfs.ext4 $rootfs_disk

uuid_rootfs=$(blkid -s UUID -o value ${rootfs_disk})
info "--> rootfs UUID=${uuid_rootfs}"

info "--> Mount rootfs"
rootfs_mnt=$outdir/rootfs_mount

rm -rf $rootfs_mnt
mkdir $rootfs_mnt
mount -t ext4 $rootfs_disk $rootfs_mnt

info "--> Mount EFI"
efi_mnt=$rootfs_mnt/boot/efi
mkdir -p $efi_mnt
mount -t vfat $efi_disk $efi_mnt

info "--> Extract rootfs"
tar xf $outdir/calaos-os.rootfs.tar -C $rootfs_mnt
#remove the docker file on rootfs
rm -f $rootfs_mnt/.dockerenv

#setup hostname. It does not work from within docker
echo "calaos-os" > $rootfs_mnt/etc/hostname

#Setup resolv.conf
rm -rf $rootfs_mnt/etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf $rootfs_mnt/etc/resolv.conf

#Populate containers cache
mkdir -p $rootfs_mnt/var/lib/cache/containers
cp -r $outdir/containers/ $rootfs_mnt/var/lib/cache/

#create a file to know we are booting a live image
touch $rootfs_mnt/.calaos-live

#Remove policy file from docker, we don't want this in a real system
rm $rootfs_mnt/usr/sbin/policy-rc.d

info "--> Install systemd-boot on EFI"
mkdir -p $efi_mnt/EFI $efi_mnt/loader/entries
#Init machine-id for bootctl to work
#sudo systemd-firstboot --root / --setup-machine-id
bootctl --no-variables --make-machine-id-directory=no --esp-path=$efi_mnt install

#remove random-seed file from EFI. It contains an initialized entropy for faster boot
# As we distribute our live-image for installation, we do not want to distribute the same
# seed to anyone
# More info: https://systemd.io/RANDOM_SEEDS/
rm -f $efi_mnt/loader/random-seed

cat > $efi_mnt/loader/loader.conf << EOF
default calaos.conf
timeout 30
console-mode max
editor yes
random-seed-mode off
EOF

cat > $efi_mnt/loader/entries/calaos.conf << EOF
title   Boot USB Calaos v4 Live
linux   /vmlinuz
initrd  /initrd.img
options LABEL=live-efi root=UUID=${uuid_rootfs} rootwait rw init=/lib/systemd/systemd
EOF

cat > $efi_mnt/loader/entries/calaos-install.conf << EOF
title   Install Calaos OS to disk
linux   /vmlinuz
initrd  /initrd.img
options LABEL=live-efi root=UUID=${uuid_rootfs} rootwait rw init=/lib/systemd/systemd calaos_install
EOF

#copy kernel/initramfs to EFI partition to let sd-boot find it
cp $rootfs_mnt/vmlinuz $rootfs_mnt/initrd.img $efi_mnt/


echo target arch : $TARGET_ARCH
info "--> Install Syslinux"
mkdir -p $rootfs_mnt/boot/syslinux
cp /usr/lib/syslinux/modules/bios/*.c32 $rootfs_mnt/boot/syslinux/
#extlinux --install $rootfs_mnt/boot/syslinux
dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/mbr.bin of=$disk
cp /src/calaos-os/boot/syslinux.calaos.cfg $rootfs_mnt/boot/syslinux/syslinux.cfg
sed -i "s/\$uuid_rootfs/$uuid_rootfs/g" $rootfs_mnt/boot/syslinux/syslinux.cfg
cp /src/calaos-os/boot/splash.lss $rootfs_mnt/boot/syslinux/

info "--> Umount disks"
umount $efi_mnt
umount $rootfs_mnt
losetup --detach $efi_disk
losetup --detach $rootfs_disk

info "--> Compressing image"
(cd "$outdir"; ln -sf "$(basename $disk)" calaos-os.hddimg)

rm -fr "$disk".zst
zstd -19 -T0 "$disk" -o "$disk".zst

green "--> Calaos OS image is created: \n\t$outdir/calaos-os-${TARGET_ARCH}-v${version}.hddimg\n\t$outdir/calaos-os-${TARGET_ARCH}-v${version}.hddimg.zst"
