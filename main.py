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
# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls
{% endmacro -%}

set -o errexit

podman --version

# podman login --username mtmonacelli registry.redhat.io $REGISTRY_REDHAT_IO_PASSWORD

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

rm -rf ./reptest/

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

{% for pod in manifest['pods'] %}
# bridge mode networking
podman pod create --name={{ pod.name }} --publish={{ manifest['global']['internal_port'] }}{{loop.index}}:{{ manifest['global']['internal_port'] }} --network={{ manifest['global']['network'] }}
podman container create --name={{ pod.containers[0].name }} --rm --health-start-period=80s --log-driver=journald --pod={{ pod.name }} --volume=./reptest/{{ pod.containers[0].name }}/my.cnf:/etc/my.cnf.d/100-reptest.cnf --volume={{ pod.volume }}:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=demo --env=MYSQL_USER=user --env=MYSQL_PASSWORD=pass --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman pod ls
{% endfor %}

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
until podman exec --tty --interactive {{ pod.containers[0].name }} mysql --host={{ pod.name }} --user=user --password=pass --execute "SHOW DATABASES;"; do sleep 5; done;
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
podman inspect {{ pod.containers[0].name }} | grep -i ipaddr
{{ip}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ manifest['global']['network'] }}.IPAddress{%- raw -%} }} {%- endraw -%}') 
echo ${{ip}}
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
# mysqladmin --port={{ manifest['global']['internal_port'] }} --host=${{ip}} --user=user --password=pass password ''
{%- endfor %}

# ip test
{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
mysql --port={{ manifest['global']['internal_port'] }} --host=${{ip}} --user=user --password=pass --execute "SHOW DATABASES;"
{%- endfor %}

# FIXME: {% set containers = [] %}{% for pod in manifest['pods'] %}{{ containers.append( pod.containers[0].name ) }}{% endfor %}

# dns test
{% for container in containers %}
{% for pod in manifest['pods'] %}
time podman exec --tty --interactive {{ container }} mysql --user=root --password=demo --host={{ pod.name }}.dns.podman --execute 'SHOW DATABASES;' </dev/null
{%- endfor %}
{%- endfor %}

{{ status() }}
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
