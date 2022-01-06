#!/bin/sh

cp -r /boot/ /src/out

dd if=/dev/zero of=/src/out/calaos-os.hddimg bs=2048 count=1M
mkfs.vfat /src/out/calaos-os.hddimg

dd if=/dev/zero of=/src/out/rootfs.img bs=1500 count=1M
mkfs.ext4 /src/out/rootfs.img
rm -rf /src/out/rootfs_mount
mkdir /src/out/rootfs_mount
mount -t ext4 /src/out/rootfs.img /src/out/rootfs_mount
tar xf /src/out/calaos-os.rootfs.tar -C  /src/out/rootfs_mount
syslinux --directory syslinux --install /src/out/calaos-os.hddimg 
mcopy -s -i /src/out/calaos-os.hddimg /src/out/rootfs_mount/boot/* ::
umount /src/out/rootfs_mount

mcopy -n -o -i /src/out/calaos-os.hddimg /src/calaos-os/boot/syslinux.calaos.cfg ::syslinux/syslinux.cfg
mcopy -i /src/out/calaos-os.hddimg /src/calaos-os/boot/splash.lss ::syslinux/splash.lss

mcopy -i /src/out/calaos-os.hddimg /usr/lib/syslinux/bios/menu.c32 ::
mcopy -i /src/out/calaos-os.hddimg /usr/lib/syslinux/bios/libutil.c32 ::
mcopy -i /src/out/calaos-os.hddimg /usr/lib/syslinux/bios/libcom32.c32 ::
mcopy -i /src/out/calaos-os.hddimg /usr/lib/syslinux/bios/vesamenu.c32 ::
mcopy -i /src/out/calaos-os.hddimg /src/out/rootfs.img ::
# mcopy -i /src/out/calaos-os.hddimg /src/out/rootfs_mount/boot/initramfs-linux.img ::
# mcopy -i /src/out/calaos-os.hddimg /src/out/rootfs_mount/boot/vmlinuz-linux ::
# mdir -i /src/out/calaos-os.hddimg ::syslinux
#mcopy -i /src/out/calaos-os.hddimg /src/out/rootfs_mount/boot/syslinux/syslinux.cfg ::syslinux/syslinux.cfg
mdir -i /src/out/calaos-os.hddimg

