#!/bin/bash

ct_name="$1"

# Get fqdn of image (docker.io|ghcr.io|...)
if [ -f /etc/containers/systemd/"$ct_name".container ]
then
    image=$(< /etc/containers/systemd/"$ct_name".container grep Image= | cut -d= -f 2)
else
    image="$2"
fi

if [ -z "$image" ]
then
    echo "Usage: $0 <containe_name> <full image name>"
    echo "  ex: $0 calaos-home ghcr.io/calaos/calaos_home:latest"
    exit 1
fi

# build container cache directory
cache=/var/lib/cache/containers/$ct_name

if [ -d "$cache" ]
then
    echo "loading $cache"

    # Podman loads directory as cache and put it in localhost/... repository
    podman load -i "$cache"

    echo "Image : $image"

    # Get SHA of image loaded
    sha=$(podman images -a | grep "$ct_name" | awk -F ' ' '{ print $3 }')
    echo "SHA : $sha"

    # tag it SHA with the full qualified image name to be used in the container
    podman image tag "$sha" "$image"

    # Remove the cache
    rm -rf "$cache"
fi
