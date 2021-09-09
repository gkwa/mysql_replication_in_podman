@test "test1" {
    result=$(podman ls | grep -c Running)
    [ "$result" -eq 4 ]
}

@test "test2" {
    [ $(podman ls | grep -cE 'my1p.*Running') -eq 1 ]
    [ $(podman ls | grep -cE 'my2p.*Running') -eq 1 ]
    [ $(podman ls | grep -cE 'my3p.*Running') -eq 1 ]
    [ $(podman ls | grep -cE 'my4p.*Running') -eq 1 ]
}
