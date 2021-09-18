#!/usr/bin/env bats
source ./common.sh

@test 'test_fart' {
  echo waiting for replication to be ready...
  sleep=3
  tries=20
  loop1 repcheck my1c my1c.dns.podman $sleep $tries
  loop1 repcheck my1c my2c.dns.podman $sleep $tries
  loop1 repcheck my1c my3c.dns.podman $sleep $tries
  loop1 repcheck my1c my4c.dns.podman $sleep $tries
  loop1 repcheck my1c my5c.dns.podman $sleep $tries

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest'

  
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'

  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my1p --database=ptest --execute 'SELECT id FROM dummy WHERE name="a"')
  [ "$result" == 1 ]

  # ensure these fail
  
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest'
  [ "$status" == 1 ]

  # start replication
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'START SLAVE USER="repl" PASSWORD="repl"'

  echo waiting for replication to be ready...
  sleep=3
  tries=20
  loop1 repcheck my1c my1c.dns.podman $sleep $tries
  loop1 repcheck my1c my2c.dns.podman $sleep $tries
  loop1 repcheck my1c my3c.dns.podman $sleep $tries
  loop1 repcheck my1c my4c.dns.podman $sleep $tries
  loop1 repcheck my1c my5c.dns.podman $sleep $tries

  # ensure these pass
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest'
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest'
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest'
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest'
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest'
  [ "$status" == 0 ]
}
