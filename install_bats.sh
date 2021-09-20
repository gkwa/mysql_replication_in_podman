#!/bin/bash

# allow nice testing output
git clone --quiet --depth 1 https://github.com/sstephenson/bats.git /tmp/bats
pushd /tmp/bats >/dev/null
./install.sh /usr/local
popd >/dev/null
