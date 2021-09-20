#!/bin/bash

@test "install apps" {

apt-get update
apt-get -qqy install \
    jq \
    git \
    python3-pip \
    python3-venv


}

@test "install podman" {

# run containers with podman
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | apt-key add -
apt-get update
apt-get -y install podman


}


@test "install shfmt" {

# allow pretty-printing bash scripts
curl -Lo /tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.3.1/shfmt_v3.3.1_linux_386
install /tmp/shfmt /usr/local/bin/shfmt

}





