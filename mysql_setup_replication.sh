#!/bin/bash

set -o errexit

podman info --debug
mysql --version

# FIXME: reminder: i'm using appveyor secrets to decrypt this from ./auth.json.enc, thats obscure
# podman login --username mtmonacelli registry.redhat.io $REGISTRY_REDHAT_IO_PASSWORD

podman pull docker.io/perconalab/percona-toolkit:latest

podman ps
podman ps --pod
podman ps -a --pod
podman network ls
podman volume ls
podman pod ls



podman pod stop --ignore my1p
podman pod rm --ignore --force my1p
podman volume exists my1dbdata && podman volume rm --force my1dbdata

podman pod stop --ignore my2p
podman pod rm --ignore --force my2p
podman volume exists my2dbdata && podman volume rm --force my2dbdata

podman pod stop --ignore my3p
podman pod rm --ignore --force my3p
podman volume exists my3dbdata && podman volume rm --force my3dbdata

podman pod stop --ignore my4p
podman pod rm --ignore --force my4p
podman volume exists my4dbdata && podman volume rm --force my4dbdata

podman pod stop --ignore my5p
podman pod rm --ignore --force my5p
podman volume exists my5dbdata && podman volume rm --force my5dbdata


podman network exists replication && podman network rm --force replication

podman ps
podman ps --pod
podman ps -a --pod
podman network ls
podman volume ls
podman pod ls


podman network create replication

podman volume create my1dbdata
podman volume create my2dbdata
podman volume create my3dbdata
podman volume create my4dbdata
podman volume create my5dbdata

# start clean
[[ -d 'reptest' ]] && mv reptest reptest.$(date +%s)

mkdir -p reptest/extra2
mkdir -p reptest/my1c/extra
mkdir -p reptest/my2c/extra
mkdir -p reptest/my3c/extra
mkdir -p reptest/my4c/extra
mkdir -p reptest/my5c/extra


mkdir -p reptest/my1c
cat <<'__eot__' >reptest/my1c/my.cnf
[mysqld]
bind-address                   = my1p.dns.podman
server_id                      = 1
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy
binlog_do_db                   = sales

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/my1c/my.cnf

mkdir -p reptest/my2c
cat <<'__eot__' >reptest/my2c/my.cnf
[mysqld]
bind-address                   = my2p.dns.podman
server_id                      = 2
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy
binlog_do_db                   = sales

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/my2c/my.cnf

mkdir -p reptest/my3c
cat <<'__eot__' >reptest/my3c/my.cnf
[mysqld]
bind-address                   = my3p.dns.podman
server_id                      = 3
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy
binlog_do_db                   = sales

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/my3c/my.cnf

mkdir -p reptest/my4c
cat <<'__eot__' >reptest/my4c/my.cnf
[mysqld]
bind-address                   = my4p.dns.podman
server_id                      = 4
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy
binlog_do_db                   = sales

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/my4c/my.cnf

mkdir -p reptest/my5c
cat <<'__eot__' >reptest/my5c/my.cnf
[mysqld]
bind-address                   = my5p.dns.podman
server_id                      = 5
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy
binlog_do_db                   = sales

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/my5c/my.cnf


# pods with bridge mode networking
podman pod create --name=my1p --publish=33061:3306 --network=replication
podman pod create --name=my2p --publish=33062:3306 --network=replication
podman pod create --name=my3p --publish=33063:3306 --network=replication
podman pod create --name=my4p --publish=33064:3306 --network=replication
podman pod create --name=my5p --publish=33065:3306 --network=replication

# mysqld containers
podman container create --name=my1c --pod=my1p --health-start-period=80s --log-driver=journald --volume=./reptest/my1c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/my1c/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume=my1dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my2c --pod=my2p --health-start-period=80s --log-driver=journald --volume=./reptest/my2c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/my2c/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume=my2dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my3c --pod=my3p --health-start-period=80s --log-driver=journald --volume=./reptest/my3c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/my3c/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume=my3dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my4c --pod=my4p --health-start-period=80s --log-driver=journald --volume=./reptest/my4c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/my4c/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume=my4dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my5c --pod=my5p --health-start-period=80s --log-driver=journald --volume=./reptest/my5c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/my5c/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume=my5dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80


podman pod start my1p
podman pod start my2p
podman pod start my3p
podman pod start my4p
podman pod start my5p


podman wait my1c --condition=running
podman wait my2c --condition=running
podman wait my3c --condition=running
podman wait my4c --condition=running
podman wait my5c --condition=running


podman volume inspect my1dbdata
podman volume inspect my2dbdata
podman volume inspect my3dbdata
podman volume inspect my4dbdata
podman volume inspect my5dbdata

podman ps
podman ps --pod
podman ps -a --pod
podman network ls
podman volume ls
podman pod ls



until podman exec --env=MYSQL_PWD=joe --tty --interactive my1c mysql --host=my1p --user=joe --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe --tty --interactive my2c mysql --host=my2p --user=joe --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe --tty --interactive my3c mysql --host=my3p --user=joe --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe --tty --interactive my4c mysql --host=my4p --user=joe --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe --tty --interactive my5c mysql --host=my5p --user=joe --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;


