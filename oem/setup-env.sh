#!/bin/sh
env=/etc/environment
function get_ipv4() {
    IP=
    while [ 1 ]; do
        IP=$(ip -f inet addr show eno1 | awk '/inet 172/ { gsub("/24", ""); print $2 }')
        if [ "$IP" != "" ]; then
            break
        fi
        sleep .1
    done
    echo $IP
}

ipv4=$(get_ipv4)

if [ "$1" == "" ]; then
    if [ -f "${env}" ]; then
        sed -i -e '/^COREOS_PUBLIC_IPV4=/d' -e '/^COREOS_PRIVATE_IPV4=/d' -e '/^COREOS_PUBLIC_IPV6=/d' -e '/^COREOS_PRIVATE_IPV6=/d' "${env}"
    fi

    echo "COREOS_PUBLIC_IPV4=${ipv4}" >>${env}
    echo "COREOS_PRIVATE_IPV4=${ipv4}" >>${env}
else
    echo "COREOS_PUBLIC_IPV4=${ipv4}"
    echo "COREOS_PRIVATE_IPV4=${ipv4}"
fi

###EOF###
