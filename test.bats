@test "test1" {
    result=$(podman ls | grep -c Running)
    [ "$result" -eq 4 ]
}
