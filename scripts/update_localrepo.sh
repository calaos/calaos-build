#!/bin/sh

ls /src/out/pkgs/x86_64/*.tar.zst
if [ $? -eq 0 ]; then
    repo-add /src/out/pkgs/x86_64/calaos.db.tar.gz /src/out/pkgs/x86_64/*.tar.zst
    echo -e\
    "[calaos]\n"\
    "SigLevel = Optional TrustAll\n"\
    "Server = file:///src/out/pkgs/x86_64\n"\
    >>  /etc/pacman.conf
    pacman -Sy --noconfirm
else
     mkdir -p /src/out/pkgs/x86_64/
fi


