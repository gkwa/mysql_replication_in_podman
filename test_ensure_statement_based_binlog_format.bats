#!/usr/bin/env bats
source ./common.sh

@test 'test_ensure_statement_based_binlog_format' {
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my1p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
  run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
  [ "$status" -eq 0 ]
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my2p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
  run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
  [ "$status" -eq 0 ]
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my3p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
  run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
  [ "$status" -eq 0 ]
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my4p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
  run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
  [ "$status" -eq 0 ]
  
  result=$(podman exec --env=MYSQL_PWD=root my1c mysql --user=root --host=my5p --skip-column-names --execute 'SHOW VARIABLES LIKE "binlog_format"')
  run grep --silent -E 'binlog_format.*STATEMENT' <<<"$result"
  [ "$status" -eq 0 ]
  
}