podman inspect my1c |grep -i ipaddr
ip1=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip1
podman inspect my2c |grep -i ipaddr
ip2=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip2
podman inspect my3c |grep -i ipaddr
ip3=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip3
podman inspect my4c |grep -i ipaddr
ip4=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip4
podman inspect my5c |grep -i ipaddr
ip5=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip5


# mysqladmin --port=3306 --host=$ip1 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip2 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip3 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip4 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip5 --user=joe --password=joe password ''

# ip test

MYSQL_PWD=joe mysql --port=3306 --host=$ip1 --user=joe --execute 'SHOW DATABASES' </dev/null
MYSQL_PWD=joe mysql --port=3306 --host=$ip2 --user=joe --execute 'SHOW DATABASES' </dev/null
MYSQL_PWD=joe mysql --port=3306 --host=$ip3 --user=joe --execute 'SHOW DATABASES' </dev/null
MYSQL_PWD=joe mysql --port=3306 --host=$ip4 --user=joe --execute 'SHOW DATABASES' </dev/null
MYSQL_PWD=joe mysql --port=3306 --host=$ip5 --user=joe --execute 'SHOW DATABASES' </dev/null

# FIXME: NoneNoneNoneNoneNone

# dns test


time podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' </dev/null

time podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' </dev/null

time podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' </dev/null

time podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' </dev/null

time podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES' </dev/null
time podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' </dev/null

podman ps
podman ps --pod
podman ps -a --pod
podman network ls
podman volume ls
podman pod ls

replica_ip=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
# 'repl'@'$replica_ip' on my1c:
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'$replica_ip' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my2p.dns.podname' on my1c:
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'my2p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my2p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my2p' on my1c:
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'my2p' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my2p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'%' on my1c:
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'FLUSH PRIVILEGES' </dev/null

replica_ip=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
# 'repl'@'$replica_ip' on my2c:
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'$replica_ip' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my3p.dns.podname' on my2c:
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'my3p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my3p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my3p' on my2c:
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'my3p' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my3p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'%' on my2c:
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'FLUSH PRIVILEGES' </dev/null

replica_ip=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
# 'repl'@'$replica_ip' on my3c:
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'$replica_ip' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my4p.dns.podname' on my3c:
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'my4p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my4p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my4p' on my3c:
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'my4p' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my4p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'%' on my3c:
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'FLUSH PRIVILEGES' </dev/null

replica_ip=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
# 'repl'@'$replica_ip' on my4c:
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'$replica_ip' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my5p.dns.podname' on my4c:
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'my5p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my5p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my5p' on my4c:
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'my5p' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my5p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'%' on my4c:
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'FLUSH PRIVILEGES' </dev/null

replica_ip=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
# 'repl'@'$replica_ip' on my5c:
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'$replica_ip' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my1p.dns.podname' on my5c:
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'my1p.dns.podname' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my1p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'my1p' on my5c:
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'my1p' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'my1p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES' </dev/null
# 'repl'@'%' on my5c:
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'FLUSH PRIVILEGES' </dev/null

podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'FLUSH TABLES WITH READ LOCK' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'FLUSH TABLES WITH READ LOCK' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'FLUSH TABLES WITH READ LOCK' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'FLUSH TABLES WITH READ LOCK' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'FLUSH TABLES WITH READ LOCK' </dev/null


podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'UNLOCK TABLES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'UNLOCK TABLES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'UNLOCK TABLES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'UNLOCK TABLES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'UNLOCK TABLES' </dev/null


podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null

: <<'END_COMMENT'
# workaround for mysql 5.6: GRANT USAGE ON *.* TO...
replica_ip=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT USAGE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "DROP USER 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT USAGE ON *.* TO 'repl'@'my2p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "DROP USER 'repl'@'my2p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT USAGE ON *.* TO 'repl'@'my2p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "DROP USER 'repl'@'my2p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "GRANT USAGE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute "DROP USER 'repl'@'%'" </dev/null

replica_ip=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT USAGE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "DROP USER 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT USAGE ON *.* TO 'repl'@'my3p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "DROP USER 'repl'@'my3p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT USAGE ON *.* TO 'repl'@'my3p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "DROP USER 'repl'@'my3p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "GRANT USAGE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute "DROP USER 'repl'@'%'" </dev/null

replica_ip=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT USAGE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "DROP USER 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT USAGE ON *.* TO 'repl'@'my4p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "DROP USER 'repl'@'my4p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT USAGE ON *.* TO 'repl'@'my4p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "DROP USER 'repl'@'my4p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "GRANT USAGE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute "DROP USER 'repl'@'%'" </dev/null

