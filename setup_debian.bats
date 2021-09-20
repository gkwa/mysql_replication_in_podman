#!/bin/bash

apt-get update
apt-get -qqy install \
    jq \
    git \
    python3-pip \
    python3-venv

# run containers with podman
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | apt-key add -
apt-get update
apt-get -y install podman

# allow pretty-printing bash scripts
curl -Lo /tmp/shfmt https://github.com/mvdan/sh/releases/download/v2.6.4/shfmt_v2.6.4_linux_386
install /tmp/shfmt /usr/local/bin/shfmt
