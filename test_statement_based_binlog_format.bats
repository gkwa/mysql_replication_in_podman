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
            podman network exists $network && podman network rm $network
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
            podman network exists $network && podman network rm $network
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

    result=$(podman exec --env=MYSQL_PWD=root $jump_container mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')

    grep --silent 'Slave_IO_Running: Yes' <<<"$result"
    r1=$?

    grep --silent 'Slave_SQL_Running: Yes' <<<"$result"
    r2=$?

    [ $r1 -eq 0 ] && [ $r2 -eq 0 ]
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
# healthcheck_fn() {
#     jump_container=$1
#     target_host=$2
# 
#     result=$(podman exec --env=MYSQL_PWD=root $jump_container mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')
# 
#     grep --silent 'Slave_IO_Running: Yes' <<<"$result"
#     r1=$?
# 
#     grep --silent 'Slave_SQL_Running: Yes' <<<"$result"
#     r2=$?
# 
#     [ $r1 -eq 0 ] && [ $r2 -eq 0 ]
# }

@test 'test_statement_based_binlog_format' {






result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
[ "$status" -eq 0 ]






}