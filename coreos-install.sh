#!/bin/bash
# Copyright (c) 2015 - INAETICS.
# Based on the coreos-install script from CoreOS.

# Everything we do should be user-access only!
umask 077

USAGE="Usage: $0 [-d /dev/device] [-h hostname]
Options:
    -d DEVICE   Install CoreOS to the given device.
    -n HOSTNAME The name of the machine.
    -v          Super verbose, for debugging.
    -h          This ;-)
        
This tool installs CoreOS on a given block device.
"
DEVICE=""
CC_DIR=""

while getopts "d:n:vh" OPTION
do
    case $OPTION in
        d) DEVICE="$OPTARG" ;;
        h) echo "$USAGE"; exit;;
        n) HOSTNAME="$OPTARG" ;;
        v) set -x ;;
        *) exit 1;;
    esac
done

# Make sure we've got a valid SSH key to add...
if [ ! -f ssh/id_rsa.pub ]; then
    echo 'Please copy valid SSH public key file (id_rsa.pub) into ssh!'
    exit 1
fi

if [[ -z "${HOSTNAME}" ]]; then
    echo "$0: No hostname provided, -n is required." >&2
    exit 1
fi

# Device is required, must not be a partition, must be writable
if [[ -z "${DEVICE}" ]]; then
    echo "$0: No target block device provided, -d is required." >&2
    exit 1
fi

if ! [[ $(lsblk -n -d -o TYPE "${DEVICE}") =~ ^(disk|loop|lvm)$ ]]; then
    echo "$0: Target block device (${DEVICE}) is not a full disk." >&2
    exit 1
fi

if [[ ! -w "${DEVICE}" ]]; then
    echo "$0: Target block device (${DEVICE}) is not writable (are you root?)" >&2
    exit 1
fi

IMAGE_NAME="./coreos_production_image.bin.bz2"
if [[ ! -f "${IMAGE_NAME}" ]]; then
    echo "$0: No CoreOS image downloaded! Run download.sh first!" >&2
    exit 1
fi

CC_DIR="oem/${HOSTNAME}/cloudinit"
if [[ ! -d "${CC_DIR}" ]]; then
    CC_DIR="oem/default/cloudinit"
fi

OPT_DIR="oem/${HOSTNAME}/opt"
if [[ ! -d "${OPT_DIR}" ]]; then
    OPT_DIR="oem/default/opt"
fi

SSL_DIR="oem/${HOSTNAME}/ssl"
if [[ ! -d "${SSL_DIR}" ]]; then
    SSL_DIR="oem/default/ssl"
fi

CC_FIRST_STAGE=${CC_DIR}/cloud-config.yml
CC_SECOND_STAGE=${CC_DIR}/cloud-config-2nd-stage.yml

# Pre-flight checks pass, lets get this party started!
echo "Writing ${IMAGE_NAME} to ${DEVICE}..."
if ! bzcat $IMAGE_NAME >"${DEVICE}"; then
    echo "Failed to write ${IMAGE_NAME} to ${DEVICE}..." >&2
    wipefs --all --backup "${DEVICE}"
    exit 1
fi

# inform the OS of partition table changes
blockdev --rereadpt "${DEVICE}"

WORKDIR=$(mktemp --tmpdir -d coreos-install.XXXXXXXXXX)
mkdir -p "${WORKDIR}/rootfs" "${WORKDIR}/oemfs"

unmount_all() {
    umount "${WORKDIR}/rootfs"
    umount "${WORKDIR}/oemfs"
    rm -rf "${WORKDIR}"
}
trap "unmount_all" EXIT

PUBKEY=$(cat ssh/id_rsa.pub)

# The ROOT partition should be #9 but make no assumptions here!
# Also don't mount by label directly in case other devices conflict.
ROOT_DEV=$(blkid -t "LABEL=ROOT" -o device "${DEVICE}"*)
if [[ -z "${ROOT_DEV}" ]]; then
    echo "Unable to find new ROOT partition on ${DEVICE}" >&2
    exit 1
fi
mount "${ROOT_DEV}" "${WORKDIR}/rootfs"

OEM_DEV=$(blkid -t "LABEL=OEM" -o device "${DEVICE}"*)
if [[ -z "${OEM_DEV}" ]]; then
    echo "Unable to find new OEM partition on ${DEVICE}" >&2
    exit 1
fi
mount "${OEM_DEV}" "${WORKDIR}/oemfs"

# Add our INAETICS specific stuff...
mkdir -p "${WORKDIR}/rootfs/opt"
mkdir -p "${WORKDIR}/rootfs/etc/docker/certs.d/172.17.8.20:5000/"
cp "${OPT_DIR}/ssl/certs/ca.pem" "${WORKDIR}/rootfs/etc/docker/certs.d/172.17.8.20:5000/ca.crt"
cp -rL "${OPT_DIR}"/* "${WORKDIR}/rootfs/opt/"
find "${WORKDIR}/rootfs/opt" -type f -exec chmod 0644 {} \;
find "${WORKDIR}/rootfs/opt" -type d -exec chmod 0755 {} \;
chmod 0755 "${WORKDIR}/rootfs/opt/bin/kubectl" "${WORKDIR}/rootfs/bin"/*.sh
chown -R 0:500 "${WORKDIR}/rootfs/opt/ssl/"
chmod 0640 "${WORKDIR}/rootfs/opt/ssl/priv"/*-key.pem
chmod 0644 "${WORKDIR}/rootfs/opt/ssl/certs"/*.pem
# Ensure that our paths are visible...
bashrc="${WORKDIR}/rootfs/home/core/.bashrc"
rm -f $bashrc
cat <<'EOT' >$bashrc
if [[ $- != *i* ]] ; then
# Shell is non-interactive.  Be done now!
    return
fi
# Make sure we can access our own scripts...
export PATH=$PATH:~/bin:/opt/bin
EOT
# Make sure it has the correct ownership...
chown 500:500 $bashrc

cp "oem/setup-env.sh" "${WORKDIR}/oemfs"
cat ${CC_FIRST_STAGE} | sed -e "s|\$PUBKEY|$PUBKEY|g" -e "s|\$HOSTNAME|$HOSTNAME|g" >"${WORKDIR}/oemfs/cloud-config.yml"
cat ${CC_SECOND_STAGE} | sed -e "s|\$HOSTNAME|$HOSTNAME|g" >"${WORKDIR}/oemfs/cloud-config-2nd-stage.yml"
find "${WORKDIR}/oemfs" -name "*.yml" -exec chmod 0644 {} \;
find "${WORKDIR}/oemfs" -name "*.sh" -exec chmod 0750 {} \;

# And we're done...
unmount_all
trap - EXIT

echo "Success! CoreOS is installed on ${DEVICE}..."

###EOF###
