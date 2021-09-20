#!/bin/bash

set -o errexit

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

echo waiting for replication to be ready...
sleep=3
tries=20
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries

echo ensuring we can reach mysqld
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' | grep --quiet mysql
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' | grep --quiet mysql
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' | grep --quiet mysql
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' | grep --quiet mysql
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' | grep --quiet mysql

echo pt-table-checksum replicates percona table to all
set +o errexit
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my1p.dns.podman,u=root,p=root,P=3306
set -o errexit
# podman run --pod=my2p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my2p.dns.podman,u=root,p=root,P=3306
# podman run --pod=my3p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my3p.dns.podman,u=root,p=root,P=3306
# podman run --pod=my4p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my4p.dns.podman,u=root,p=root,P=3306
# podman run --pod=my5p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my5p.dns.podman,u=root,p=root,P=3306

until grep --silent percona <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES\G')"; do sleep 5; done
until grep --silent percona <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES\G')"; do sleep 5; done
until grep --silent percona <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES\G')"; do sleep 5; done
until grep --silent percona <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES\G')"; do sleep 5; done
until grep --silent percona <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES\G')"; do sleep 5; done

podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my1p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print
podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my2p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print
podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my3p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print
podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my4p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print
podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my5p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print

echo waiting for replication to be ready...
sleep=3
tries=20
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries

cat <<'__eot__' >reptest/extra2/20210912_1.sql
DROP DATABASE IF EXISTS ptest;
CREATE DATABASE IF NOT EXISTS ptest;
USE ptest;
CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;
-- INSERT INTO dummy (id, name) VALUES (1, 'a'), (2, 'b');
SELECT * FROM dummy;
__eot__
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/20210912_1.sql'

until podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'SHOW DATABASES'; do sleep 5; done
until podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute 'SHOW DATABASES'; do sleep 5; done
until podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute 'SHOW DATABASES'; do sleep 5; done
until podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute 'SHOW DATABASES'; do sleep 5; done
until podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute 'SHOW DATABASES'; do sleep 5; done

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'

set +o errexit
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my1p.dns.podman,u=root,p=root,P=3306
#podman run --pod=my1p --env=PTDEBUG=1 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my2p.dns.podman,u=root,p=root,P=3306
#podman run --pod=my1p --env=PTDEBUG=1 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my3p.dns.podman,u=root,p=root,P=3306
#podman run --pod=my1p --env=PTDEBUG=1 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my4p.dns.podman,u=root,p=root,P=3306
#podman run --pod=my1p --env=PTDEBUG=1 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my5p.dns.podman,u=root,p=root,P=3306
set -o errexit

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

cat <<'__eot__' >reptest/extra2/20210913_10.sql
USE ptest;
-- INSERT INTO dummy (id, name) VALUES (11, 'xxxxx');
INSERT INTO dummy (name) VALUES ('xxxxx');
SELECT * FROM dummy;
__eot__
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_10.sql'
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_10.sql'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_10.sql'
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_10.sql'
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_10.sql'

cat <<'__eot__' >reptest/extra2/20210913_20.sql
USE ptest;
-- INSERT INTO dummy (id, name) VALUES (12, 'yyy'); # use this to break stuff
INSERT INTO dummy (name) VALUES ('yyy');
SELECT * FROM dummy;
__eot__
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_20.sql'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_20.sql'
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_20.sql'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_20.sql'
#podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SOURCE /tmp/extra2/20210913_20.sql'

echo starting replication
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'

echo waiting for replication to be ready...
sleep=3
tries=20
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries

set +o errexit
podman run --pod=my1p --env=PTDEBUG=0 --env=MYSQL_PWD=root percona-toolkit pt-table-checksum --replicate=percona.checksums h=my1p.dns.podman,u=root,p=root,P=3306
set -o errexit

podman run --pod=my1p --env=MYSQL_PWD=root percona-toolkit pt-table-sync --sync-to-master h=my1p.dns.podman,u=root,p=root,P=3306 --databases=ptest --tables=dummy --verbose --print

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --database=ptest --execute 'SELECT * FROM dummy'
