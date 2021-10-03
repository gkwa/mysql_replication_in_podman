#!/usr/bin/env bash

set -o errexit

container=$(buildah from python:bullseye)
buildah config --label maintainer="Taylor Monacelli <taylormonacelli@gmail.com>" $container
buildah copy $container ./requirements.txt /tmp/requirements.txt
buildah run $container pip install --requirement /tmp/requirements.txt --upgrade pip
buildah run $container pip list
buildah run $container apt-get -y update
buildah run $container apt-get -y install less bsdmainutils
buildah config --workingdir /data $container
buildah commit --format docker $container dbeval:latest
