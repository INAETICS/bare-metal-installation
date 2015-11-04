#!/bin/sh

openssl=$(which openssl)

keysize=2048
days=1000

outdir=out
ca_key_file="$outdir/ca-key.pem"
ca_cert_file="$outdir/ca.pem"

export K8S_SERVICE_IP=10.3.0.1
export MASTER_IP=172.17.8.20

if [ ! -d $outdir ]; then
    mkdir $outdir
fi

gen_ca_cert() {
    $openssl genrsa -out $ca_key_file $keysize
    $openssl req -x509 -new -nodes -key $ca_key_file -days $days -out $ca_cert_file -subj "$1"
}

gen_cert() {
    key_file="$outdir/${1}-key.pem"
    csr_file="$outdir/${1}.csr"
    cert_file="$outdir/${1}.pem"
    subject="$2"

    $openssl genrsa -out $key_file $keysize
    $openssl req -new -key $key_file -out $csr_file -subj "$subject" -config openssl.cnf
    $openssl x509 -req -in $csr_file -CA $ca_cert_file -CAkey $ca_key_file -CAcreateserial -out $cert_file -days $days -extensions v3_req -extfile openssl.cnf
}

# Generate CA key...
gen_ca_cert "/O=inaetics/CN=ca"

# Generate the various certificates...
gen_cert "docker-registry" "/O=inaetics/CN=docker-registry"
gen_cert "etcd" "/O=inaetics/CN=etcd"
gen_cert "apiserver" "/O=inaetics/CN=k8s-apiserver"
gen_cert "worker" "/O=inaetics/CN=k8s-worker"
gen_cert "admin" "/O=inaetics/CN=k8s-cluster-admin"

rm -f $outdir/*.csr

###EOF###
