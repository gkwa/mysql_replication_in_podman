
source ./common.sh

@test 'test_ensure_replication_is_running' {
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'DROP DATABASE IF EXISTS ptest'
  run bash -c "podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW DATABASES' | grep ptest"
  [ "$status" -eq 1 ]
  run bash -c "podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --execute 'SHOW DATABASES' | grep ptest"
  [ "$status" -eq 1 ]
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'CREATE DATABASE IF NOT EXISTS ptest'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'CREATE TABLE dummy (id INT(11) NOT NULL auto_increment PRIMARY KEY, name CHAR(5)) engine=innodb;'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'INSERT INTO dummy (name) VALUES ("a"), ("b")'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --database=ptest --execute 'SELECT * FROM dummy'
  podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --database=ptest --execute 'SELECT * FROM dummy'
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="a"')
  [ $result -eq 1 ]
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --skip-column-names --user=root --host=my4p --database=ptest --execute 'SELECT id FROM dummy WHERE name="c"')
  [ "$result" == "" ]
}