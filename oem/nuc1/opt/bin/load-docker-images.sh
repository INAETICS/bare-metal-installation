#!/bin/bash

cd /opt/images

for TARFILE in *.tar; do
	echo "loading image $TARFILE"
	docker load -i "$TARFILE"
done
