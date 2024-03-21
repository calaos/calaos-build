#!/bin/bash

set -e

function upload_file()
{
    FNAME=$1
    HASH=$2
    INSTALLPATH=$3

    curl -X POST \
        -H "Content-Type: multipart/form-data" \
        -F "upload_key=$UPLOAD_KEY" \
        -F "upload_folder=$INSTALLPATH" \
        -F "upload_sha256=$HASH" \
        -F "upload_file=@$FNAME" \
        https://calaos.fr/download/upload
}

TARGET_ARCH="$1"
FILE="$2"

if [ -z "$TARGET_ARCH" ]; then
    echo "Usage: $0 <arch> <file>"
    exit 1
fi

if [ -z "$FILE" ]; then
    echo "Usage: $0 <arch> <file>"
    exit 1
fi

#if filename contains rc or alpha, upload to unstable
if [[ $FILE == *"rc"* ]] || [[ $FILE == *"alpha"* ]]; then
    repo="experimental"
else
    repo="stable"
fi

upload_file "$FILE" "$(shasum -a 256 "build/$FILE" | cut -d' ' -f1)" "${repo}/calaos-os/${TARGET_ARCH}/"
