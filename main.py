import pathlib

import jinja2
import yaml

in_file = pathlib.Path("manifest.yml")

with open(in_file, "r") as stream:
    try:
        manifest = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

tmpl_str = """#!/bin/bash

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

# podman login --username mtmonacelli registry.redhat.io $REGISTRY_REDHAT_IO_PASSWORD

podman pull docker.io/perconalab/percona-toolkit:latest

{{ status() }}

{% for pod in manifest['pods'] %}
podman pod stop --ignore {{ pod.name }}
podman pod rm --ignore --force {{ pod.name }}
podman volume exists {{ pod.volume }} && podman volume rm --force {{ pod.volume }}
{% endfor %}

podman network exists {{ manifest['global']['network'] }} && podman network rm --force {{ manifest['global']['network'] }}

{{ status() }}

podman network create {{ manifest['global']['network'] }}
{% for pod in manifest['pods'] %}
podman volume create {{ pod.volume }}
{%- endfor %}

rm -rf reptest/

{% for pod in manifest['pods'] %}
mkdir -p reptest/{{ pod.containers[0].name }}/extra
{% endfor %}

{% for pod in manifest['pods'] %}
mkdir -p reptest/{{ pod.containers[0].name }}
cat <<'__eot__' >reptest/{{ pod.containers[0].name }}/my.cnf
[mysqld]
bind-address             = {{ pod.name }}.dns.podman
server_id                = {{ loop.index }}
#log_bin                 = /var/log/mysql/mysql-bin.log
binlog_do_db             = db
__eot__
{% endfor %}

# pods with bridge mode networking
{%- for pod in manifest['pods'] %}
podman pod create --name={{ pod.name }} --publish={{ manifest['global']['internal_port'] }}{{loop.index}}:{{ manifest['global']['internal_port'] }} --network={{ manifest['global']['network'] }}
{%- endfor %}

# mysqld containers
{%- for pod in manifest['pods'] %}
podman container create --name={{ pod.containers[0].name }} --pod={{ pod.name }} --rm --health-start-period=80s --log-driver=journald --volume=./reptest/{{ pod.containers[0].name }}/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume=./reptest/{{ pod.containers[0].name }}/extra:/tmp/extra:Z --volume={{ pod.volume }}:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD={{ manifest['global']['user_root_pass'] }} --env=MYSQL_USER={{ manifest['global']['user_non_root'] }} --env=MYSQL_PASSWORD={{ manifest['global']['user_non_root_pass'] }} --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
{%- endfor %}

{% for pod in manifest['pods'] %}
podman pod start {{ pod.name }}
{%- endfor %}

{% for pod in manifest['pods'] %}
podman wait {{ pod.containers[0].name }} --condition=running
{%- endfor %}

{% for pod in manifest['pods'] %}
podman volume inspect {{ pod.volume }}
{%- endfor %}

{{ status() }}

{% for pod in manifest['pods'] %}
until podman exec --tty --interactive {{ pod.containers[0].name }} mysql --host={{ pod.name }} --user={{ manifest['global']['user_non_root'] }} --password={{ manifest['global']['user_non_root_pass'] }} --execute "SHOW DATABASES;"; do sleep 5; done;
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
podman inspect {{ pod.containers[0].name }} | grep -i ipaddr
{{ip}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ manifest['global']['network'] }}.IPAddress{%- raw -%} }} {%- endraw -%}')
echo ${{ip}}
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
# mysqladmin --port={{ manifest['global']['internal_port'] }} --host=${{ip}} --user={{ manifest['global']['user_non_root'] }} --password={{ manifest['global']['user_non_root_pass'] }} password ''
{%- endfor %}

# ip test
{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
mysql --port={{ manifest['global']['internal_port'] }} --host=${{ip}} --user={{ manifest['global']['user_non_root'] }} --password={{ manifest['global']['user_non_root_pass'] }} --execute "SHOW DATABASES;"
{%- endfor %}

# FIXME: {% set containers = [] %}{% for pod in manifest['pods'] %}{{ containers.append( pod.containers[0].name ) }}{% endfor %}

# dns test
{% for container in containers %}
{% for pod in manifest['pods'] %}
time podman exec --tty --interactive {{ container }} mysql --user={{ manifest['global']['user_root'] }} --password={{ manifest['global']['user_root_pass'] }} --host={{ pod.name }}.dns.podman --execute 'SHOW DATABASES;' </dev/null
{%- endfor %}
{%- endfor %}

{{ status() }}

{% for pod in manifest['pods'] %}
replica_ip{{ pod.replica.number }}=$(podman inspect {{ pod.replica.container }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ manifest['global']['network'] }}.IPAddress{%- raw -%} }} {%- endraw -%}')
mkdir -p reptest/{{ pod.containers[0].name }}/extra
cat <<__eot__ >reptest/{{ pod.containers[0].name }}/extra/add_user.sql
CREATE USER '{{ manifest['global']['user_replication'] }}'@'$replica_ip{{ pod.replica.number }}' IDENTIFIED WITH mysql_native_password BY '{{ manifest['global']['user_replication_pass'] }}';
GRANT REPLICATION SLAVE ON *.* TO '{{ manifest['global']['user_replication'] }}'@'$replica_ip{{ pod.replica.number }}';
FLUSH PRIVILEGES;
__eot__
{% endfor %}

{%- for pod in manifest['pods'] %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ manifest['global']['user_root'] }} --password={{ manifest['global']['user_root_pass'] }} --host={{ pod.name }}.dns.podman --execute 'SOURCE /tmp/extra/add_user.sql;'
{%- endfor %}

{%- for pod in manifest['pods'] %}
podman exec --tty --interactive {{ pod.containers[0].name }} mysql --user={{ manifest['global']['user_root'] }} --password={{ manifest['global']['user_root_pass'] }} --host={{ pod.name }}.dns.podman --execute 'SELECT User, Host, Password FROM mysql.user;'
{%- endfor %}
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)

