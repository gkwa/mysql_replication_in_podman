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



podman ps --pod
podman container stop --ignore my1c my2c my3c my4c my5c
podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod stop --force --time=10s --ignore my1p my2p my3p my4p my5p
podman pod ls 

for i in {1..5}; do rm -rf --preserve-root $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint')/*; done
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done

podman pod start my1p my2p my3p my4p my5p

for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done

podman pod ls 
podman logs --since=30s my1c 

until podman healthcheck run my1c </dev/null; do sleep 5; done
until podman healthcheck run my2c </dev/null; do sleep 5; done
until podman healthcheck run my3c </dev/null; do sleep 5; done
until podman healthcheck run my4c </dev/null; do sleep 5; done
until podman healthcheck run my5c </dev/null; do sleep 5; done

position=$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my1c source:my5c position:$position
podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my2c source:my1c position:$position
podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my3c source:my2c position:$position
podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my4c source:my3c position:$position
podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my5c source:my4c position:$position
podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'
sleep 1
podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'USE ptest'





podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'SHOW GLOBAL VARIABLES LIKE "skip_name_resolve"'

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'localhost' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'localhost'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES'
podman logs --since=10s my1c 

podman exec --env=MYSQL_PWD=repl my1c mysql --host=my1p --user=repl --execute 'SHOW GLOBAL VARIABLES LIKE "skip_name_resolve"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user'

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'my2p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my2p.dns.podname'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES'
podman logs --since=10s my1c 

podman exec --env=MYSQL_PWD=repl my2c mysql --host=my1p --user=repl --execute 'SHOW GLOBAL VARIABLES LIKE "skip_name_resolve"'

# repl@my2p.dns.podname

podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'SHOW GLOBAL VARIABLES LIKE "skip_name_resolve"'

for i in {1..5}; do rm -rf --preserve-root $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint')/*; done
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done
podman container start my1c my2c my3c my4c my5c
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done
podman pod ls 

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'my2p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my2p.dns.podname'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES'
podman logs my1c

podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'SHOW VARIABLES' | grep skip_name_resolve

podman pod ls 
podman pod start --all
until podman healthcheck run my1c </dev/null; do sleep 5; done
until podman healthcheck run my2c </dev/null; do sleep 5; done
until podman healthcheck run my3c </dev/null; do sleep 5; done
until podman healthcheck run my4c </dev/null; do sleep 5; done
until podman healthcheck run my5c </dev/null; do sleep 5; done
podman logs 

podman container start my1c my2c my3c my4c my5c
until podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute 'SHOW DATABASES'; do sleep 5; done;

for i in {1..5}; do rm -rf $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint')/*; done
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done
podman container start my1c my2c my3c my4c my5c
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done
podman wait my1c my2c my3c my4c my5c --condition=running
for i in {1..5}; do podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE mysql'; done

podman healthcheck run my1c

sleep 20

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES'

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

position=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo $position
podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo $position
podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo $position
podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo $position
podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo $position
podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"

for i in {1..5}; do podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my${i}p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'; done

echo waiting for replication to be ready...
sleep=3; tries=5
for i in {1..5}; do loop1 repcheck my1c my${i}p.dns.podman $sleep $tries;  done

