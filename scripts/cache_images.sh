#!/bin/bash

set -e

function podman_export()
{
    container_name="$1"
    image="$2"

    mkdir -p /src/out/containers/
    if [ ! -d /src/out/containers/"$container_name" ]
    then
        echo " -> Export image: $container_name ($image)"

        # Pull image
        sudo podman pull "$image"
        # Save image as oci-dir and compressed it
        sudo podman save --format oci-dir -o /src/out/containers/"$container_name" "$image"
    else
        echo " -> Image already exist: $container_name ($image)"
    fi
}

echo "[*] Export container images in cache"

# iterate on all container files
for f in /src/calaos-os/services/*.container ; do
    image=$(< "$f" grep Image= | cut -d= -f 2)
    filename=$(< "$f" grep ContainerName= | cut -d= -f 2)

    podman_export "$filename" "$image"
done

#Cache images
podman_export "calaos-base" "ghcr.io/calaos/calaos_base:latest"
podman_export "calaos-home" "ghcr.io/calaos/calaos_home:latest"
#Add special image for calaos-home/x11
podman_export "xserver" "docker.io/x11docker/xserver:latest"
