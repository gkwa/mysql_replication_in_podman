#!/bin/bash

set -o errexit
set +o history

PASSWORD="$1"

echo $PASSWORD

# base64 encode basic credentials
auth=$(echo -n "mtmonacelli:$PASSWORD" | python -m base64)

# wrap in json that podman will recognize
tmp=/tmp/sensitive

mkdir -p $tmp

cat <<__eot__ >$tmp/auth.json.tmp
{
  "auths": {
    "registry.redhat.io": {
      "auth": "$auth"
    }
  }
}
__eot__
cat $tmp/auth.json.tmp |python -m base64 >$tmp/auth.json
rm -f $tmp/auth.json.tmp

curl -sflL 'https://raw.githubusercontent.com/appveyor/secure-file/master/install.sh' | bash -e -
secret=$(python3 -c "import uuid; print(uuid.uuid4())")
echo -n "$secret" >$tmp/secret

salt=$(./appveyor-tools/secure-file -encrypt $tmp/auth.json -secret $secret -out $tmp/auth.json.enc | sed -e 's#Salt: *##')
rm -f $tmp/auth.json.enc.tmp
echo -n "$salt" |python -m base64 >$tmp/salt

# now try decrypting it to verify it all worked
./appveyor-tools/secure-file -decrypt $tmp/auth.json.enc -secret "$secret" -salt "$salt" -out $tmp/auth.json.decrypted.tmp
cat $tmp/auth.json.decrypted.tmp |python -m base64 -d >$tmp/auth.json.decrypted
rm -f $tmp/auth.json.decrypted.tmp


credentials=$(jq -r .auths.'"registry.redhat.io"'.auth $tmp/auth.json.decrypted | python -m base64 -d)
echo $credentials

cp $tmp/auth.json.enc .
ls $tmp/salt
ls $tmp/secret
