#!/bin/bash

set -o errexit
set +o history

PASSWORD="$1"

# base64 encode basic credentials
auth=$(echo -n "mtmonacelli:$PASSWORD" | python -m base64)

# wrap in json that podman will recognize
tmp=/tmp
cat <<__eot__ >$tmp/auth.json
{
  "auths": {
    "registry.redhat.io": {
      "auth": "$auth"
    }
  }
}
__eot__
cat $tmp/auth.json

curl -sflL 'https://raw.githubusercontent.com/appveyor/secure-file/master/install.sh' | bash -e -
secret=$(python3 -c "import uuid; print(uuid.uuid4())")
echo $secret >/tmp/secret

salt=$(./appveyor-tools/secure-file -encrypt $tmp/auth.json -secret $secret -out $tmp/auth.json.enc | cut -d: -f2 | tr -d ' ')
# ls $tmp/auth.json.enc
echo $salt >/tmp/salt

# now try decrypting it to verify it all worked
./appveyor-tools/secure-file -decrypt $tmp/auth.json.enc -secret $secret -salt "$salt" -out $tmp/auth.json.decrypted
# ls $tmp/auth.json.decrypted
cat $tmp/auth.json.decrypted

credentials=$(jq -r .auths.'"registry.redhat.io"'.auth $tmp/auth.json.decrypted | python -m base64 -d)
echo $credentials

cp /tmp/auth.json.enc .

ls /tmp/salt
ls /tmp/secret
