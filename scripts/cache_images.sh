#!/bin/bash

set -e
# iterate on all container files
for f in /src/calaos-os/services/*.container ; do
    image=$(cat $f | grep Image= | cut -d= -f 2)
    filename=$(cat $f | grep ContainerName= | cut -d= -f 2)
    mkdir -p /src/out/containers/
    if [ ! -d /src/out/containers/"$filename" ]
    then
        # Pull image
        sudo podman pull "$image"
        # Save image as oci-dir and compressed it
        sudo podman save --format oci-dir -o /src/out/containers/"$filename" "$image"
    fi
done
