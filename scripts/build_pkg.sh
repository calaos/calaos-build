#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

if [ -z "$1" ]
then
    echo "No package name given. Usage: $0 calaos-ddns|calaos-home|calaos-server"
    exit 1
fi

import_gpg_key

pkgname=$1

cd $build_dir/pkgbuilds/$pkgname

if [ $signing_available -eq 1 ]
then
    makepkg -f -s --sign --noconfirm
else
    makepkg -f -s --noconfirm
fi

arch="x86_64"

mkdir -p $build_dir/out/pkgs/$arch
cp $build_dir/pkgbuilds/$pkgname/*pkg.tar.zst* $build_dir/out/pkgs/$arch
