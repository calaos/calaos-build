#!/bin/bash

# build container cache directory
cache=/var/lib/cache/containers/$1

if [ -d "$cache" ]
then
    echo "loading $cache"
    # Podman loads directory as cache and put it in localhost/... repository
    podman load -i "$cache"
    # Retry image name with repositiory name (docker.io|ghcr.io|...)
    image=$(cat  /etc/containers/systemd/$1.container | grep Image= | cut -d= -f 2)
    echo "Image : $image"
    # Get SHA of image loaded
    sha=$(podman images -a | grep $1 | awk -F ' ' '{ print $3 }')
    echo "SHA : $sha"
    # tag it SHA with the full qualified image name to be used in the container
    podman image tag "$sha" "$image"
    # Remove the cache
    rm -rf "$cache"
fi
