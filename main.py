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

# FIXME: reminder: i'm using appveyor secrets to decrypt this from ./auth.json.enc, thats obscure
# podman login --username mtmonacelli registry.redhat.io $REGISTRY_REDHAT_IO_PASSWORD

podman pull docker.io/perconalab/percona-toolkit:latest

{{ status() }}

{% for pod in pods %}
podman pod stop --ignore {{ pod.name }}
podman pod rm --ignore --force {{ pod.name }}
podman volume exists {{ pod.volume }} && podman volume rm --force {{ pod.volume }}
{% endfor %}

podman network exists {{ global.network}} && podman network rm --force {{ global.network }}

{{ status() }}

podman network create {{ global.network }}
{% for pod in pods %}
podman volume create {{ pod.volume }}
{%- endfor %}

# start clean
[[ -d 'reptest' ]] && mv reptest reptest.$(date +%s)

{%- for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}/extra
{%- endfor %}

{% for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}/my.cnf
[mysqld]
bind-address                   = {{ pod.name }}.dns.podman
server_id                      = {{ loop.index }}
# log_bin                      = /var/log/mysql/mysql-bin.log
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
binlog_do_db                   = db
binlog_do_db                   = dummy

; https://www.clusterdb.com/mysql-cluster/get-mysql-replication-up-and-running-in-5-minutes
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
podman container create --name={{ pod.containers[0].name }} --pod={{ pod.name }} --health-start-period=80s --log-driver=journald --volume=./reptest/{{ pod.containers[0].name }}/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/{{ pod.containers[0].name }}/extra:/tmp/extra:Z --volume={{ pod.volume }}:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD={{ global.user_root_pass }} --env=MYSQL_USER={{ global.user_non_root }} --env=MYSQL_PASSWORD={{ global.user_non_root_pass }} --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
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
until podman exec --tty --interactive {{ pod.containers[0].name }} mysql --host={{ pod.name }} --user={{ global.user_non_root }} --password={{ global.user_non_root_pass }} --execute 'SHOW DATABASES' </dev/null; do sleep 5; done;
{%- endfor %}

{% for pod in pods %}{% set ip='ip' ~ loop.index %}
podman inspect {{ pod.containers[0].name }} |grep -i ipaddr
{{ip}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network }}.IPAddress{%- raw -%} }} {%- endraw -%}')
echo ${{ip}}
{%- endfor %}

{% for pod in pods %}{% set ip='ip' ~ loop.index %}
# mysqladmin --port={{ global.internal_port }} --host=${{ip}} --user={{ global.user_non_root }} --password={{ global.user_non_root_pass }} password ''
{%- endfor %}

# ip test
{% for pod in pods %}{% set ip='ip' ~ loop.index %}
mysql --port={{ global.internal_port }} --host=${{ip}} --user={{ global.user_non_root }} --password={{ global.user_non_root_pass }} --execute 'SHOW DATABASES' </dev/null
{%- endfor %}

# FIXME: {% set containers = [] %}{% for pod in pods %}{{ containers.append( pod.containers[0].name ) }}{% endfor %}

