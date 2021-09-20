#!/bin/bash

uid=$(id -u)
gid=$(id -g)

echo $uid:$gid
echo XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR

mkdir -p $HOME/.docker/
cp /tmp/auth.json.decrypted /tmp/auth.json.decrypted.tmp
rm -f /tmp/auth.json.decrypted
cat /tmp/auth.json.decrypted.tmp | python -m base64 -d >$HOME/.docker/config.json
