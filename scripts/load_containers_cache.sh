#!/bin/bash

for image in /var/lib/cache/containers/* ; do
    name="${image##*/}"
    mkdir -p /src/out/containers/
    skopeo copy oci:$image containers-storage://$name:latest
done

rm -rf /var/lib/cache/containers