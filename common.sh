function repcheck() {
    jump_container=$1
    target_host=$2

    grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root $jump_container mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')"
    r1=$?

    grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root $jump_container mysql --user=root --host=$target_host --execute 'SHOW SLAVE STATUS\G')"
    r2=$?

    [ $r1 -eq 0 ] && [ $r2 -eq 0 ]
}

function loop1() {
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
            return false
        fi
    done
}
