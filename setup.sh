#!/bin/bash

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
set -o errexit

podman pull --quiet docker.io/perconalab/percona-toolkit:latest >/dev/null
podman pull --quiet registry.redhat.io/rhel8/mysql-80 >/dev/null

set +o errexit
podman container stop --log-level debug --ignore
set -o errexit

podman pod exists my1p && podman pod stop --log-level debug --ignore my1p
podman pod exists my2p && podman pod stop --log-level debug --ignore my2p
podman pod exists my3p && podman pod stop --log-level debug --ignore my3p
podman pod exists my4p && podman pod stop --log-level debug --ignore my4p
podman pod exists my5p && podman pod stop --log-level debug --ignore my5p

podman pod exists my1p && podman wait --condition=stopped
podman pod exists my2p && podman wait --condition=stopped
podman pod exists my3p && podman wait --condition=stopped
podman pod exists my4p && podman wait --condition=stopped
podman pod exists my5p && podman wait --condition=stopped
podman pod ls

rm -rf reptest
mkdir reptest

cat <<'__eot__' >reptest/my1c_my.cnf
[mysqld]
server_id                      = 1
auto_increment_offset          = 1
bind-address                   = my1p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
__eot__

cat <<'__eot__' >reptest/my2c_my.cnf
[mysqld]
server_id                      = 2
auto_increment_offset          = 2
bind-address                   = my2p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
__eot__

cat <<'__eot__' >reptest/my3c_my.cnf
[mysqld]
server_id                      = 3
auto_increment_offset          = 3
bind-address                   = my3p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
__eot__

cat <<'__eot__' >reptest/my4c_my.cnf
[mysqld]
server_id                      = 4
auto_increment_offset          = 4
bind-address                   = my4p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
__eot__

cat <<'__eot__' >reptest/my5c_my.cnf
[mysqld]
server_id                      = 5
auto_increment_offset          = 5
bind-address                   = my5p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
__eot__

cat reptest/my1c_my.cnf
echo
cat reptest/my2c_my.cnf
echo
cat reptest/my3c_my.cnf
echo
cat reptest/my4c_my.cnf
echo
cat reptest/my5c_my.cnf
echo

echo creating volumes
podman volume exists my1dbdata || podman volume create my1dbdata >/dev/null
podman volume exists my2dbdata || podman volume create my2dbdata >/dev/null
podman volume exists my3dbdata || podman volume create my3dbdata >/dev/null
podman volume exists my4dbdata || podman volume create my4dbdata >/dev/null
podman volume exists my5dbdata || podman volume create my5dbdata >/dev/null

echo creating network
podman network exists replication || podman network create replication >/dev/null

echo creating pods
podman pod exists my1p ||
    podman pod create --name=my1p --publish=33061:3306 --network=replication >/dev/null
podman pod exists my2p ||
    podman pod create --name=my2p --publish=33062:3306 --network=replication >/dev/null
podman pod exists my3p ||
    podman pod create --name=my3p --publish=33063:3306 --network=replication >/dev/null
podman pod exists my4p ||
    podman pod create --name=my4p --publish=33064:3306 --network=replication >/dev/null
podman pod exists my5p ||
    podman pod create --name=my5p --publish=33065:3306 --network=replication >/dev/null

echo creating containers
podman container exists my1c || podman container create registry.redhat.io/rhel8/mysql-80 \
    --name=my1c \
    --pod=my1p \
    --log-driver=journald \
    --healthcheck-interval=0 \
    --health-retries=10 \
    --health-timeout=30s \
    --health-start-period=80s \
    --healthcheck-command 'CMD-SHELL mysql --user=root --password="root" --host=my1p --execute "USE mysql" || exit 1' \
    --volume=./reptest/my1c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
    --volume=my1dbdata:/var/lib/mysql/data:Z \
    --env=MYSQL_ROOT_PASSWORD=root \
    --env=MYSQL_USER=joe \
    --env=MYSQL_PASSWORD=joe \
    --env=MYSQL_DATABASE=db >/dev/null
