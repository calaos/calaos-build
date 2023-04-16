#!/bin/bash
set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

disk=$outdir/calaos-os.hddimg

# truncate -s 64m varstore.img
# truncate -s 64m efi.img 
# dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=efi.img conv=notrunc

# cp varstore.img efi.img $outdir

qemu-system-aarch64 -M virt \
    -accel hvf \
    -cpu host \
     -smp 4,cores=4 \
     -m 4096 \
    -drive if=pflash,format=raw,file=efi.img,readonly \
    -drive if=pflash,format=raw,file=varstore.img\
    -device virtio-blk-device,drive=disk1 \
    -drive id=disk1,file=out/calaos-os.hddimg,if=none \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    -nographic \
    -serial mon:stdio \
    -nic user,hostfwd=tcp::2222-:22,hostfwd=tcp::5454-:5454,hostfwd=udp::4545-:4545,hostfwd=tcp::3000-:3000,hostfwd=tcp::8080-:80,hostfwd=tcp::4443-:443,hostfwd=tcp::8086-:8086 \
