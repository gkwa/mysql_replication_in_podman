#!/bin/bash

set -o errexit

podman --version

# podman login --username mtmonacelli registry.redhat.io $REGISTRY_REDHAT_IO_PASSWORD

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
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


podman network exists replication && podman network rm --force replication

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls


podman network create replication

podman volume create my1dbdata
podman volume create my2dbdata
podman volume create my3dbdata
podman volume create my4dbdata

rm -rf ./reptest/


mkdir -p reptest/my1c
cat <<'__eot__' >reptest/my1c/my.cnf
[mysqld]
bind-address             = my1p.dns.podman
server_id                = 1
#log_bin                 = /var/log/mysql/mysql-bin.log
binlog_do_db             = db
__eot__

mkdir -p reptest/my2c
cat <<'__eot__' >reptest/my2c/my.cnf
[mysqld]
bind-address             = my2p.dns.podman
server_id                = 2
#log_bin                 = /var/log/mysql/mysql-bin.log
binlog_do_db             = db
__eot__

mkdir -p reptest/my3c
cat <<'__eot__' >reptest/my3c/my.cnf
[mysqld]
bind-address             = my3p.dns.podman
server_id                = 3
#log_bin                 = /var/log/mysql/mysql-bin.log
binlog_do_db             = db
__eot__

mkdir -p reptest/my4c
cat <<'__eot__' >reptest/my4c/my.cnf
[mysqld]
bind-address             = my4p.dns.podman
server_id                = 4
#log_bin                 = /var/log/mysql/mysql-bin.log
binlog_do_db             = db
__eot__



# bridge mode networking
podman pod create --name=my1p --publish=33061:3306 --network=replication
podman container create --name=my1c --rm --health-start-period=80s --log-driver=journald --pod=my1p --volume=./reptest/my1c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=my1dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman pod ls

# bridge mode networking
podman pod create --name=my2p --publish=33062:3306 --network=replication
podman container create --name=my2c --rm --health-start-period=80s --log-driver=journald --pod=my2p --volume=./reptest/my2c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=my2dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman pod ls

# bridge mode networking
podman pod create --name=my3p --publish=33063:3306 --network=replication
podman container create --name=my3c --rm --health-start-period=80s --log-driver=journald --pod=my3p --volume=./reptest/my3c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=my3dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman pod ls

# bridge mode networking
podman pod create --name=my4p --publish=33064:3306 --network=replication
podman container create --name=my4c --rm --health-start-period=80s --log-driver=journald --pod=my4p --volume=./reptest/my4c/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=my4dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman pod ls



podman pod start my1p
podman pod start my2p
podman pod start my3p
podman pod start my4p


podman wait my1c --condition=running
podman wait my2c --condition=running
podman wait my3c --condition=running
podman wait my4c --condition=running


podman volume inspect my1dbdata
podman volume inspect my2dbdata
podman volume inspect my3dbdata
podman volume inspect my4dbdata

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls



until podman exec --tty --interactive my1c mysql --host=my1p --user=joe --password=joe --execute "SHOW DATABASES;"; do sleep 5; done;
until podman exec --tty --interactive my2c mysql --host=my2p --user=joe --password=joe --execute "SHOW DATABASES;"; do sleep 5; done;
until podman exec --tty --interactive my3c mysql --host=my3p --user=joe --password=joe --execute "SHOW DATABASES;"; do sleep 5; done;
until podman exec --tty --interactive my4c mysql --host=my4p --user=joe --password=joe --execute "SHOW DATABASES;"; do sleep 5; done;


podman inspect my1c | grep -i ipaddr
ip1=$(podman inspect my1c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip1
podman inspect my2c | grep -i ipaddr
ip2=$(podman inspect my2c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip2
podman inspect my3c | grep -i ipaddr
ip3=$(podman inspect my3c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip3
podman inspect my4c | grep -i ipaddr
ip4=$(podman inspect my4c --format '{{.NetworkSettings.Networks.replication.IPAddress}}')
echo $ip4


# mysqladmin --port=3306 --host=$ip1 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip2 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip3 --user=joe --password=joe password ''
# mysqladmin --port=3306 --host=$ip4 --user=joe --password=joe password ''

# ip test

mysql --port=3306 --host=$ip1 --user=joe --password=joe --execute "SHOW DATABASES;"
mysql --port=3306 --host=$ip2 --user=joe --password=joe --execute "SHOW DATABASES;"
mysql --port=3306 --host=$ip3 --user=joe --password=joe --execute "SHOW DATABASES;"
mysql --port=3306 --host=$ip4 --user=joe --password=joe --execute "SHOW DATABASES;"

# FIXME: NoneNoneNoneNone

# dns test


time podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my1c mysql --user=root --password=root --host=my2p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my1c mysql --user=root --password=root --host=my3p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my1c mysql --user=root --password=root --host=my4p.dns.podman --execute 'SHOW DATABASES;' </dev/null

time podman exec --tty --interactive my2c mysql --user=root --password=root --host=my1p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my2c mysql --user=root --password=root --host=my2p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my2c mysql --user=root --password=root --host=my3p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my2c mysql --user=root --password=root --host=my4p.dns.podman --execute 'SHOW DATABASES;' </dev/null

time podman exec --tty --interactive my3c mysql --user=root --password=root --host=my1p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my3c mysql --user=root --password=root --host=my2p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my3c mysql --user=root --password=root --host=my3p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my3c mysql --user=root --password=root --host=my4p.dns.podman --execute 'SHOW DATABASES;' </dev/null

time podman exec --tty --interactive my4c mysql --user=root --password=root --host=my1p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my4c mysql --user=root --password=root --host=my2p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my4c mysql --user=root --password=root --host=my3p.dns.podman --execute 'SHOW DATABASES;' </dev/null
time podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p.dns.podman --execute 'SHOW DATABASES;' </dev/null

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls

