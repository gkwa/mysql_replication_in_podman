#!/bin/bash
set -o errexit

cleanall() {
    for i in {1..2}; do
        podman pod stop --ignore --all
        podman container stop --ignore --all
        podman pod rm --all --force
        podman container rm --all --force
        podman images prune
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
! grep --quiet --regexp 'registry.redhat.io/rhel8/mysql-80.*latest' <<<"$(podman images)" && time podman pull --quiet registry.redhat.io/rhel8/mysql-80 >/dev/null
! grep --quiet --regexp 'docker.io/perconalab/percona-toolkit.*latest' <<<"$(podman images)" && time podman pull --quiet docker.io/perconalab/percona-toolkit:latest >/dev/null

echo stopping containers
set +o errexit
podman container stop --ignore my1c my2c my3c my4c my5c 2>&1 | grep -v 'Error: no container with name or ID ' >podman_stop_containers_$(date +%s).log
set -o errexit
podman container exists my1c && podman container stop --ignore my1c 2>&1 | grep -v 'Error: no container with name or ID '
podman container exists my2c && podman container stop --ignore my2c 2>&1 | grep -v 'Error: no container with name or ID '
podman container exists my3c && podman container stop --ignore my3c 2>&1 | grep -v 'Error: no container with name or ID '
podman container exists my4c && podman container stop --ignore my4c 2>&1 | grep -v 'Error: no container with name or ID '
podman container exists my5c && podman container stop --ignore my5c 2>&1 | grep -v 'Error: no container with name or ID '
podman container wait --condition=stopped my1c my2c my3c my4c my5c || true

echo stopping pods
podman pod exists my1p && podman pod stop my1p --ignore my1p >/dev/null
podman pod exists my2p && podman pod stop my2p --ignore my2p >/dev/null
podman pod exists my3p && podman pod stop my3p --ignore my3p >/dev/null
podman pod exists my4p && podman pod stop my4p --ignore my4p >/dev/null
podman pod exists my5p && podman pod stop my5p --ignore my5p >/dev/null

podman container exists my1c && podman container rm --force --ignore my1c >/dev/null
podman container exists my2c && podman container rm --force --ignore my2c >/dev/null
podman container exists my3c && podman container rm --force --ignore my3c >/dev/null
podman container exists my4c && podman container rm --force --ignore my4c >/dev/null
podman container exists my5c && podman container rm --force --ignore my5c >/dev/null
set +o errexit
podman pod exists my1p && podman pod rm --force my1p --ignore my1p 2>podman_rm_pods.log >/dev/null
podman pod exists my2p && podman pod rm --force my2p --ignore my2p 2>podman_rm_pods.log >/dev/null
podman pod exists my3p && podman pod rm --force my3p --ignore my3p 2>podman_rm_pods.log >/dev/null
podman pod exists my4p && podman pod rm --force my4p --ignore my4p 2>podman_rm_pods.log >/dev/null
podman pod exists my5p && podman pod rm --force my5p --ignore my5p 2>podman_rm_pods.log >/dev/null
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

if ! podman network exists replication; then
    echo creating network replication
    podman network create replication >/dev/null
fi

mkdir -p reptest

echo mysql: configure mysql service
cat <<'__eot__' >reptest/my1c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
server_id                      = 1
auto_increment_offset          = 1
binlog_format                  = STATEMENT
;slave-skip-errors              = 1050,1062,1032
__eot__
cat <<'__eot__' >reptest/my2c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
server_id                      = 2
auto_increment_offset          = 2
binlog_format                  = STATEMENT
;slave-skip-errors              = 1050,1062,1032
__eot__
cat <<'__eot__' >reptest/my3c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
server_id                      = 3
auto_increment_offset          = 3
binlog_format                  = STATEMENT
;slave-skip-errors              = 1050,1062,1032
__eot__
cat <<'__eot__' >reptest/my4c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
server_id                      = 4
auto_increment_offset          = 4
binlog_format                  = STATEMENT
;slave-skip-errors              = 1050,1062,1032
__eot__
cat <<'__eot__' >reptest/my5c_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1 
sync_binlog                    = 1
server_id                      = 5
auto_increment_offset          = 5
binlog_format                  = STATEMENT
;slave-skip-errors              = 1050,1062,1032
__eot__

echo mysql: check mysql config
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
mkdir -p /root/live_dbeval_comparing_records
if ! podman container exists my1c; then
    podman container create \
        --name=my1c \
        --pod=my1p \
        --log-driver=journald \
        --healthcheck-interval=0 \
        --health-retries=10 \
        --health-timeout=30s \
        --health-start-period=80s \
        --healthcheck-command 'CMD-SHELL mysql --user=root --password="rootpass" --host=my1p --execute "USE mysql" || exit 1' \
        --volume=/root/live_dbeval_comparing_records:/data \
        --volume=./reptest/my1c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
        --volume=my1dbdata:/var/lib/mysql/data:Z \
        --env=MYSQL_ROOT_PASSWORD=rootpass \
        --env=MYSQL_USER=joe \
        --env=MYSQL_PASSWORD=joepass \
        --env=MYSQL_DATABASE=db \
        registry.redhat.io/rhel8/mysql-80 >/dev/null
fi
if ! podman container exists my2c; then
    podman container create \
        --name=my2c \
        --pod=my2p \
        --log-driver=journald \
        --healthcheck-interval=0 \
        --health-retries=10 \
        --health-timeout=30s \
        --health-start-period=80s \
        --healthcheck-command 'CMD-SHELL mysql --user=root --password="rootpass" --host=my2p --execute "USE mysql" || exit 1' \
        --volume=/root/live_dbeval_comparing_records:/data \
        --volume=./reptest/my2c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
        --volume=my2dbdata:/var/lib/mysql/data:Z \
        --env=MYSQL_ROOT_PASSWORD=rootpass \
        --env=MYSQL_USER=joe \
        --env=MYSQL_PASSWORD=joepass \
        --env=MYSQL_DATABASE=db \
        registry.redhat.io/rhel8/mysql-80 >/dev/null
fi
if ! podman container exists my3c; then
    podman container create \
        --name=my3c \
        --pod=my3p \
        --log-driver=journald \
        --healthcheck-interval=0 \
        --health-retries=10 \
        --health-timeout=30s \
        --health-start-period=80s \
        --healthcheck-command 'CMD-SHELL mysql --user=root --password="rootpass" --host=my3p --execute "USE mysql" || exit 1' \
        --volume=/root/live_dbeval_comparing_records:/data \
        --volume=./reptest/my3c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
        --volume=my3dbdata:/var/lib/mysql/data:Z \
        --env=MYSQL_ROOT_PASSWORD=rootpass \
        --env=MYSQL_USER=joe \
        --env=MYSQL_PASSWORD=joepass \
        --env=MYSQL_DATABASE=db \
        registry.redhat.io/rhel8/mysql-80 >/dev/null
fi
if ! podman container exists my4c; then
    podman container create \
        --name=my4c \
        --pod=my4p \
        --log-driver=journald \
        --healthcheck-interval=0 \
        --health-retries=10 \
        --health-timeout=30s \
        --health-start-period=80s \
        --healthcheck-command 'CMD-SHELL mysql --user=root --password="rootpass" --host=my4p --execute "USE mysql" || exit 1' \
        --volume=/root/live_dbeval_comparing_records:/data \
        --volume=./reptest/my4c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
        --volume=my4dbdata:/var/lib/mysql/data:Z \
        --env=MYSQL_ROOT_PASSWORD=rootpass \
        --env=MYSQL_USER=joe \
        --env=MYSQL_PASSWORD=joepass \
        --env=MYSQL_DATABASE=db \
        registry.redhat.io/rhel8/mysql-80 >/dev/null
fi
if ! podman container exists my5c; then
    podman container create \
        --name=my5c \
        --pod=my5p \
        --log-driver=journald \
        --healthcheck-interval=0 \
        --health-retries=10 \
        --health-timeout=30s \
        --health-start-period=80s \
        --healthcheck-command 'CMD-SHELL mysql --user=root --password="rootpass" --host=my5p --execute "USE mysql" || exit 1' \
        --volume=/root/live_dbeval_comparing_records:/data \
        --volume=./reptest/my5c_my.cnf:/etc/my.cnf.d/100-reptest.cnf \
        --volume=my5dbdata:/var/lib/mysql/data:Z \
        --env=MYSQL_ROOT_PASSWORD=rootpass \
        --env=MYSQL_USER=joe \
        --env=MYSQL_PASSWORD=joepass \
        --env=MYSQL_DATABASE=db \
        registry.redhat.io/rhel8/mysql-80 >/dev/null
fi
set +o errexit
podman pod start my1p my2p my3p my4p my5p 2>podman_start_pods_$(date +%s).log >/dev/null
set -o errexit
podman pod start my1p my2p my3p my4p my5p >/dev/null

echo 'wait for container healthcheck(s)'
sleep=4
tries=20
loop2 healthcheck my1c $sleep $tries
loop2 healthcheck my2c $sleep $tries
loop2 healthcheck my3c $sleep $tries
loop2 healthcheck my4c $sleep $tries
loop2 healthcheck my5c $sleep $tries

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

echo mysql: add and grant user repl
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'CREATE USER IF NOT EXISTS `repl`@"%" IDENTIFIED WITH mysql_native_password BY "replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'CREATE USER IF NOT EXISTS `repl`@"%" IDENTIFIED WITH mysql_native_password BY "replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'CREATE USER IF NOT EXISTS `repl`@"%" IDENTIFIED WITH mysql_native_password BY "replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'CREATE USER IF NOT EXISTS `repl`@"%" IDENTIFIED WITH mysql_native_password BY "replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'CREATE USER IF NOT EXISTS `repl`@"%" IDENTIFIED WITH mysql_native_password BY "replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'GRANT REPLICATION SLAVE ON *.* TO `repl`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'GRANT REPLICATION SLAVE ON *.* TO `repl`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'GRANT REPLICATION SLAVE ON *.* TO `repl`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'GRANT REPLICATION SLAVE ON *.* TO `repl`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'GRANT REPLICATION SLAVE ON *.* TO `repl`@"%"'

echo mysql: add and grant user percona
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'CREATE USER IF NOT EXISTS `percona`@"%" IDENTIFIED WITH mysql_native_password BY "perconapass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'CREATE USER IF NOT EXISTS `percona`@"%" IDENTIFIED WITH mysql_native_password BY "perconapass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'CREATE USER IF NOT EXISTS `percona`@"%" IDENTIFIED WITH mysql_native_password BY "perconapass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'CREATE USER IF NOT EXISTS `percona`@"%" IDENTIFIED WITH mysql_native_password BY "perconapass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'CREATE USER IF NOT EXISTS `percona`@"%" IDENTIFIED WITH mysql_native_password BY "perconapass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'GRANT REPLICATION SLAVE,PROCESS,SUPER,SELECT ON *.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'GRANT ALL PRIVILEGES ON percona.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'GRANT REPLICATION SLAVE,PROCESS,SUPER,SELECT ON *.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'GRANT ALL PRIVILEGES ON percona.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'GRANT REPLICATION SLAVE,PROCESS,SUPER,SELECT ON *.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'GRANT ALL PRIVILEGES ON percona.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'GRANT REPLICATION SLAVE,PROCESS,SUPER,SELECT ON *.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'GRANT ALL PRIVILEGES ON percona.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'GRANT REPLICATION SLAVE,PROCESS,SUPER,SELECT ON *.* TO `percona`@"%"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'GRANT ALL PRIVILEGES ON percona.* TO `percona`@"%"'

echo mysql: flush privileges
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'FLUSH PRIVILEGES'

echo mysql: stop slave
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE IO_THREAD FOR CHANNEL ""'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE IO_THREAD FOR CHANNEL ""'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE IO_THREAD FOR CHANNEL ""'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE IO_THREAD FOR CHANNEL ""'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE IO_THREAD FOR CHANNEL ""'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

echo mysql: fetch positions
master_log_file=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $master_log_file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p --execute \
    "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='replpass',MASTER_LOG_FILE='"$master_log_file"',MASTER_LOG_POS=$position"
master_log_file=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $master_log_file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p --execute \
    "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='replpass',MASTER_LOG_FILE='"$master_log_file"',MASTER_LOG_POS=$position"
master_log_file=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $master_log_file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p --execute \
    "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='replpass',MASTER_LOG_FILE='"$master_log_file"',MASTER_LOG_POS=$position"
master_log_file=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $master_log_file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p --execute \
    "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='replpass',MASTER_LOG_FILE='"$master_log_file"',MASTER_LOG_POS=$position"
master_log_file=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $master_log_file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW MASTER STATUS\G' |
        sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p --execute \
    "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='replpass',MASTER_LOG_FILE='"$master_log_file"',MASTER_LOG_POS=$position"

echo mysql: start replication
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'
podman exec --env=MYSQL_PWD=rootpass my1c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="replpass"'

echo mysql: wait for replication to be ready
sleep=2
tries=60
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries
