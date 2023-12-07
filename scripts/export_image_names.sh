#!/bin/bash

outdir="/src/out/containers.list"

mkdir -p "$outdir"

# All containers source and version are stored from the deb packages in /usr/share/calaos/*.source
# file basename is the deb pkg-name
for file in /usr/share/calaos/*.source; do
    file_name=$(basename "$file")
    cp "$file" "$outdir/$file_name"
done
