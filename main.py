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

set -o errexit

podman --version

# podman login --username mtmonacelli registry.redhat.io

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls

{% for pod in manifest['pods'] %}
podman pod stop --ignore {{ pod.name }}
podman pod rm --ignore --force {{ pod.name }}
podman volume exists {{ pod.volume }} && podman volume rm --force {{ pod.volume }}
{% endfor %}

podman network exists {{ manifest['global']['network'] }} && podman network rm --force {{ manifest['global']['network'] }}

# podman ps -a --pod
podman ps --pod
podman network ls
podman volume ls
podman ps
podman pod ls

podman network create {{ manifest['global']['network'] }}
{% for pod in manifest['pods'] %}
podman volume create {{ pod.volume }}
{%- endfor %}

{% for pod in manifest['pods'] %}
podman pod create --name {{ pod.name }} -p 3306{{loop.index}}:{{ manifest['global']['internal_port'] }} --network {{ manifest['global']['network'] }}
podman container create --log-driver journald --pod={{ pod.name }} -v {{ pod.volume }}:/var/lib/mysql/data:Z -e MYSQL_ROOT_PASSWORD=demo -e MYSQL_USER=user -e MYSQL_PASSWORD=pass -e MYSQL_DATABASE=db --name {{ pod.containers[0].name }} registry.redhat.io/rhel8/mysql-80
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

podman ps -a --pod
podman network ls
podman volume ls
podman ps
podman pod ls

{% for pod in manifest['pods'] %}
podman volume inspect {{ pod.volume }}
{%- endfor %}

{% for pod in manifest['pods'] %}
until podman exec -ti {{ pod.containers[0].name }} bash -c 'mysql --host {{ pod.name }} --user=user --password=pass --execute "SHOW DATABASES;"'; do sleep 5; done;
{%- endfor %}

{% for pod in manifest['pods'] %}
podman ps --pod
podman inspect {{ pod.name }} | grep -i ipaddr
ip{{loop.index}}=$(podman inspect {{ pod.containers[0].name }} --format '{%- raw -%} {{ {%- endraw -%}.NetworkSettings.Networks.{{ manifest['global']['network'] }}.IPAddress{%- raw -%} }} {%- endraw -%}') 
echo $ip{{loop.index}}
mysql --port 3306 --host $ip{{loop.index}} --user=user --password=pass --execute "SHOW DATABASES;"
{% endfor %}
"""

template = jinja2.Template(tmpl_str)
result = template.render(manifest=manifest)
print(result)
