#!/usr/bin/env bash

set -o pipefail -eux

DOMAIN_NAME="${1}"
PASSWORD="${2}"

generate () {
    NAME="${1}"
    SUBJECT="${2}"
    KEY="${3}"
    CA_NAME="${4}"
    CA_OPTIONS=("-CA" "${CA_NAME}.pem" "-CAkey" "${CA_NAME}.key" "-CAcreateserial")

    cat > openssl.conf << EOL
distinguished_name = req_distinguished_name

[req_distinguished_name]

[req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SUBJECT}
DNS.2 = ${NAME}
EOL

    echo "Generating ${NAME} signed cert"
    openssl req \
        -new \
        "-${KEY}" \
        -subj "/CN=${SUBJECT}" \
        -newkey rsa:2048 \
        -keyout "${NAME}.key" \
        -out "${NAME}.csr" \
        -config openssl.conf \
        -reqexts req \
        -passin pass:"${PASSWORD}" \
        -passout pass:"${PASSWORD}"

    openssl x509 \
        -req \
        -in "${NAME}.csr" \
        "-${KEY}" \
        -out "${NAME}.pem" \
        -days 365 \
        -extfile openssl.conf \
        -extensions req \
        -passin pass:"${PASSWORD}" \
        ${CA_OPTIONS[@]}

    openssl pkcs12 \
        -export \
        -out "${NAME}.pfx" \
        -inkey "${NAME}.key" \
        -in "${NAME}.pem" \
        -passin pass:"${PASSWORD}" \
        -passout pass:"${PASSWORD}"

    rm openssl.conf
}

echo "Generating CA certificate"
openssl genrsa \
    -aes256 \
    -out ca.key \
    -passout pass:"${PASSWORD}"

openssl req \
    -new \
    -x509 \
    -days 365 \
    -key ca.key \
    -out ca.pem \
    -subj "/CN=sansldap Root" \
    -passin pass:"${PASSWORD}"

echo "Generating DC01 LDAPS certificate"
generate DC01 DC01."${DOMAIN_NAME}" sha256 ca

echo "Generating SQL01 certificate"
generate SQL01 SQL01."${DOMAIN_NAME}" sha256 ca

touch complete.txt
