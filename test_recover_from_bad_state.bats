#!/usr/bin/env bats
source ./common.sh

@test 'test_recover_from_bad_state' {

  
  until grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my1p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my1p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my3p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my3p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my4p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my4p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_IO_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my5p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;
  until grep --silent 'Slave_SQL_Running: Yes' <<<"$(podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my5p.dns.podman --execute 'SHOW SLAVE STATUS\G')"; do sleep 5; done;

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest1'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest2'
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest2'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest2'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest2'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest2'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1'
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest2'
  [ "$status" == 1 ]

  
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'STOP SLAVE'
  podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'STOP SLAVE'

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest1'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest1 --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest1 --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'

  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --execute 'CREATE DATABASE IF NOT EXISTS ptest2'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --database=ptest2 --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --database=ptest2 --execute 'INSERT INTO dummy (name) VALUES ("c"), ("d")'

  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1'
  [ "$status" == 0 ]

  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest2'
  [ "$status" == 0 ]

  
  
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1' #2
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1' #3
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1' #4
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1' #5
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest2' #1
  [ "$status" == 1 ]
  
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest2' #3
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest2' #4
  [ "$status" == 1 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest2' #5
  [ "$status" == 1 ]

  # start rep
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

  
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest1' #1
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p.dns.podman --execute 'USE ptest2' #1
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest1' #2
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my2c mysql --user=root --host=my2p.dns.podman --execute 'USE ptest2' #2
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest1' #3
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my3c mysql --user=root --host=my3p.dns.podman --execute 'USE ptest2' #3
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest1' #4
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my4c mysql --user=root --host=my4p.dns.podman --execute 'USE ptest2' #4
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest1' #5
  [ "$status" == 0 ]
  run podman exec --env=MYSQL_PWD=root my5c mysql --user=root --host=my5p.dns.podman --execute 'USE ptest2' #5
  [ "$status" == 0 ]
}
