#!/bin/bash

@test "Fix podman/buildah install" {
    apt-get -qy upgrade
    apt-get -qqy install ca-certificates
}

@test "install apps" {
    apt-get update
    apt-get -qqy install \
        jq \
        git \
        python3-pip \
        python3-venv
}

@test "install podman" {
    apt-get update
    apt-get -y install podman

    podman info --debug >podman-info.log

    run test -s podman-info.log
    [ $status -eq 0 ]
}

@test "install podman old method" {
    skip
    . /etc/os-release
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | apt-key add -
    apt-get update
    apt-get -y install podman

    podman info --debug >podman-info.log

    run test -s podman-info.log
    [ $status -eq 0 ]
}

# https://github.com/mvdan/sh/releases
@test "install shfmt" {
    version=3.4.0
    curl -Lo /tmp/shfmt https://github.com/mvdan/sh/releases/download/v$version/shfmt_v${version}_linux_386
    install /tmp/shfmt /usr/local/bin/shfmt
}

@test "install buildah" {
    apt-get -qqy update </dev/null
    apt-get -o APT::Install-Suggests="true" -y install buildah
}
