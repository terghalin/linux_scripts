SCHECK=$(mysql -h 172.16.0.50 -u root --password=********** -e "SHOW SLAVE STATUS\G;" | grep Slave_SQL_Running)
echo $SCHECK

#SCHECK="No"  # just for testing bad thingies

if [[ $SCHECK == *"Yes"* ]]
then
 echo "Slave is Running, no problem here";
elif [[ $SCHECK == *"No"* ]]
 then
  echo "Slave SQL is not running!"
  ### Убираем из сообщений об ошибке непечатные  для удобного чтения
  LASTERR=$(mysql -h 172.16.0.50 -u root --password=********** -e "SHOW SLAVE STATUS\G;" | grep Last_SQL_Error: | tr -dc '[:print:]')
  echo $LASTERR
  echo
  # read -p "Should we start rebuilding slave? (y/n) " -n 1 -r  # accept one character for input (without Enter)
  read -p "Do you want to REBUILD slave? This operation will lock tables on master. (yes/no) " REPLY
  case "$REPLY" in
    yes );;
    n|N|no ) echo "Aborted";;
    * ) echo "Invalid symbol or command";;
  esac
  echo
  if [[ $REPLY == *"yes"* ]]
    then
     echo "Rebuilding slave..."
     echo "Resetting master and flushing tables with read lock."
     mysql -u root -e "RESET MASTER;" && mysql -u root -e "FLUSH TABLES WITH READ LOCK;"
     MASTERPOS=$(mysql -u root -e "SHOW MASTER STATUS;" | awk 'FNR == 2 {print $2}')
     echo "Master binlog position is $MASTERPOS"
     GTID_POS=$(mysql -u root -e "SELECT BINLOG_GTID_POS('mysql-bin.000001', $MASTERPOS);" | awk 'FNR == 2')
     echo "BINLOG_GTID_POS = $GTID_POS"
     echo "Saving mysql dump to /tmp/ts_drupal.sql ..."
     mysqldump -u root --lock-all-tables ts_drupal > /tmp/ts_drupal.sql
     echo "Unlocking master tables..."
     mysql -u root -e "UNLOCK TABLES";
     echo "Copying master dump to slave directory /tmp/ts_drupal.sql"
     scp /tmp/ts_drupal.sql 172.16.0.50:/tmp/ts_drupal.sql

     echo "Stopping slave..."
     mysql -h 172.16.0.50 -u root --password=********** -e "STOP SLAVE;"
     echo "Loading master mysql dump to slave..."
     mysql -h 172.16.0.50 -u root --password=********** ts_drupal < /tmp/ts_drupal.sql
     echo "Syncing slave with master binlog..."
     mysql -h 172.16.0.50 -u root --password=********** -e "
        RESET SLAVE;
        SET GLOBAL gtid_slave_pos = '$GTID_POS';
        CHANGE MASTER TO master_use_gtid=slave_pos,
                master_host='172.16.0.5',
                master_user='slave_usr',
                master_password='**********',
                master_log_file='mysql-bin.000001',
                master_log_pos=$MASTERPOS;
                START SLAVE;"
     echo "Check if slave SQL is running..."
     sleep 3
     SCHECK=$(mysql -h 172.16.0.50 -u root --password=********** -e "SHOW SLAVE STATUS\G;" | grep Slave_SQL_Running)
     echo $SCHECK

  else exit
  fi
else
 echo "Something happend with Slave... :("
 exit
fi
