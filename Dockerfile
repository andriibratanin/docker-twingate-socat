#https://hub.docker.com/r/bitnami/minideb
#FROM bitnami/minideb:bullseye@sha256:50ff45bbb2f66326b2df9cb99cc6ccdb3bdc60f0851c1a92af4280cce355ebcd
#FROM bitnami/minideb:trixie@sha256:8c421215febfc583d9399faf3b8ae6c3b190e5c3b526f84f6a0e10a22e604a86
#https://hub.docker.com/_/ubuntu
FROM ubuntu:noble-20260113

WORKDIR /

# Note: use `apt list twingate -a` to get a list of available versions
# Note: message like "GPG error..." during build is ok - "curl" and "gpg" are not installed to decrease the resulting image size (see commented lines)
RUN apt-get update && \
    apt-get install --no-install-recommends -y ca-certificates=20240203 && \
    # Signed (more packages installed, more space taken)
    #apt-get install --no-install-recommends -y curl=8.5.0-2ubuntu10.6 && \
    #apt-get install --no-install-recommends -y gpg=2.4.4-2ubuntu17.4 && \
    #curl -fsSL https://packages.twingate.com/apt/gpg.key | gpg --dearmor -o /usr/share/keyrings/twingate-client-keyring.gpg && \
    #echo "deb [signed-by=/usr/share/keyrings/twingate-client-keyring.gpg] https://packages.twingate.com/apt/ * *" | tee /etc/apt/sources.list.d/twingate.list && \
    # OR
    # Trusted (less space)
    echo "deb [trusted=yes] https://packages.twingate.com/apt/ /" | tee /etc/apt/sources.list.d/twingate.list && \
    #
    apt-get update -o Dir::Etc::sourcelist="sources.list.d/twingate.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" && \
    apt-get install --no-install-recommends -y twingate=2025.342.178568 && \
    apt-get install --no-install-recommends -y socat=1.8.0.0-4build3 && \
    apt-get remove ca-certificates -y && \
    #apt-get remove curl -y && \
    #apt-get remove gpg -y && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /
COPY log_transformer_socat.sh /
COPY log_transformer_twingate.sh /

ENTRYPOINT ["/entrypoint.sh"]
