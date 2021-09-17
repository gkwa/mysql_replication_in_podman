source ./common.sh

@test 'test100' {
    bash ./test20210914_4.sh

    run bats test_simple_insert.bats
    [ "$status" -eq 0 ]
}
