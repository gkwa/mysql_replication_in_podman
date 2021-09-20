#!/usr/bin/env bats

@test "debian" {
    sudo bats setup_debian.bats
}

@test "create setup" {
    sudo bash create_setup.sh
}

@test "secure file setup" {
    sudo bats secure_file_setup.bats
}

@test "decrypt" {
    sudo bats decrypt.bats
}

@test "containers" {
    sudo bats containers.bats
}
