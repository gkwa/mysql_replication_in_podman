#!/usr/bin/env bats

cleanall() {
    for i in {1..2}; do
        podman pod stop --ignore --all
        podman container stop --ignore --all
        podman pod rm --all --force
        podman container rm --all --force
        podman image prune --all --force
        podman volume rm --all --force
        for network in $(podman network ls --format json | jq -r '.[].Name'); do
            if [[ $network != "podman" ]]; then
                podman network exists $network && podman network rm $network
            fi
        done
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

    result=$(podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')

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

@test 'test_percona_checksums' {

echo mysql: start replication
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
echo mysql: wait for replication to be ready
sleep=2; tries=60
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries

podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest'

run podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p --execute 'USE ptest'
[ "$status" -eq 1 ]

run podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --execute 'USE ptest'
[ "$status" -eq 1 ]

podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS ptest\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --database=ptest --host=my4p --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --database=ptest --host=my4p --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'

result=$(podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --database=ptest --skip-column-names --execute 'SELECT id FROM dummy WHERE name="a"')
[ $result -eq 1 ]

result=$(podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --database=ptest --skip-column-names --execute 'SELECT id FROM dummy WHERE name="c"')
[ "$result" == "" ]

# disabled for now.  django complains about using binlog_format=STATEMENT and pt-table-checksum complains about using binlog_format=ROW from https://bit.ly/3zL5Zxx

# podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=rootpass percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my1p.dns.podman,u=root,p=rootpass,P=3306
# podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=rootpass percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my2p.dns.podman,u=root,p=rootpass,P=3306
# podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=rootpass percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my3p.dns.podman,u=root,p=rootpass,P=3306
# podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=rootpass percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my4p.dns.podman,u=root,p=rootpass,P=3306
# podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=rootpass percona-toolkit pt-table-checksum --replicate=percona.checksums --ignore-databases=sys,mysql h=my5p.dns.podman,u=root,p=rootpass,P=3306


}
