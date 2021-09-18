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
        echo trying... $count
        sleep $sleep
        let count+=1

        if [[ $count -ge $maxcalls ]]; then
            return 1
        fi
    done
}

@test 'test_percona_checksums' {



podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest'

run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'USE ptest'
[ "$status" -eq 1 ]

run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --execute 'USE ptest'
[ "$status" -eq 1 ]

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'SELECT * FROM dummy'

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="a"')
[ $result -eq 0 ]

result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="c"')
[ "$result" == "" ]



podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my1p.dns.podman,u=root,p=root,P=3306
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my2p.dns.podman,u=root,p=root,P=3306
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my3p.dns.podman,u=root,p=root,P=3306
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my4p.dns.podman,u=root,p=root,P=3306
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my5p.dns.podman,u=root,p=root,P=3306








}
