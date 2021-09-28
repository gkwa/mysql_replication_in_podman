#!/usr/bin/env bash

set -o errexit

container=$(buildah from python:bullseye)
buildah config --label maintainer="Taylor Monacelli <taylormonacelli@gmail.com>" $container
buildah copy $container ./requirements.txt /tmp/requirements.txt
buildah run $container pip install --requirements /tmp/requirements.txt --upgrade pip
buildah run $container pip list
buildah config --workingdir /data $container
buildah commit --format docker $container dbeval:latest
