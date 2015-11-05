#!/bin/bash

if [ "$1" == "" ]; then
    echo "Usage: $0 /path/to/dest"
    exit 1
fi

# copy certs and keys first
shopt -s extglob
cp ssl/out/!(*-key.pem|*.srl) oem/default/opt/ssl/certs/
cp ssl/out/!(*-key.pem|*.srl) oem/nuc1/opt/ssl/certs/
cp ssl/out/*-key.pem oem/default/opt/ssl/priv/
cp ssl/out/*-key.pem oem/nuc1/opt/ssl/priv/

rsync -rvcW --filter="exclude copy_all.sh" --filter="exclude download-coreos.sh" --filter="exclude initial-download.sh" --filter="exclude tmp" --filter="exclude .git" --filter="exclude .gitignore" . $1

find "$1" -iname "*.sh" | xargs chmod +x