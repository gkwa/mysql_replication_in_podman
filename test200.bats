source ./common.sh

@test 'test200' {
    bash ./test20210914_4.sh

    run bats test_ensure_replication_is_running.bats
    [ "$status" -eq 0 ]

    run cleanall
    [ "$status" -eq 0 ]

    bash ./test20210914_4.sh
    run bats test_ensure_replication_is_running.bats
    [ "$status" -eq 0 ]

    bash ./test20210914_4.sh
    run bats test_ensure_replication_is_running.bats
    [ "$status" -eq 0 ]
}