replica_ip=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT USAGE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "DROP USER 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT USAGE ON *.* TO 'repl'@'my5p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "DROP USER 'repl'@'my5p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT USAGE ON *.* TO 'repl'@'my5p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "DROP USER 'repl'@'my5p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "GRANT USAGE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute "DROP USER 'repl'@'%'" </dev/null

replica_ip=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT USAGE ON *.* TO 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "DROP USER 'repl'@'$replica_ip'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT USAGE ON *.* TO 'repl'@'my1p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "DROP USER 'repl'@'my1p.dns.podname'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT USAGE ON *.* TO 'repl'@'my1p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "DROP USER 'repl'@'my1p'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "GRANT USAGE ON *.* TO 'repl'@'%'" </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute "DROP USER 'repl'@'%'" </dev/null

END_COMMENT

cat <<'__eot__' >reptest/extra2/extra2.sql
CREATE DATABASE IF NOT EXISTS sales;
USE sales;
CREATE TABLE IF NOT EXISTS user
   (
   user_id int,
   fn varchar(30),
   ln varchar(30),
   age int
   );
INSERT INTO user (fn, ln, age) VALUES ('tom', 'mccormick', 40);
__eot__


# podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql' </dev/null


mkdir -p reptest/my1c/extra
replica_ip=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
cat <<'__eot__' >reptest/my1c/extra/extra.sql
-- placeholder
__eot__
# cat reptest/my1c/extra/extra.sql
mkdir -p reptest/my2c/extra
replica_ip=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
cat <<'__eot__' >reptest/my2c/extra/extra.sql
-- placeholder
__eot__
# cat reptest/my2c/extra/extra.sql
mkdir -p reptest/my3c/extra
replica_ip=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
cat <<'__eot__' >reptest/my3c/extra/extra.sql
-- placeholder
__eot__
# cat reptest/my3c/extra/extra.sql
mkdir -p reptest/my4c/extra
replica_ip=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
cat <<'__eot__' >reptest/my4c/extra/extra.sql
-- placeholder
__eot__
# cat reptest/my4c/extra/extra.sql
mkdir -p reptest/my5c/extra
replica_ip=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
cat <<'__eot__' >reptest/my5c/extra/extra.sql
-- placeholder
__eot__
# cat reptest/my5c/extra/extra.sql


podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null


# podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
# podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null


podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my1c source:my5c position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --host=my1p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my2c source:my1c position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --host=my2p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my3c source:my2c position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --host=my3p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my4c source:my3c position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --host=my4p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my5c source:my4c position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --host=my5p --user=root --execute "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS=$position"

: <<'END_COMMENT'
# FIXME: it would be really nice to be able to use dns here
source_ip=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
target_ip=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --host=my1p --user=root --execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS="$position'"'
source_ip=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
target_ip=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --host=my2p --user=root --execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS="$position'"'
source_ip=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
target_ip=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --host=my3p --user=root --execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS="$position'"'
source_ip=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
target_ip=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --host=my4p --user=root --execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS="$position'"'
source_ip=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
target_ip=$(podman inspect my5c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --host=my5p --user=root --execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',MASTER_USER='repl',MASTER_PASSWORD='repl',MASTER_LOG_FILE='mysql-bin.000003',MASTER_LOG_POS="$position'"'
END_COMMENT


podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE' </dev/null

: <<'END_COMMENT'
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE' </dev/null
END_COMMENT

# testing replication
: <<'END_COMMENT'
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'SHOW DATABASES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'SHOW DATABASES' </dev/null

podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'SHOW DATABASES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'SHOW DATABASES' </dev/null

podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'SHOW DATABASES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'SHOW DATABASES' </dev/null

podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'SHOW DATABASES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'SHOW DATABASES' </dev/null

podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'SHOW DATABASES' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'SHOW DATABASES' </dev/null

END_COMMENT

cat <<'__eot__' >test_replication_is_running.bats
@test 'ensure replication is running' {
  sleep 5
  podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE' </dev/null

  sleep 5
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'USE dummy' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'USE dummy' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
  run podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'USE dummy' </dev/null
  sleep 5
  [ "$status" -eq 1 ]
}
__eot__
sudo bats test_replication_is_running.bats

cat <<'__eot__' >test_replication_is_stopped.bats
@test 'stop replication and ensure its not running' {

  sleep 5
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE' </dev/null

  sleep 5
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'USE dummy' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null

  sleep 5
  run podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'USE dummy' </dev/null
  [ "$status" -eq 1 ]

  sleep 5
  run podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'USE dummy' </dev/null
  [ "$status" -eq 0 ]

  # make sure replication is running again for next test...managing state like this will get dirty, i promise
  podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE' </dev/null
  sleep 5
}
__eot__
sudo bats test_replication_is_stopped.bats

# i guess positions have increased, yes?
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my5c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my1c source:my5c position:$position
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my2c source:my1c position:$position
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my2c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my3c source:my2c position:$position
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my3c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my4c source:my3c position:$position
position=$(podman exec --env=MYSQL_PWD=root --tty --interactive my4c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:my5c source:my4c position:$position
