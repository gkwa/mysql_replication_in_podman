@test "decrypt key" {

./appveyor-tools/secure-file -decrypt ./auth.json.enc -secret $my_secret -salt $my_salt -out /tmp/auth.json.decrypted

}
