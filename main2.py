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

# podman pod stop --ignore --all; podman images prune; podman container stop --ignore --all; podman pod rm --all --force; podman container rm --all --force; podman volume rm --all --force; for network in $(podman network ls --format json | jq -r '.[].Name'); do if [[ "$network" !=  "podman" ]]; then podman network exists $network && podman network rm $network; fi; done; podman pod stop --ignore --all; podman images prune; podman container stop --ignore --all; podman pod rm --all --force; podman container rm --all --force; podman volume rm --all --force; for network in $(podman network ls --format json | jq -r '.[].Name'); do if [[ "$network" !=  "podman" ]]; then podman network exists $network && podman network rm $network; fi; done; podman ps; podman ps --pod; podman ps -a --pod; podman network ls; podman volume ls; podman pod ls; #destroyall

set -o errexit

podman info --debug

# FIXME: {% set containers = [] %}{% for pod in pods %}{{ containers.append( pod.containers[0].name ) }}{% endfor %}

set +o errexit
podman container stop --log-level debug --ignore {{ containers |join(' ') }}
set -o errexit
{% for pod in pods %}
podman pod exists {{ pod.name }} && podman pod stop --log-level debug --ignore {{ pod.name }}
{%- endfor %}

{% for pod in pods %}
podman pod exists {{ pod.name }} && podman wait --condition=stopped {{ containers |join(' ') }}
{%- endfor %}
podman pod ls 

rm -rf reptest
mkdir reptest

{% for pod in pods %}
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}_my.cnf
[mysqld]
innodb_flush_log_at_trx_commit = 1
sync_binlog                    = 1
server_id                      = {{ loop.index }}
auto_increment_offset          = {{ loop.index }}
bind-address                   = {{ pod.name }}.dns.podman
datadir                        = /var/log/mysql
log_bin                        = mysql-bin.log
log_slave_updates              = ON
__eot__
{% endfor %}

{% for pod in pods %}
cat reptest/{{ pod.containers[0].name }}_my.cnf
echo
{%- endfor %}

{% for pod in pods %}
podman volume exists {{ pod.volume }} || podman volume create {{ pod.volume }}
{%- endfor %}

podman network exists {{ global.network}} || podman network create {{ global.network }}

{% for pod in pods -%}
podman pod exists {{ pod.name }} || podman pod create --name={{ pod.name }} --publish={{ global.internal_port }}{{loop.index}}:{{ global.internal_port }} --network={{ global.network }}
{% endfor -%}

{% for pod in pods %}
podman container exists {{ pod.containers[0].name }} || podman container create --name={{ pod.containers[0].name }} --pod={{ pod.name }} --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --volume=./reptest/{{ pod.containers[0].name }}_my.cnf:/etc/my.cnf.d/100-reptest.cnf --healthcheck-command 'mysql --user={{ global.user_root }} --password="{{ global.user_root_pass }}" --host={{ pod.name }} --execute "USE mysql" || exit 1' --volume={{ pod.volume }}:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD={{ global.user_root_pass }} --env=MYSQL_USER={{ global.user_non_root }} --env=MYSQL_PASSWORD={{ global.user_non_root_pass }} --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
{%- endfor %}

{% for pod in pods %}
rm -rf --preserve-root $(podman volume inspect {{ pod.volume }} | jq -r '.[]|.Mountpoint')/*;
{%- endfor %}

{% for pod in pods %}
du -sh $(podman volume inspect {{ pod.volume }} | jq -r '.[]|.Mountpoint')/;
{%- endfor %}

{% for pod in pods %}
du -shc $(podman volume inspect {{ pod.volume }} | jq -r '.[]|.Mountpoint')
{%- endfor %}

set +o errexit
podman pod start {{ pods |map(attribute='name') |join(' ') }}
set -o errexit
podman pod start {{ pods |map(attribute='name') |join(' ') }}

{% for pod in pods %}
du -shc $(podman volume inspect {{ pod.volume }} | jq -r '.[]|.Mountpoint')
{%- endfor %}

podman pod ls 
podman logs --since=30s {{ pods[0].containers[0].name }} 

{% for pod in pods %}
until podman healthcheck run {{ pod.containers[0].name }} </dev/null; do sleep 3; done
{%- endfor %}

{% for pod in pods %}
{%- set user = "'" ~ global.user_replication ~ "'@'" ~ '%' ~ "'" %}
# {{ user }} on {{ pod.containers[0].name }}:
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "CREATE USER {{ user }} IDENTIFIED WITH mysql_native_password BY '{{ global.user_replication_pass }}'"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute "GRANT REPLICATION SLAVE ON *.* TO {{ user }}"
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'FLUSH PRIVILEGES'
{%- endfor %}

{% for block in replication %}
position=$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.source.container }} mysql --user={{ global.user_root }} --host={{ block.source.pod }} --execute 'SHOW MASTER STATUS\G' |sed -e '/^ *Position:/!d' -e 's/[^0-9]*//g')
echo target:{{ block.instance.container }} source:{{ block.source.container }} position:$position
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ block.instance.container }} mysql --host={{ block.instance.pod }} --user={{ global.user_root }} \
--execute "CHANGE MASTER TO MASTER_HOST='{{ block.source.pod }}.dns.podman',\
MASTER_USER='{{ global.user_replication }}',\
MASTER_PASSWORD='{{ global.user_replication_pass }}',\
MASTER_LOG_FILE='mysql-bin.000003',\
MASTER_LOG_POS=$position"
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pod.containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }}.dns.podman --execute 'START SLAVE USER="{{ global.user_replication }}" PASSWORD="{{ global.user_replication_pass }}"'
{%- endfor %}

podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --execute 'CREATE DATABASE IF NOT EXISTS ptest'

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --host={{ pod.name }} --user={{ global.user_root }} --execute 'USE ptest' && echo {{ pod.name }} ok
{%- endfor %}

{% for pod in pods %}
podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pod.name }} --execute 'SHOW VARIABLES LIKE "binlog_format"'
{%- endfor %}

cat <<'__eot__' >test_simple_insert.bats
source ./common.sh

@test 'test_simple_insert' {
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --execute 'DROP DATABASE IF EXISTS ptest'
  run bash -c "podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --execute 'SHOW DATABASES' | grep ptest"
  [ "$status" -eq 1 ]
  run bash -c "podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host=my4p --execute 'SHOW DATABASES' | grep ptest"
  [ "$status" -eq 1 ]
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --execute 'CREATE DATABASE IF NOT EXISTS ptest'
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --database=ptest --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --database=ptest --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host={{ pods[0].name }} --database=ptest --execute 'SELECT * FROM dummy'
  podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --user={{ global.user_root }} --host=my4p --database=ptest --execute 'SELECT * FROM dummy'
  result=$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --skip-column-names --user={{ global.user_root }} --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="a"')
  [ $result -eq 1 ]
  result=$(podman exec --env=MYSQL_PWD={{ global.user_root_pass }} {{ pods[0].containers[0].name }} mysql --skip-column-names --user={{ global.user_root }} --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="c"')
  [ "$result" == "" ]
}
__eot__
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
