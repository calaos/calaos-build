#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

cp -r /boot/ $outdir

info "--> Create empty calaos-os.hddimg"
dd if=/dev/zero of=$outdir/calaos-os.hddimg bs=4096 count=1M
mkfs.vfat $outdir/calaos-os.hddimg

info "--> Create empty rootfs.img"
dd if=/dev/zero of=$outdir/rootfs.img bs=4000 count=1M
mkfs.ext4 $outdir/rootfs.img

info "--> Mount rootfs.img"
rm -rf $outdir/rootfs_mount
mkdir $outdir/rootfs_mount
mount -t ext4 $outdir/rootfs.img $outdir/rootfs_mount

info "--> Extract rootfs into rootfs.img"
tar xf $outdir/calaos-os.rootfs.tar -C  $outdir/rootfs_mount

info "--> Install Syslinux"
syslinux --directory syslinux --install $outdir/calaos-os.hddimg

info "--> Install boot files"
mcopy -s -i $outdir/calaos-os.hddimg $outdir/rootfs_mount/boot/* ::
umount $outdir/rootfs_mount

info "--> Install bootloader files"
mcopy -n -o -i $outdir/calaos-os.hddimg /src/calaos-os/boot/syslinux.calaos.cfg ::syslinux/syslinux.cfg
mcopy -i $outdir/calaos-os.hddimg /src/calaos-os/boot/splash.lss ::syslinux/splash.lss

mcopy -i $outdir/calaos-os.hddimg /usr/lib/syslinux/bios/menu.c32 ::
mcopy -i $outdir/calaos-os.hddimg /usr/lib/syslinux/bios/libutil.c32 ::
mcopy -i $outdir/calaos-os.hddimg /usr/lib/syslinux/bios/libcom32.c32 ::
mcopy -i $outdir/calaos-os.hddimg /usr/lib/syslinux/bios/vesamenu.c32 ::
mcopy -i $outdir/calaos-os.hddimg $outdir/rootfs.img ::
# mcopy -i $outdir/calaos-os.hddimg $outdir/rootfs_mount/boot/initramfs-linux.img ::
# mcopy -i $outdir/calaos-os.hddimg $outdir/rootfs_mount/boot/vmlinuz-linux ::
# mdir -i $outdir/calaos-os.hddimg ::syslinux
#mcopy -i $outdir/calaos-os.hddimg $outdir/rootfs_mount/boot/syslinux/syslinux.cfg ::syslinux/syslinux.cfg
mdir -i $outdir/calaos-os.hddimg

green "--> Calaos OS image is created: $outdir/calaos-os.hddimg"
