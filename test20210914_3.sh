#!/bin/bash

set -o errexit

podman info --debug

podman container stop --ignore my1c my2c my3c my4c my5c
podman pod stop --log-level debug --ignore my1p my2p my3p my4p my5p
podman wait --condition=stopped my1c my2c my3c my4c my5c
podman pod ls 

for i in {1..5}; do rm -rf --preserve-root $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint')/*; done
for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done

set +o errexit
podman pod start my1p my2p my3p my4p my5p
podman pod start my1p my2p my3p my4p my5p
set -o errexit

for i in {1..5}; do du -shc $(podman volume inspect my${i}dbdata | jq -r '.[]|.Mountpoint'); done

podman pod ls 
podman logs --since=30s my1c 

until podman healthcheck run my1c </dev/null; do sleep 5; done
until podman healthcheck run my2c </dev/null; do sleep 5; done
until podman healthcheck run my3c </dev/null; do sleep 5; done
until podman healthcheck run my4c </dev/null; do sleep 5; done
until podman healthcheck run my5c </dev/null; do sleep 5; done

for i in {1..5}; do 
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my${i}p --execute "CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'repl'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my${i}p --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my${i}p --execute 'FLUSH PRIVILEGES'
done

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

for i in {1..5}; do 
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my${i}p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
done

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'

for i in {1..5}; do 
podman exec --env=MYSQL_PWD=root my1c mysql --host=my${i}p --user=root --execute 'USE ptest' && echo my${i}p ok
done
