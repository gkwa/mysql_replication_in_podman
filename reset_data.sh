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
            if podman network exists $network; then
                podman network rm $network
            fi
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
            if podman network exists $network; then
                podman network rm $network
            fi
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

    result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')

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

set +o errexit
podman container stop --ignore my1c my2c my3c my4c my5c 2>podman_stop_containers_$(date +%s).log >/dev/null
set -o errexit
if podman container exists my1c; then
    podman container stop --ignore my1c >/dev/null
fi
if podman container exists my2c; then
    podman container stop --ignore my2c >/dev/null
fi
if podman container exists my3c; then
    podman container stop --ignore my3c >/dev/null
fi
if podman container exists my4c; then
    podman container stop --ignore my4c >/dev/null
fi
if podman container exists my5c; then
    podman container stop --ignore my5c >/dev/null
fi

if podman pod exists my1p; then
    podman pod stop my1p --ignore my1p >/dev/null
fi
if podman pod exists my2p; then
    podman pod stop my2p --ignore my2p >/dev/null
fi
if podman pod exists my3p; then
    podman pod stop my3p --ignore my3p >/dev/null
fi
if podman pod exists my4p; then
    podman pod stop my4p --ignore my4p >/dev/null
fi
if podman pod exists my5p; then
    podman pod stop my5p --ignore my5p >/dev/null
fi

podman pod ls

echo remove data from volume, but leaving volume in place
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

podman pod ls

echo mysql: add user repl
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

echo mysql: grant repl user replication permission
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%'"

echo mysql: flush privileges
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'FLUSH PRIVILEGES'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'FLUSH PRIVILEGES'

echo mysql: setup replication

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute "STOP SLAVE IO_THREAD FOR CHANNEL ''"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute "STOP SLAVE IO_THREAD FOR CHANNEL ''"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute "STOP SLAVE IO_THREAD FOR CHANNEL ''"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute "STOP SLAVE IO_THREAD FOR CHANNEL ''"
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute "STOP SLAVE IO_THREAD FOR CHANNEL ''"

podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'
file=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --user=root --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my5p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='"$file"',MASTER_LOG_POS=$position"
file=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --user=root --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my1p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='"$file"',MASTER_LOG_POS=$position"
file=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --user=root --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my2p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='"$file"',MASTER_LOG_POS=$position"
file=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --user=root --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my3p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='"$file"',MASTER_LOG_POS=$position"
file=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *File:/!d' -e 's/File://g' -e 's/ //g'
)
[[ -n $file ]] # assert not empty
position=$(
    podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'SHOW MASTER STATUS\G' | sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g'
)
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --user=root --execute 'SHOW MASTER STATUS\G'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --user=root --execute \
    "CHANGE MASTER TO MASTER_HOST='my4p.dns.podman',MASTER_USER='repl',\
MASTER_PASSWORD='repl',MASTER_LOG_FILE='"$file"',MASTER_LOG_POS=$position"

echo mysql: start replication
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'

echo mysql: wait for replication to be ready
sleep=2
tries=60
loop1 repcheck my1c my1p.dns.podman $sleep $tries
loop1 repcheck my1c my2p.dns.podman $sleep $tries
loop1 repcheck my1c my3p.dns.podman $sleep $tries
loop1 repcheck my1c my4p.dns.podman $sleep $tries
loop1 repcheck my1c my5p.dns.podman $sleep $tries
