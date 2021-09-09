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
# bind-address = 127.0.0.1
__eot__
{% endfor %}

{% for pod in manifest['pods'] %}
podman pod create --name {{ pod.name }} -p {{ manifest['global']['internal_port'] }}{{loop.index}}:{{ manifest['global']['internal_port'] }} --network {{ manifest['global']['network'] }}
podman container create --log-driver journald --pod={{ pod.name }} -v $PWD/reptest/{{ pod.containers[0].name }}/my.cnf:/etc/my.cnf.d/100-reptest.cnf -v {{ pod.volume }}:/var/lib/mysql/data:Z -e MYSQL_ROOT_PASSWORD=demo -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db --name {{ pod.containers[0].name }} registry.redhat.io/rhel8/mysql-80
podman pod ls
{% endfor %}

{% for pod in manifest['pods'] %}
podman pod start {{ pod.name }}
{%- endfor %}

{% for pod in manifest['pods'] %}
podman wait {{ pod.containers[0].name }} --condition running
{%- endfor %}

{% for pod in manifest['pods'] %}
podman volume inspect {{ pod.volume }}
{%- endfor %}

{{ status() }}

{% for pod in manifest['pods'] %}
podman volume inspect {{ pod.volume }}
{%- endfor %}

{% for pod in manifest['pods'] %}
until podman exec -ti {{ pod.containers[0].name }} bash -c 'mysql --host {{ pod.name }} --user=user --password=pass --execute "SHOW DATABASES;"'; do sleep 1; done;
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
podman inspect {{ pod.containers[0].name }} | grep -i ipaddr
{{ip}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ manifest['global']['network'] }}.IPAddress{%- raw -%} }} {%- endraw -%}') 
echo ${{ip}}
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
# mysqladmin --port {{ manifest['global']['internal_port'] }} --host ${{ip}} --user=user --password=pass password ''
{%- endfor %}

{% for pod in manifest['pods'] %}{% set ip='ip' ~ loop.index %}
mysql --port {{ manifest['global']['internal_port'] }} --host ${{ip}} --user=user --password=pass --execute "SHOW DATABASES;"
{%- endfor %}

{{ status() }}
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
