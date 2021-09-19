#!/usr/bin/env bats

cleanall() {
    podman pod stop --ignore --all
    podman images prune
    podman container stop --ignore --all
    podman pod rm --all --force
    podman container rm --all --force
    podman volume rm --all --force
    for network in $(podman network ls --format json | jq -r '.[].Name'); do
        if [[ $network != "podman" ]]; then
            if podman network exists $network
            then
                podman network rm $network
            fi
        fi
    done
    podman pod stop --ignore --all
    podman images prune
    podman container stop --ignore --all
    podman pod rm --all --force
    podman container rm --all --force
    podman volume rm --all --force
    for network in $(podman network ls --format json | jq -r '.[].Name'); do
        if [[ $network != "podman" ]]; then
            if podman network exists $network
            then
                podman network rm $network
            fi
        fi
    done
    podman ps
    podman ps --pod
    podman ps -a --pod
    podman network ls
    podman volume ls
    podman pod ls
}

repcheck() {
    jump_container=$1
    target_host=$2

    result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')

    grep --silent 'Slave_IO_Running: Yes' <<<"$result"
    r1=$?

    grep --silent 'Slave_SQL_Running: Yes' <<<"$result"
    r2=$?

    [ $r1 -eq 0 ] && [ $r2 -eq 0 ]
}

loop2() {
    func=$1
    container=$2
    sleep=$3
    maxcalls=$4

    count=1
    while ! ($func $container); do
        echo trying $func... $count
        sleep $sleep
        let count+=1

        if [[ $count -ge $maxcalls ]]; then
            return 1
        fi
    done
}

loop1() {
    func=$1
    jump_container=$2
    target_host=$3
    sleep=$4
    maxcalls=$5

    count=1
    while ! ($func $jump_container $target_host); do
        echo trying $func... $count
        sleep $sleep
        let count+=1

        if [[ $count -ge $maxcalls ]]; then
            return 1
        fi
    done
}

healthcheck() {
    container=$1

    podman healthcheck run $container </dev/null
    r1=$?

    [ $r1 -eq 0 ]
}

@test 'test_statement_based_binlog_format' {






result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]






}