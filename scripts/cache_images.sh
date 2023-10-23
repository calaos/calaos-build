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
wget https://releases.calaos.fr/v4/images -O releases.calaos.json

jq -r '.images[] | [.name, .source, .version] | @tsv' releases.calaos.json |
  while IFS=$'\t' read -r name source version; do
    echo "  [*] Exporting container $name version $version"
    podman_export $name  $source
  done
