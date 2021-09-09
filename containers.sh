#!/bin/bash

uid=$(id -u)
gid=$(id -g)

echo XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR

cp /tmp/auth.json.decrypted /tmp/auth.json.decrypted.tmp
sudo cat /tmp/auth.json.decrypted.tmp | sudo python -m base64 -d >/tmp/auth.json.decrypted
mkdir -p $HOME/.docker/
sudo cp /tmp/auth.json.decrypted $HOME/.docker/config.json

sudo cat /tmp/auth.json.decrypted >$HOME/.docker/config.json

sudo mkdir -p /run/user/$uid/containers
sudo cp /tmp/auth.json.decrypted /run/user/$uid/containers/auth.json
sudo chown -R $uid:$gid /run/user/$uid/containers
