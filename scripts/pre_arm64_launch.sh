#!/bin/bash

if [ ! -e /src/out/varstore.img ]; then
    echo "Create varstore.img"
    truncate -s 64m /src/out/varstore.img
fi

if [ ! -e /src/out/efi.img ]; then
    echo "Create efi.img"
    truncate -s 64m /src/out/efi.img
    dd if=/usr/share/qemu-efi-aarch64/QEMU_EFI.fd of=/src/out/efi.img conv=notrunc
fi
