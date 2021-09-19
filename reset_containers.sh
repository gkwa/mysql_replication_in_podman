#!/bin/bash
set -o errexit
set +o errexit
podman container stop --ignore my1c my2c my3c my4c my5c 2>podman_stop_containers_$(date +%s).log >/dev/null
set -o errexit
podman container exists my1c && podman container stop --ignore my1c >/dev/null
podman container exists my2c && podman container stop --ignore my2c >/dev/null
podman container exists my3c && podman container stop --ignore my3c >/dev/null
podman container exists my4c && podman container stop --ignore my4c >/dev/null
podman container exists my5c && podman container stop --ignore my5c >/dev/null

podman pod exists my1p && podman pod stop my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod stop my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod stop my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod stop my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod stop my5p --ignore my5p >/dev/null

podman container rm --force --ignore my1c
podman container rm --force --ignore my2c
podman container rm --force --ignore my3c
podman container rm --force --ignore my4c
podman container rm --force --ignore my5c

set +o errexit

podman pod rm --force my1p --ignore my1p >/dev/null
podman pod rm --force my2p --ignore my2p >/dev/null
podman pod rm --force my3p --ignore my3p >/dev/null
podman pod rm --force my4p --ignore my4p >/dev/null
podman pod rm --force my5p --ignore my5p >/dev/null
set -o errexit

podman pod exists my1p && podman pod rm --force my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod rm --force my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod rm --force my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod rm --force my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod rm --force my5p --ignore my5p >/dev/null

podman pod ls

echo create volumes
podman volume exists my1dbdata || podman volume create my1dbdata >/dev/null
podman volume exists my2dbdata || podman volume create my2dbdata >/dev/null
podman volume exists my3dbdata || podman volume create my3dbdata >/dev/null
podman volume exists my4dbdata || podman volume create my4dbdata >/dev/null
podman volume exists my5dbdata || podman volume create my5dbdata >/dev/null

echo create network
podman network exists replication || podman network create replication >/dev/null

mkdir -p reptest

cat <<'__eot__' >reptest/my1c_my.cnf
[mysqld]
server_id                      = 1
auto_increment_offset          = 1
bind-address                   = my1p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
__eot__

cat reptest/my1c_my.cnf && echo
cat reptest/my2c_my.cnf && echo
cat reptest/my3c_my.cnf && echo
cat reptest/my4c_my.cnf && echo
cat reptest/my5c_my.cnf && echo

echo create pods
podman pod exists my1p || podman pod create --name=my1p --publish=33061:3306 --network=replication >/dev/null
podman pod exists my2p || podman pod create --name=my2p --publish=33062:3306 --network=replication >/dev/null
podman pod exists my3p || podman pod create --name=my3p --publish=33063:3306 --network=replication >/dev/null
podman pod exists my4p || podman pod create --name=my4p --publish=33064:3306 --network=replication >/dev/null
podman pod exists my5p || podman pod create --name=my5p --publish=33065:3306 --network=replication >/dev/null

echo create containers
podman container exists my1c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my2c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my3c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my4c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my5c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null

set +o errexit
podman pod start my1p my2p my3p my4p my5p 2>podman_start_pods_$(date +%s).log >/dev/null
set -o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null

echo 'wait for container healthcheck(s)'
sleep=4
tries=20
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries

echo 'check data directory is larger than 80MB, ~97MB is expected size'
size=$(du -s $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]

# repeat

set +o errexit
podman container stop --ignore my1c my2c my3c my4c my5c 2>podman_stop_containers_$(date +%s).log >/dev/null
set -o errexit
podman container exists my1c && podman container stop --ignore my1c >/dev/null
podman container exists my2c && podman container stop --ignore my2c >/dev/null
podman container exists my3c && podman container stop --ignore my3c >/dev/null
podman container exists my4c && podman container stop --ignore my4c >/dev/null
podman container exists my5c && podman container stop --ignore my5c >/dev/null

podman pod exists my1p && podman pod stop my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod stop my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod stop my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod stop my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod stop my5p --ignore my5p >/dev/null

podman container rm --force --ignore my1c
podman container rm --force --ignore my2c
podman container rm --force --ignore my3c
podman container rm --force --ignore my4c
podman container rm --force --ignore my5c

set +o errexit

podman pod rm --force my1p --ignore my1p >/dev/null
podman pod rm --force my2p --ignore my2p >/dev/null
podman pod rm --force my3p --ignore my3p >/dev/null
podman pod rm --force my4p --ignore my4p >/dev/null
podman pod rm --force my5p --ignore my5p >/dev/null
set -o errexit

podman pod exists my1p && podman pod rm --force my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod rm --force my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod rm --force my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod rm --force my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod rm --force my5p --ignore my5p >/dev/null

podman pod ls

echo create volumes
podman volume exists my1dbdata || podman volume create my1dbdata >/dev/null
podman volume exists my2dbdata || podman volume create my2dbdata >/dev/null
podman volume exists my3dbdata || podman volume create my3dbdata >/dev/null
podman volume exists my4dbdata || podman volume create my4dbdata >/dev/null
podman volume exists my5dbdata || podman volume create my5dbdata >/dev/null

echo create network
podman network exists replication || podman network create replication >/dev/null

mkdir -p reptest

