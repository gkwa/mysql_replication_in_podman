#!/bin/bash

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -sSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | sudo apt-key add -

sudo apt-get -qy update
sudo apt-get -qy install podman

podman --version

sudo apt-get -qy install python3-pip
# sudo apt-get -qy install python-venv
sudo apt-get -qy install python3.8-venv
