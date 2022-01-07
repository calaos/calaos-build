#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

fix_docker_perms

if [ -z "$1" ]
then
    echo "No package name given. Usage: $0 calaos-ddns|calaos-home|calaos-server <repo> <arch>"
    exit 1
fi

arch="x86_64"
repo="calaos-dev"

if [ ! -z "$2" ]
then
    repo=$2
fi

if [ ! -z "$3" ]
then
    arch=$3
fi

echo "Building package for repo: $repo and arch: $arch"

setup_calaos_repo
import_gpg_key

pkgname=$1
cd $build_dir/pkgbuilds/$pkgname

if [ $signing_available -eq 1 ]
then
    makepkg -f -s --sign --noconfirm
else
    makepkg -f -s --noconfirm
fi

mkdir -p $build_dir/out/pkgs/$arch
cp $build_dir/pkgbuilds/$pkgname/*pkg.tar.zst* $build_dir/out/pkgs/$arch

upload_pkg $build_dir/pkgbuilds/$pkgname/*pkg.tar.zst $repo $arch
