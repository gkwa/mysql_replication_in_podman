#!/bin/bash

podman network exists replication || podman network create replication

podman volume exists my1dbdata || podman volume create my1dbdata
podman volume exists my2dbdata || podman volume create my2dbdata
podman volume exists my3dbdata || podman volume create my3dbdata
podman volume exists my4dbdata || podman volume create my4dbdata
podman volume exists my5dbdata || podman volume create my5dbdata

# pods with bridge mode networking
podman pod create --name=my1p --publish=33061:3306 --network=replication
podman pod create --name=my2p --publish=33062:3306 --network=replication
podman pod create --name=my3p --publish=33063:3306 --network=replication
podman pod create --name=my4p --publish=33064:3306 --network=replication
podman pod create --name=my5p --publish=33065:3306 --network=replication

# mysqld containers
podman container create --name=my1c --pod=my1p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --healthcheck-command 'mysql --user=root --password="root" --host=my1p --execute "USE mysql" || exit 1' --volume=my1dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my2c --pod=my2p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --healthcheck-command 'mysql --user=root --password="root" --host=my2p --execute "USE mysql" || exit 1' --volume=my2dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my3c --pod=my3p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --healthcheck-command 'mysql --user=root --password="root" --host=my3p --execute "USE mysql" || exit 1' --volume=my3dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my4c --pod=my4p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --healthcheck-command 'mysql --user=root --password="root" --host=my4p --execute "USE mysql" || exit 1' --volume=my4dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80
podman container create --name=my5c --pod=my5p --health-start-period=80s --log-driver=journald --healthcheck-interval=0 --health-retries=10 --health-timeout=30s --healthcheck-command 'CMD-SHELL mysqladmin ping -h localhost || exit 1' --healthcheck-command 'mysql --user=root --password="root" --host=my5p --execute "USE mysql" || exit 1' --volume=my5dbdata:/var/lib/mysql/data:Z --env=MYSQL_ROOT_PASSWORD=root --env=MYSQL_USER=joe --env=MYSQL_PASSWORD=joe --env=MYSQL_DATABASE=db registry.redhat.io/rhel8/mysql-80

podman pod start my1p
podman pod start my2p
podman pod start my3p
podman pod start my4p
podman pod start my5p


