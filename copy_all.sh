#!/bin/sh

if [ "$1" == "" ]; then
    echo "Usage: $0 /path/to/dest"
    exit 1
fi

rsync -rvcW --copy-links --filter="exclude copy_all.sh" --filter="exclude download.sh" . $1

