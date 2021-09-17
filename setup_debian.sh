#!/bin/bash

sudo apt-get update
sudo apt-get -qqy install \
    jq \
    git \
    python3-pip \
    python3-venv

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -sSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -qqy install podman

git clone --quiet --depth 1 https://github.com/sstephenson/bats.git /tmp/bats
pushd /tmp/bats >/dev/null
sudo ./install.sh /usr/local
popd >/dev/null
