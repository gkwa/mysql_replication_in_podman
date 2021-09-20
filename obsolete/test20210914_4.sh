#!/bin/bash

# podman pod stop --ignore --all; podman images prune; podman container stop --ignore --all; podman pod rm --all --force; podman container rm --all --force; podman volume rm --all --force; for network in $(podman network ls --format json | jq -r '.[].Name'); do if [[ "$network" !=  "podman" ]]; then podman network exists $network && podman network rm $network; fi; done; podman pod stop --ignore --all; podman images prune; podman container stop --ignore --all; podman pod rm --all --force; podman container rm --all --force; podman volume rm --all --force; for network in $(podman network ls --format json | jq -r '.[].Name'); do if [[ "$network" !=  "podman" ]]; then podman network exists $network && podman network rm $network; fi; done; podman ps; podman ps --pod; podman ps -a --pod; podman network ls; podman volume ls; podman pod ls; #destroyall

set -o errexit

podman info --debug

# FIXME: NoneNoneNoneNoneNone

set +o errexit
podman container stop --log-level debug --ignore my1c my2c my3c my4c my5c
set -o errexit

podman pod exists my1p && podman pod stop --log-level debug --ignore my1p
podman pod exists my2p && podman pod stop --log-level debug --ignore my2p
podman pod exists my3p && podman pod stop --log-level debug --ignore my3p
podman pod exists my4p && podman pod stop --log-level debug --ignore my4p
podman pod exists my5p && podman pod stop --log-level debug --ignore my5p

podman pod exists my1p && podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod exists my2p && podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod exists my3p && podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod exists my4p && podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod exists my5p && podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod ls

rm -rf reptest
mkdir reptest

cat <<'__eot__' >reptest/my1c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = 1
auto_increment_offset          = 1
bind-address                   = my1p.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
__eot__

cat <<'__eot__' >reptest/my2c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = 2
auto_increment_offset          = 2
bind-address                   = my2p.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
__eot__

cat <<'__eot__' >reptest/my3c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = 3
auto_increment_offset          = 3
bind-address                   = my3p.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
__eot__

cat <<'__eot__' >reptest/my4c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = 4
auto_increment_offset          = 4
bind-address                   = my4p.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
__eot__

cat <<'__eot__' >reptest/my5c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = 5
auto_increment_offset          = 5
bind-address                   = my5p.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
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

podman volume exists my1dbdata || podman volume create my1dbdata
podman volume exists my2dbdata || podman volume create my2dbdata
podman volume exists my3dbdata || podman volume create my3dbdata
podman volume exists my4dbdata || podman volume create my4dbdata
podman volume exists my5dbdata || podman volume create my5dbdata

podman network exists replication || podman network create replication

podman pod exists my1p || podman pod create --name=my1p --publish=33061:3306 --network=replication
podman pod exists my2p || podman pod create --name=my2p --publish=33062:3306 --network=replication
podman pod exists my3p || podman pod create --name=my3p --publish=33063:3306 --network=replication
podman pod exists my4p || podman pod create --name=my4p --publish=33064:3306 --network=replication
podman pod exists my5p || podman pod create --name=my5p --publish=33065:3306 --network=replication

podman container exists my1c || podman container create --name=my1c --pod=my1p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/my1c_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user=root --password="root" --host=my1p --execute "USE mysql" || exit 1' --volume=my1dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container exists my2c || podman container create --name=my2c --pod=my2p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/my2c_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user=root --password="root" --host=my2p --execute "USE mysql" || exit 1' --volume=my2dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container exists my3c || podman container create --name=my3c --pod=my3p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/my3c_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user=root --password="root" --host=my3p --execute "USE mysql" || exit 1' --volume=my3dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container exists my4c || podman container create --name=my4c --pod=my4p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/my4c_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user=root --password="root" --host=my4p --execute "USE mysql" || exit 1' --volume=my4dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container exists my5c || podman container create --name=my5c --pod=my5p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/my5c_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user=root --password="root" --host=my5p --execute "USE mysql" || exit 1' --volume=my5dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80

rm -rf --preserve-root $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/*
rm -rf --preserve-root $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/*

du -sh $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')/
du -sh $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')/
du -sh $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')/
du -sh $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')/
du -sh $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')/

du -shc $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')

set +o errexit
podman pod start my1p my2p my3p my4p my5p
set -o errexit
podman pod start my1p my2p my3p my4p my5p

du -shc $(podman volume inspect my1dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my2dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my3dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my4dbdata | jq -r '.[]|.Mountpoint')
du -shc $(podman volume inspect my5dbdata | jq -r '.[]|.Mountpoint')

podman pod ls
podman logs --since=30s my1c

until podman healthcheck run my1c </dev/null; do sleep 3; done
until podman healthcheck run my2c </dev/null; do sleep 3; done
until podman healthcheck run my3c </dev/null; do sleep 3; done
until podman healthcheck run my4c </dev/null; do sleep 3; done
until podman healthcheck run my5c </dev/null; do sleep 3; done

# 'repl'@'%' on my1c:
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES'
# 'repl'@'%' on my2c:
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES'
# 'repl'@'%' on my3c:
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES'
# 'repl'@'%' on my4c:
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES'
# 'repl'@'%' on my5c:
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES'

position=$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my1c source:my5c position:$position
podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my2c source:my1c position:$position
podman exec --env=MYSQL_PWD=root my2c mysql --host=my2p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my3c source:my2c position:$position
podman exec --env=MYSQL_PWD=root my3c mysql --host=my3p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my4c source:my3c position:$position
podman exec --env=MYSQL_PWD=root my4c mysql --host=my4p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my5c source:my4c position:$position
podman exec --env=MYSQL_PWD=root my5c mysql --host=my5p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'

podman exec --env=MYSQL_PWD=root my1c mysql --host=my1p --user=root --execute 'USE ptest' && echo my1p ok
podman exec --env=MYSQL_PWD=root my1c mysql --host=my2p --user=root --execute 'USE ptest' && echo my2p ok
podman exec --env=MYSQL_PWD=root my1c mysql --host=my3p --user=root --execute 'USE ptest' && echo my3p ok
podman exec --env=MYSQL_PWD=root my1c mysql --host=my4p --user=root --execute 'USE ptest' && echo my4p ok
podman exec --env=MYSQL_PWD=root my1c mysql --host=my5p --user=root --execute 'USE ptest' && echo my5p ok

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW VARIABLES LIKE "binlog_format"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --execute 'SHOW VARIABLES LIKE "binlog_format"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --execute 'SHOW VARIABLES LIKE "binlog_format"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --execute 'SHOW VARIABLES LIKE "binlog_format"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --execute 'SHOW VARIABLES LIKE "binlog_format"'
