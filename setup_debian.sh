#!/bin/bash

sudo apt-get update
sudo apt-get -qy install \
     unzip \
     jq \
     git \
     python3-pip \
     python3-venv

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman

git clone https://github.com/sstephenson/bats.git /usr/local/src/bats
cd /usr/local/src/bats
./install.sh /usr/local
