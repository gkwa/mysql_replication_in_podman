#!/usr/bin/env bash

set -o errexit

container=$(buildah from python:3.9-bullseye)
buildah config --label maintainer="Taylor Monacelli <taylormonacelli@gmail.com>" $container
buildah run $container pip install --upgrade pip
buildah copy $container ./requirements.txt /tmp/requirements.txt
buildah run $container apt-get -y update
buildah run $container apt-get -y install graphviz
buildah run $container apt-get -y install less bsdmainutils inotify-tools
buildah run $container apt-get -y --no-install-recommends install build-essential graphviz-dev
buildah run $container pip install --no-cache-dir --requirement /tmp/requirements.txt
buildah run $container pip install mysqlclient --no-binary=mysqlclient
buildah run $container pip list
buildah run $container apt-get -y clean
buildah run $container rm -rf /var/lib/apt/lists/*
buildah config --workingdir /data $container
buildah commit --format docker $container dbeval:latest
