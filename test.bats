@test "test1" {
    run podman ls
    [ $status -eq 0]
    [ $(echo $output | grep -c Running) -eq 4 ]
}
