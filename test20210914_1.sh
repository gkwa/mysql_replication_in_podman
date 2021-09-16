#!/bin/bash

set -o errexit

source ./common.sh

# podman pod rm --force --ignore my1p my2p my3p my4p my5p
# podman pod start my1p my2p my3p my4p my5p

# podman container rm --force --ignore my1c my2c my3c my4c my5c
# podman pod stop --ignore my1p my2p my3p my4p my5p
# podman container stop --ignore my1c my2c my3c my4c my5c
# podman wait my1c my2c my3c my4c my5c --condition=stopped
# podman container start my1c

podman ps --pod
podman container stop --ignore my1c my2c my3c my4c my5c
podman wait --condition=stopped my1c my2c my3c my4c my5c
podman container start my1c my2c my3c my4c my5c
podman wait --condition=running my1c my2c my3c my4c my5c

podman pod ls 
podman pod start --all
until podman healthcheck run my1c </dev/null; do sleep 5; done
until podman healthcheck run my2c </dev/null; do sleep 5; done
until podman healthcheck run my3c </dev/null; do sleep 5; done
until podman healthcheck run my4c </dev/null; do sleep 5; done
until podman healthcheck run my5c </dev/null; do sleep 5; done
podman logs 

podman container start my1c my2c my3c my4c my5c
until podman exec --env=MYSQL_PWD=joe my1c mysql --host=my1p --user=joe --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe my2c mysql --host=my2p --user=joe --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe my3c mysql --host=my3p --user=joe --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe my4c mysql --host=my4p --user=joe --execute 'SHOW DATABASES'; do sleep 5; done;
until podman exec --env=MYSQL_PWD=joe my5c mysql --host=my5p --user=joe --execute 'SHOW DATABASES'; do sleep 5; done;

for i in {1..5}; do rm -rf $(podman volume inspect my${i}.dns.podman | jq -r '.[]|.Mountpoint')/*; done
for i in {1..5}; do du -shc $(podman volume inspect my${i}.dns.podman | jq -r '.[]|.Mountpoint'); done
podman container start my1c my2c my3c my4c my5c
for i in {1..5}; do du -shc $(podman volume inspect my${i}.dns.podman | jq -r '.[]|.Mountpoint'); done
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

