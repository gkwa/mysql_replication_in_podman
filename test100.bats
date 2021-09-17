source ./common.sh

@test 'test100' {
    bash ./test20210914_4.sh

    run bats simple_insert.bats
    [ "$status" -eq 0 ]
}
