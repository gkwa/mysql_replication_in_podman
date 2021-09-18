#!/usr/bin/env bats
source ./common.sh

# This assumes replication is running

@test 'test_fart2' {
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest1'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest2'

  
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest1'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest1 --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest1 --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'

  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest2'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my1p --database=ptest2 --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my1p --database=ptest2 --execute 'INSERT INTO dummy (name) VALUES ("c"), ("d")'

  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my1p --database=ptest1 --execute 'SELECT id FROM dummy WHERE name="a"')
  [ "$result" == 1 ]

  result=$(podman exec --env=MYSQL_PWD=root my2c mysql --skip-column-names --user=root --host=my2p --database=ptest2 --execute 'SELECT id FROM dummy WHERE name="c"')
  [ "$result" == 3 ]
}
