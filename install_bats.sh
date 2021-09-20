#!/bin/bash

# allow nice testing output
rm -rf /tmp/bats-core
git clone --quiet --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
pushd /tmp/bats-core >/dev/null
./install.sh /usr/local
popd >/dev/null
