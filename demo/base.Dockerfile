# Create base system with a vulnerable OpenSSL version.
FROM ubuntu:bionic
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
 && apt-get install -y libssl1.1 openssl gdb
# Patch in the vulnerable OpenSSL version.
COPY libssl.so.1.1 libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/
COPY openssl /usr/bin/
# Copy the self-signed certificate.
COPY server.pem /root/