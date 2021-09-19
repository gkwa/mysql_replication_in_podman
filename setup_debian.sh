#!/bin/bash

apt-get update
apt-get -qqy install \
    jq \
    git \
    python3-pip \
    python3-venv

. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -sSL "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | apt-key add -
apt-get update
apt-get -qqy install podman

git clone --quiet --depth 1 https://github.com/sstephenson/bats.git /tmp/bats
pushd /tmp/bats >/dev/null
./install.sh /usr/local
popd >/dev/null

curl -sSLo /tmp/shfmt https://github.com/mvdan/sh/releases/download/v2.6.4/shfmt_v2.6.4_linux_386
install /tmp/shfmt /usr/local/bin/shfmt
