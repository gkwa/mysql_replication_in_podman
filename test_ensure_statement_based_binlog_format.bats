
source ./common.sh

@test 'test_ensure_statement_based_binlog_format' {
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --execute 'SHOW VARIABLES LIKE "binlog_format"')
  [ "$result" == "STATMENT" ]
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --execute 'SHOW VARIABLES LIKE "binlog_format"')
  [ "$result" == "STATMENT" ]
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --execute 'SHOW VARIABLES LIKE "binlog_format"')
  [ "$result" == "STATMENT" ]
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --execute 'SHOW VARIABLES LIKE "binlog_format"')
  [ "$result" == "STATMENT" ]
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --execute 'SHOW VARIABLES LIKE "binlog_format"')
  [ "$result" == "STATMENT" ]
}