#!/bin/bash

uid=$(id -u)
gid=$(id -g)

sudo mkdir -p /run/user/$uid/containers
sudo cp /tmp/auth.json.decrypted /run/user/$uid/containers/auth.json
sudo chown -R $uid:$gid /run/user/$uid/containers
