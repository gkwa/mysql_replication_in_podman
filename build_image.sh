#!/usr/bin/env bash

set -o errexit

container=$(buildah from python:bullseye)

# Labels are part of the "buildah config" command
buildah config --label maintainer="Taylor Monacelli <taylormonacelli@gmail.com>" $container

cat <<'__eot__' >/tmp/requirements.txt
monacelli_pylog_prefs
ipython
django-extensions
Django
humanfriendly
Jinja2
Pandas
PyYAML
mysqlclient
pydantic
wheel
__eot__

buildah copy $container /tmp/requirements.txt /tmp/requirements.txt 
buildah run $container pip install -r /tmp/requirements.txt
buildah run $container pip list
buildah config --workingdir /data $container
# buildah config --entrypoint /usr/local/bin/hello $container
buildah commit --format docker $container dbeval:latest