podman container exists my2c || podman container create registry.redhat.io/rhel8/mysql-80 \
    --name=my2c \
    --pod=my2p \
    --log-driver=journald \
    --healthcheck-interval=0 \
    --health-retries=10 \
    --health-timeout=30s \
    --health-start-period=80s \
    --healthcheck-command 'CMD-SHELL mysql --user=root --password="root" --host=my2p --execute "USE mysql" || exit 1' \
    --volume=./reptest/my2c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
    --volume=my2dbdata:/var/lib/mysql/data:Z \
    --env=MYSQL_ROOT_PASSWORD=root \
    --env=MYSQL_USER=joe \
    --env=MYSQL_PASSWORD=joe \
    --env=MYSQL_DATABASE=db >/dev/null
podman container exists my3c || podman container create registry.redhat.io/rhel8/mysql-80 \
    --name=my3c \
    --pod=my3p \
    --log-driver=journald \
    --healthcheck-interval=0 \
    --health-retries=10 \
    --health-timeout=30s \
    --health-start-period=80s \
    --healthcheck-command 'CMD-SHELL mysql --user=root --password="root" --host=my3p --execute "USE mysql" || exit 1' \
    --volume=./reptest/my3c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
    --volume=my3dbdata:/var/lib/mysql/data:Z \
    --env=MYSQL_ROOT_PASSWORD=root \
    --env=MYSQL_USER=joe \
    --env=MYSQL_PASSWORD=joe \
    --env=MYSQL_DATABASE=db >/dev/null
podman container exists my4c || podman container create registry.redhat.io/rhel8/mysql-80 \
    --name=my4c \
    --pod=my4p \
    --log-driver=journald \
    --healthcheck-interval=0 \
    --health-retries=10 \
    --health-timeout=30s \
    --health-start-period=80s \
    --healthcheck-command 'CMD-SHELL mysql --user=root --password="root" --host=my4p --execute "USE mysql" || exit 1' \
    --volume=./reptest/my4c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
    --volume=my4dbdata:/var/lib/mysql/data:Z \
    --env=MYSQL_ROOT_PASSWORD=root \
    --env=MYSQL_USER=joe \
    --env=MYSQL_PASSWORD=joe \
    --env=MYSQL_DATABASE=db >/dev/null
podman container exists my5c || podman container create registry.redhat.io/rhel8/mysql-80 \
    --name=my5c \
    --pod=my5p \
    --log-driver=journald \
    --healthcheck-interval=0 \
    --health-retries=10 \
    --health-timeout=30s \
    --health-start-period=80s \
    --healthcheck-command 'CMD-SHELL mysql --user=root --password="root" --host=my5p --execute "USE mysql" || exit 1' \
    --volume=./reptest/my5c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
    --volume=my5dbdata:/var/lib/mysql/data:Z \
    --env=MYSQL_ROOT_PASSWORD=root \
    --env=MYSQL_USER=joe \
    --env=MYSQL_PASSWORD=joe \
    --env=MYSQL_DATABASE=db >/dev/null

echo removing data from volume, but leaving volume in place
rm -rf --preserve-root $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/*

echo check data directory is cleaned out
size=$(du -s $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -le 8 ]]
size=$(du -s $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -le 8 ]]
size=$(du -s $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -le 8 ]]
size=$(du -s $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -le 8 ]]
size=$(du -s $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -le 8 ]]

set +o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null
set -o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null

# podman pod ls
# podman logs --since=30s my1c

echo waiting for container healthcheck
until podman healthcheck run my1c </dev/null; do sleep 3; done
until podman healthcheck run my2c </dev/null; do sleep 3; done
until podman healthcheck run my3c </dev/null; do sleep 3; done
until podman healthcheck run my4c </dev/null; do sleep 3; done
until podman healthcheck run my5c </dev/null; do sleep 3; done

echo 'check data directory is larger than 90MB (tends to be ~97MB)'
size=$(du -s $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 90000 ]]
size=$(du -s $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 90000 ]]
size=$(du -s $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 90000 ]]
size=$(du -s $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 90000 ]]
size=$(du -s $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 90000 ]]

echo granting repl user replication permission
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute \
    "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute \
    "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute \
    "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute \
    "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute \
    "CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'FLUSH PRIVILEGES'

position=$(
    podman exec --env=MYSQL_PWD=root my5c \
        mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(
    podman exec --env=MYSQL_PWD=root my1c \
        mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(
    podman exec --env=MYSQL_PWD=root my2c \
        mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(
    podman exec --env=MYSQL_PWD=root my3c \
        mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(
    podman exec --env=MYSQL_PWD=root my4c \
        mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"

echo start replication
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
