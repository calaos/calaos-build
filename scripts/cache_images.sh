#!/bin/bash

set -e

SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $SCRIPTDIR/calaos_lib.sh

mkdir -p "${HOME}/calaos/calaos_docker"

for f in /src/calaos-os/services/*.container ; do
    image=$(cat $f | grep Image= | cut -d= -f 2)
    filename=$(cat $f | grep ContainerName= | cut -d= -f 2)
    path=$(echo $image | cut -d / -f 2- ) 
    echo $path
    

    mkdir -p /src/out/containers/
    skopeo copy docker://$image oci:/src/out/containers/$filename
    #sudo podman save -o /src/out/containers/$filename.tar --format oci-archive $image
done
