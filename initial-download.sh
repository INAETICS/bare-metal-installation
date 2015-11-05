#!/bin/bash

k8s_version=v1.0.6
pause_version=0.8.0
podmaster_version=1.1
flannel_version=0.5.3
registry_version=2

pullAndSave() {
    # first arg is image, second filename
	echo "pulling and saving $1"
	docker pull "$1"
	docker save -o "$2" "$1"
}

# download CoreOS image for NUC installation
./download-coreos.sh

# download CoreOS iso for USB stick boot
wget http://stable.release.core-os.net/amd64-usr/current/coreos_production_iso_image.iso

# build inaetics images
for NAME in celix-agent felix-agent node-provisioning; do
	echo "pulling and saving $NAME image"
	remote_name="inaetics/$NAME:latest"
	local_name="172.17.8.20:5000/$remote_name"
	docker pull "$remote_name"
	docker tag -f "docker.io/$remote_name" "$local_name"
	docker save -o "tmp/$NAME.tar" "$local_name"
done

echo "get latest bundles"
wget -O - "https://github.com/INAETICS/bundles/archive/master.tar.gz" | tar -xz -C "oem/nuc1/opt/bundles" --strip=1

echo "get kubectl"
wget -O "oem/nuc1/opt/bin/kubectl" "https://storage.googleapis.com/kubernetes-release/release/$k8s_version/bin/linux/amd64/kubectl"

# pull and save 3rd party images
pullAndSave "gcr.io/google_containers/pause:$pause_version" "tmp/pause.tar"
pullAndSave "gcr.io/google_containers/hyperkube:$k8s_version" "tmp/hyperkube.tar"
pullAndSave "quay.io/coreos/flannel:$flannel_version" "tmp/flannel.tar" 
pullAndSave "registry:$registry_version" "tmp/registry.tar" 
pullAndSave "slintes/elasticsearch:latest" "tmp/elasticsearch.tar"
pullAndSave "logstash:latest" "tmp/logstash.tar"
pullAndSave "slintes/kibana:latest" "tmp/kibana.tar"

# copy tarred docker images to needed location
for NAME in celix-agent felix-agent node-provisioning elasticsearch logstash kibana flannel registry hyperkube pause; do
	cp "tmp/$NAME.tar" oem/nuc1/opt/images/
done
for NAME in flannel hyperkube pause; do
	cp "tmp/$NAME.tar" oem/default/opt/images/
done