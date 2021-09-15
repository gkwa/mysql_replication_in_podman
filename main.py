import pathlib

import jinja2
import yaml

manifest_path = pathlib.Path(__file__).parent.resolve() / "manifest.yml"

in_file = manifest_path

with open(in_file, "r") as stream:
    try:
        manifest = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

tmpl_str = """#!/bin/bash
{%- set global=manifest['global'] %}
{%- set replication=manifest['replication'] %}
{%- set pods=manifest['pods'] %}

{% macro status() -%}
podman ps
podman ps --pod
podman ps -a --pod
podman network ls
podman volume ls
podman pod ls
{% endmacro -%}

set -o errexit

podman info --debug
mysql --version

# destroy everything except for podman network for sanity check
: <<'END_COMMENT'
podman pod stop --ignore --all; podman container stop --ignore --all; podman system prune --all --force; podman pod rm --all --force; podman container rm --all --force; podman volume rm --all --force; for network in $(podman network ls --format json | jq -r '.[].Name'); do if [[ "$network" !=  "podman" ]]; then podman network exists $network && podman network rm $network; fi; done; podman ps; podman ps --pod; podman ps -a --pod; podman network ls; podman volume ls; podman pod ls  #destroyall
END_COMMENT

# FIXME: reminder: i'm using appveyor secrets to decrypt this from ./auth.json.enc, thats obscure
# podman login --authfile $HOME/.config/containers/auth.json registry.redhat.io

podman pull docker.io/perconalab/percona-toolkit:latest

{{ status() }}

{% for pod in pods %}
podman container stop --ignore {{ pod.containers[0].name }}
{% endfor %}

{% for pod in pods %}
podman pod stop --ignore {{ pod.name }}
podman pod rm --ignore --force {{ pod.name }}
{% endfor %}

{% for pod in pods %}
podman volume exists {{ pod.volume }} && podman volume rm --force {{ pod.volume }}
{%- endfor %}

podman network exists {{ global.network}} && podman network rm --force {{ global.network }}

{{ status() }}

podman network create {{ global.network }}
{% for pod in pods %}
podman volume create {{ pod.volume }}
{%- endfor %}

# start clean
[[ -d 'reptest' ]] && mv reptest reptest.$(date +%s)

mkdir -p reptest/extra2
{%- for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}/extra
{%- endfor %}

{% for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}/my.cnf
[mysqld]
bind-address                   = {{ pod.name }}.dns.podman
server_id                      = {{ loop.index }}
auto_increment_offset          = {{ loop.index }}
auto_increment_increment       = {{ pods|length }}
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
#binlog_format                  = ROW
#binlog_format                  = MIXED
binlog_format                  = STATEMENT
log_slave_updates              = ON

; ignore duplicate key errors
; slave-skip-errors              = 1062
; slave-skip-errors                = 1050,1062,1032
sql_mode                       =
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
__eot__
cat reptest/{{ pod.containers[0].name }}/my.cnf
{% endfor %}

# pods with bridge mode networking
{%- for pod in pods %}
podman pod create --name={{ pod.name }} --publish={{ global.internal_port }}{{loop.index}}:{{ global.internal_port }} --network={{ global.network }}
{%- endfor %}

# mysqld containers
{%- for pod in pods %}
podman container create --name={{ pod.containers[0].name }} --pod={{ pod.name }} --health-start-period=80s --log-driver=journald --health-interval=30s --health-retries=10 --health-timeout=30s --health-cmd='CMD-SHELL mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "USE mysql"' --volume=./reptest/{{ pod.containers[0].name }}/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/{{ pod.containers[0].name }}/extra:/tmp/extra:Z --volume=./reptest/extra2:/tmp/extra2:Z --volume={{ pod.volume }}:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD={{ global.user_root_pass }} --env=MYSQL_USER={{ global.user_non_root }} --env=MYSQL_PASSWORD={{ global.user_non_root_pass }} --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
{%- endfor %}

{% for pod in pods %}
podman pod start {{ pod.name }}
{%- endfor %}

{% for pod in pods %}
podman wait {{ pod.containers[0].name }} --condition=running
{%- endfor %}

{% for pod in pods %}
podman volume inspect {{ pod.volume }}
{%- endfor %}

{{ status() }}

{% for pod in pods %}
until podman exec --env=MYSQL_PWD={{ global.user_non_root_pass }} {{ pod.containers[0].name }} mysql --host={{ pod.name }} --user={{ global.user_non_root }} --execute 'SHOW DATABASES'; do sleep 5; done;
{%- endfor %}

{% for pod in pods %}
until podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --host={{ pod.name }} --user={{ global.user_root }} --execute 'SHOW DATABASES'; do sleep 5; done;
{%- endfor %}

{% for pod in pods %}{% set ip='ip' ~ loop.index %}
{{ip}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network }}.IPAddress{%- raw -%} }} {%- endraw -%}'); echo ${{ip}}
{%- endfor %}

{% for pod in pods %}{% set ip='ip' ~ loop.index %}
# mysqladmin --port={{ global.internal_port }} --host=${{ip}} --user={{ global.user_non_root }} --password={{ global.user_non_root_pass }} password ''
{%- endfor %}

# ip test
{% for pod in pods %}{% set ip='ip' ~ loop.index %}
MYSQL_PWD={{ global.user_non_root_pass }} mysql --port={{ global.internal_port }} --host=${{ip}} --user={{ global.user_non_root }} --execute 'SHOW DATABASES' </dev/null
{%- endfor %}

# FIXME: {% set containers = [] %}{% for pod in pods %}{{ containers.append( pod.containers[0].name ) }}{% endfor %}

# dns test
{% for container in containers %}
{% for pod in pods %}
time podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ container }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SHOW DATABASES'
{%- endfor %}
{%- endfor %}

{{ status() }}

{%- for pod in pods %}
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
{%- set user = "'" ~ global.user_replication ~ "'@'" ~ "$replica_ip" ~ pod.replica.number ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES'

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ pod.replica.fqdn ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES'

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ pod.replica.fqdn.split('.')[0] ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES'

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ '%' ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES'
{% endfor %}

{%- for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH TABLES WITH READ LOCK'
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'UNLOCK TABLES'
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'CREATE DATABASE IF NOT EXISTS dummy'
{%- endfor %}

: <<'END_COMMENT'
# workaround for mysql 5.6: GRANT USAGE ON *.* TO...
{%- for pod in pods %}
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'$replica_ip{{ pod.replica.number }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'$replica_ip{{ pod.replica.number }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn.split('.')[0] }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'{{ pod.replica.fqdn.split('.')[0] }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'%'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'%'"
{% endfor %}
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

{% for pod in pods %}
# podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql'
{%- endfor %}

{% for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}/extra
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network }}.IPAddress{%- raw -%} }} {%- endraw -%}')
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}/extra/extra.sql
-- placeholder
__eot__
# cat reptest/{{ pod.containers[0].name }}/extra/extra.sql
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra/extra.sql'
{%- endfor %}

{% for pod in pods %}
# podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra/extra.sql'
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user'
{%- endfor %}

{%- for block in replication %}
position=$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:{{ block.instance.container }} source:{{ block.source.container }} position:$position
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.instance.container }} mysql --host={{ block.instance.pod }} --user={{ global.user_root }} \
--execute "CHANGE MASTER TO MASTER_HOST='{{ block.source.pod }}.dns.podman',\
MASTER_USER='{{ global.user_replication }}',\
MASTER_PASSWORD='{{ global.user_replication_pass }}',\
MASTER_LOG_FILE='mysql-bin.000003',\
MASTER_LOG_POS=$position"
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} bash -c "mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'SHOW SLAVE STATUS\G' |grep -iE 'Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master'"
{%- endfor %}

: <<'END_COMMENT'
{%- for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'STOP SLAVE'
{%- endfor %}
END_COMMENT

# testing replication
: <<'END_COMMENT'
{%- for block in replication %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.instance.container }} mysql --user={{ global.user_root }} --host={{ block.instance.pod }} --execute 'SHOW DATABASES'
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root }} --host={{ block.source.pod }} --execute 'DROP DATABASE IF EXISTS dummy'
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.instance.container }} mysql --user={{ global.user_root }} --host={{ block.instance.pod }} --execute 'SHOW DATABASES'
{% endfor %}
END_COMMENT

cat <<'__eot__' >test_replication_is_running.bats
@test 'ensure replication is running' {
  sleep 5
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'

  sleep 5
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'USE dummy'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'USE dummy'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy'
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'USE dummy'
  sleep 5
  [ "$status" -eq 1 ]
}
__eot__
sudo bats test_replication_is_running.bats

cat <<'__eot__' >test_replication_is_stopped.bats
@test 'stop replication and ensure its not running' {
  skip
  sleep 5
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

  sleep 5
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'USE dummy'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy'

  sleep 5
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'USE dummy'
  [ "$status" -eq 1 ]

  sleep 5
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'USE dummy'
  [ "$status" -eq 0 ]

  # make sure replication is running again for next test...managing state like this will get dirty, i promise
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER={{ global.user_replication }} PASSWORD="{{ global.user_replication_pass }}"'
}
__eot__
sudo bats test_replication_is_stopped.bats

# i guess positions have increased, yes?
{%- for block in replication %}
position=$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G'|sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:{{ block.instance.container }} source:{{ block.source.container }} position:$position
{%- endfor %}

{% for block in replication %}
until grep --silent 'Slave_IO_Running: Yes' <<< "$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root_pass }} --host={{ block.instance.pod }}.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
until grep --silent 'Slave_SQL_Running: Yes' <<< "$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root_pass }} --host={{ block.instance.pod }}.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
{%- endfor %}

cat <<'__eot__' >replication_ok.bats
@test 'user table replicated ok' {
  skip
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql'

  result1="$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result1" -eq 1 ] 

  result2="$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result2" -eq 1 ] 

  result3="$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result3" -eq 1 ] 

  result4="$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result4" -eq 1 ] 

  result5="$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result5" -eq 1 ] 

  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --database=sales --execute 'DELETE FROM user WHERE ln="mccormick"'

  result1="$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result1" -eq 0 ] 

  result2="$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result2" -eq 0 ] 

  result3="$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result3" -eq 0 ] 

  result4="$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result4" -eq 0 ] 

  result5="$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result5" -eq 0 ] 

  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql'

  result5="$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result5" -eq 2 ] 

  r=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES'| grep -c sales || true)
  [ "$r" -eq 1 ] 

  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p --execute 'DROP DATABASE IF EXISTS sales'

  r=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SHOW DATABASES'| grep -c sales || true)
  [ "$r" -eq 0 ] 

  r=$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'SHOW DATABASES'| grep -c sales || true)
  [ "$r" -eq 0 ] 

  r=$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'SHOW DATABASES'| grep -c sales || true)
  [ "$r" -eq 0 ] 

  r=$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'SHOW DATABASES'| grep -c sales || true)
  [ "$r" -eq 0 ] 

  r=$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'SHOW DATABASES' | grep -c sales || true)
  [ "$r" -eq 0 ] 
}
__eot__
sudo bats replication_ok.bats

cat <<'__eot__' >test_replication_stop_start.bats
@test 'stop replication, observe' {
  skip
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'SOURCE /tmp/extra2/extra2.sql'
  result1="$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result1" -eq 0 ] 

  result2="$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p --database=sales --execute 'SELECT * FROM user' | grep -c mccormick || true)"
  [ "$result2" -eq 0 ] 
}
__eot__
sudo bats replication_ok.bats
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