# dns test
{% for container in containers %}
{% for pod in pods %}
time podman exec --tty --interactive {{ container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'SHOW DATABASES' </dev/null
{%- endfor %}
{%- endfor %}

{{ status() }}

{%- for pod in pods %}
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
{%- set user = "'" ~ global.user_replication ~ "'@'" ~ "$replica_ip" ~ pod.replica.number ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES' </dev/null

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ pod.replica.fqdn ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES' </dev/null

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ pod.replica.fqdn.split('.')[0] ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES' </dev/null

{%- set user = "'" ~ global.user_replication ~ "'@'" ~ '%' ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES' </dev/null
{% endfor %}

{%- for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'FLUSH TABLES WITH READ LOCK' </dev/null
{%- endfor %}

{% for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'UNLOCK TABLES' </dev/null
{%- endfor %}

{% for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
{%- endfor %}

: <<'END_COMMENT'
# workaround for mysql 5.6: GRANT USAGE ON *.* TO...
{%- for pod in pods %}
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'$replica_ip{{ pod.replica.number }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'$replica_ip{{ pod.replica.number }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'{{ pod.replica.fqdn }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'{{ pod.replica.fqdn.split('.')[0] }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'{{ pod.replica.fqdn.split('.')[0] }}'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "GRANT USAGE ON *.* TO '{{ global.user_replication }}'@'%'" </dev/null
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }} --execute "DROP USER '{{ global.user_replication }}'@'%'" </dev/null
{% endfor %}
END_COMMENT

{% for pod in pods %}
mkdir -p reptest/{{ pod.containers[0].name }}/extra
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network }}.IPAddress{%- raw -%} }} {%- endraw -%}')
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}/extra/extra.sql
CREATE DATABASE IF NOT EXISTS `myflixdb2`;
CREATE TABLE IF NOT EXISTS `myflixdb2`.`sale_details`
  (
     `id`               INT auto_increment,
     `sale_person_name` VARCHAR(255),
     `no_products_sold` INT,
     `sales_department` VARCHAR(255),
     PRIMARY KEY (id)
  ); 
-- INSERT INTO myflixdb.members VALUES (`tom hillbilly`, `male`);
__eot__
# cat reptest/{{ pod.containers[0].name }}/extra/extra.sql
{%- endfor %}

{% for pod in pods %}
# podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
{%- endfor %}

{% for pod in pods %}
# podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra/extra.sql' </dev/null
{%- endfor %}

{% for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'SELECT User, Host from mysql.user ORDER BY user' </dev/null
{%- endfor %}

{%- for block in replication %}
position=$(podman exec --tty --interactive {{ block.source.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:{{ block.instance.container }} source:{{ block.source.container }} position:$position
podman exec --tty --interactive {{ block.instance.container }} mysql --host={{ block.instance.pod }} --user={{ global.user_root }} --password={{ global.user_root_pass }} \
--execute "CHANGE MASTER TO MASTER_HOST='{{ block.source.pod }}.dns.podman',\
MASTER_USER='{{ global.user_replication }}',\
MASTER_PASSWORD='{{ global.user_replication_pass }}',\
MASTER_LOG_FILE='mysql-bin.000003',\
MASTER_LOG_POS=$position"
{%- endfor %}

: <<'END_COMMENT'
# FIXME: it would be really nice to be able to use dns here
{%- for block in replication %}
source_ip=$(podman inspect {{ block.source.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
target_ip=$(podman inspect {{ block.instance.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ global.network}}.IPAddress{%- raw -%} }} {%- endraw -%}')
position=$(podman exec --tty --interactive {{ block.source.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:$target_ip source:$source_ip position:$position
podman exec --tty --interactive {{ block.instance.container }} mysql --host={{ block.instance.pod }} --user={{ global.user_root }} --password={{ global.user_root_pass }} \
--execute "CHANGE MASTER TO MASTER_HOST='"$source_ip"',\
MASTER_USER='{{ global.user_replication }}',\
MASTER_PASSWORD='{{ global.user_replication_pass }}',\
MASTER_LOG_FILE='mysql-bin.000003',\
MASTER_LOG_POS="$position'"'
{%- endfor %}
END_COMMENT

{% for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'START SLAVE' </dev/null
{%- endfor %}

: <<'END_COMMENT'
{%- for pod in pods %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ pod.name }}.dns.podman --execute 'STOP SLAVE' </dev/null
{%- endfor %}
END_COMMENT

# testing replication
: <<'END_COMMENT'
{%- for block in replication %}
podman exec --tty --interactive {{ block.instance.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.instance.pod }} --execute 'SHOW DATABASES' </dev/null
podman exec --tty --interactive {{ block.source.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.source.pod }} --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
podman exec --tty --interactive {{ block.instance.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.instance.pod }} --execute 'SHOW DATABASES' </dev/null
{% endfor %}
END_COMMENT

cat <<'__eot__' >test_replication_is_running.bats
@test 'ensure replication is running' {
  podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my2c mysql --user=root --password=root --host=my2p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my3c mysql --user=root --password=root --host=my3p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my5c mysql --user=root --password=root --host=my5p.dns.podman --execute 'START SLAVE' </dev/null

  sleep 1
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'USE dummy' </dev/null
  podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p --execute 'USE dummy' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null
  run podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p --execute 'USE dummy' </dev/null
  sleep 1
  [ "$status" -eq 1 ]
}
__eot__
sudo bats test_replication_is_running.bats

cat <<'__eot__' >test_replication_is_stopped.bats
@test 'stop replication and ensure its not running' {
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'CREATE DATABASE IF NOT EXISTS dummy' </dev/null

  podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --tty --interactive my2c mysql --user=root --password=root --host=my2p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --tty --interactive my3c mysql --user=root --password=root --host=my3p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p.dns.podman --execute 'STOP SLAVE' </dev/null
  podman exec --tty --interactive my5c mysql --user=root --password=root --host=my5p.dns.podman --execute 'STOP SLAVE' </dev/null

  sleep 1
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'USE dummy' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'DROP DATABASE IF EXISTS dummy' </dev/null

  sleep 1
  run podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p --execute 'USE dummy' </dev/null
  [ "$status" -eq 1 ]

  sleep 1
  run podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p --execute 'USE dummy' </dev/null
  [ "$status" -eq 0 ]

  # make sure replication is running again for next test...managing state like this will get dirty, i promise
  podman exec --tty --interactive my1c mysql --user=root --password=root --host=my1p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my2c mysql --user=root --password=root --host=my2p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my3c mysql --user=root --password=root --host=my3p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my4c mysql --user=root --password=root --host=my4p.dns.podman --execute 'START SLAVE' </dev/null
  podman exec --tty --interactive my5c mysql --user=root --password=root --host=my5p.dns.podman --execute 'START SLAVE' </dev/null
  sleep 1
}
__eot__
sudo bats test_replication_is_stopped.bats

# i guess positions have increased, yes?
{%- for block in replication %}
position=$(podman exec --tty --interactive {{ block.source.container }} mysql --user={{ global.user_root }} --password={{ global.user_root_pass }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G' </dev/null |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:{{ block.instance.container }} source:{{ block.source.container }} position:$position
{%- endfor %}
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