cat <<'__eot__' >reptest/my1c_my.cnf
[mysqld]
server_id                      = 1
auto_increment_offset          = 1
bind-address                   = my1p.dns.podman
log_bin                        = mysql-bin.log
binlog_format                  = STATEMENT
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
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
;slave-skip-errors              = 1050,1062,1032
__eot__

cat reptest/my1c_my.cnf && echo
cat reptest/my2c_my.cnf && echo
cat reptest/my3c_my.cnf && echo
cat reptest/my4c_my.cnf && echo
cat reptest/my5c_my.cnf && echo

echo create pods
podman pod exists my1p || podman pod create --name=my1p --publish=33061:3306 --network=replication >/dev/null
podman pod exists my2p || podman pod create --name=my2p --publish=33062:3306 --network=replication >/dev/null
podman pod exists my3p || podman pod create --name=my3p --publish=33063:3306 --network=replication >/dev/null
podman pod exists my4p || podman pod create --name=my4p --publish=33064:3306 --network=replication >/dev/null
podman pod exists my5p || podman pod create --name=my5p --publish=33065:3306 --network=replication >/dev/null

echo create containers
podman container exists my1c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my2c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my3c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my4c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my5c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null

set +o errexit
podman pod start my1p my2p my3p my4p my5p 2>podman_start_pods_$(date +%s).log >/dev/null
set -o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null

echo 'wait for container healthcheck(s)'
sleep=4
tries=20
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries

echo 'check data directory is larger than 80MB, ~97MB is expected size'
size=$(du -s $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]

epoch=$(date +%s)

macro=mysql_check_ptest1_does_not_exist
bats=${macro}_${epoch}.bats
cat <<'__eot__' >$bats
@test "mysql_check_ptest1_does_not_exist" {


run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1'
[ "$status" == 1 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1'
[ "$status" == 1 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1'
[ "$status" == 1 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1'
[ "$status" == 1 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1'
[ "$status" == 1 ]

}
__eot__
bats $bats

macro=mysql_create_database_ptest1
bats=${macro}_${epoch}.bats
cat <<'__eot__' >$bats
@test "mysql_create_database_ptest1" {

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest1'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --database=ptest1 --host=my1p --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --database=ptest1 --host=my1p --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'

}
__eot__
bats $bats

macro=mysql_check_ptest1_exists_everywhere
bats=${macro}_${epoch}.bats
cat <<'__eot__' >$bats
@test "mysql_check_ptest1_exists_everywhere" {


run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]

}
__eot__
bats $bats

set +o errexit
podman container stop --ignore my1c my2c my3c my4c my5c 2>podman_stop_containers_$(date +%s).log >/dev/null
set -o errexit
podman container exists my1c && podman container stop --ignore my1c >/dev/null
podman container exists my2c && podman container stop --ignore my2c >/dev/null
podman container exists my3c && podman container stop --ignore my3c >/dev/null
podman container exists my4c && podman container stop --ignore my4c >/dev/null
podman container exists my5c && podman container stop --ignore my5c >/dev/null

podman pod exists my1p && podman pod stop my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod stop my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod stop my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod stop my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod stop my5p --ignore my5p >/dev/null

podman container rm --force --ignore my1c
podman container rm --force --ignore my2c
podman container rm --force --ignore my3c
podman container rm --force --ignore my4c
podman container rm --force --ignore my5c

set +o errexit

podman pod rm --force my1p --ignore my1p >/dev/null
podman pod rm --force my2p --ignore my2p >/dev/null
podman pod rm --force my3p --ignore my3p >/dev/null
podman pod rm --force my4p --ignore my4p >/dev/null
podman pod rm --force my5p --ignore my5p >/dev/null
set -o errexit

podman pod exists my1p && podman pod rm --force my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod rm --force my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod rm --force my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod rm --force my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod rm --force my5p --ignore my5p >/dev/null

podman pod ls

echo create pods
podman pod exists my1p || podman pod create --name=my1p --publish=33061:3306 --network=replication >/dev/null
podman pod exists my2p || podman pod create --name=my2p --publish=33062:3306 --network=replication >/dev/null
podman pod exists my3p || podman pod create --name=my3p --publish=33063:3306 --network=replication >/dev/null
podman pod exists my4p || podman pod create --name=my4p --publish=33064:3306 --network=replication >/dev/null
podman pod exists my5p || podman pod create --name=my5p --publish=33065:3306 --network=replication >/dev/null

echo create containers
podman container exists my1c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my2c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my3c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my4c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null
podman container exists my5c || podman container create \
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
    --env=MYSQL_DATABASE=db \
    registry.redhat.io/rhel8/mysql-80 >/dev/null

set +o errexit
podman pod start my1p my2p my3p my4p my5p 2>podman_start_pods_$(date +%s).log >/dev/null
set -o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null

echo 'wait for container healthcheck(s)'
sleep=4
tries=20
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my1c $sleep $tries

echo 'check data directory is larger than 80MB, ~97MB is expected size'
size=$(du -s $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]
size=$(du -s $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/ | awk '{print $1}')
[[ $size -gt 80000 ]]

macro=mysql_check_ptest1_exists_everywhere
bats=${macro}_${epoch}.bats
cat <<'__eot__' >$bats
@test "mysql_check_ptest1_exists_everywhere" {


run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]
run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1'
[ "$status" == 0 ]

}
__eot__
bats $bats
