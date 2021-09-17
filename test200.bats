source ./common.sh

@test 'test200' {
    bash ./test20210914_4.sh

    run bats simple_insert.bats
    [ "$status" -eq 0 ]

    run cleanall
    [ "$status" -eq 0 ]

    bash ./test20210914_4.sh
    run bats simple_insert.bats
    [ "$status" -eq 1 ]

    bash ./test20210914_4.sh
    run bats simple_insert.bats
    [ "$status" -eq 0 ]
}
