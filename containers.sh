#!/bin/bash

uid=$(id -u)
gid=$(id -g)

echo XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR

cp /tmp/auth.json.decrypted /tmp/auth.json.decrypted.tmp
cat /tmp/auth.json.decrypted.tmp |python -m base64 -d >/tmp/auth.json.decrypted

sudo mkdir -p /run/user/$uid/containers
sudo cp /tmp/auth.json.decrypted /run/user/$uid/containers/auth.json
sudo chown -R $uid:$gid /run/user/$uid/containers

mkdir -p $HOME/.docker/
cat /tmp/auth.json.decrypted |python -m base64
cp /tmp/auth.json.decrypted $HOME/.docker/config.json