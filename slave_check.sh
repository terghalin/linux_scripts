SCHECK=$(mysql -h 172.16.0.50 -u root --password=XXXXXXXX -e "SHOW SLAVE STATUS\G;" | grep Slave_SQL_Running)
echo $SCHECK

#SCHECK="No"  # just for testing bad thingies

if [[ $SCHECK == *"Yes"* ]]
then
 echo "Slave is Running, no problem here";
elif [[ $SCHECK == *"No"* ]]
 then
  echo "Slave SQL is not running!"
  ### Убираем из сообщений об ошибке непечатные символы для удобного чтения
  LASTERR=$(mysql -h 172.16.0.50 -u root --password=XXXXXXXX -e "SHOW SLAVE STATUS\G;" | grep Last_SQL_Error: | tr -dc '[:print:]')
  echo $LASTERR
  echo
  read -p "Do you want to RESET slave? (yes/no) " REPLY
  case "$REPLY" in
    yes );;
    n|N|no ) echo "Aborted";;
    * ) echo "Invalid symbol or command";;
  esac
  echo
  if [[ $REPLY == *"yes"* ]]
    then
     echo "Resetting slave..."
     MASTERPOS=$(mysql -u root -e "SHOW MASTER STATUS;" | awk 'FNR == 2 {print $2}')
     echo "Master binlog position is $MASTERPOS"
     GTID_POS=$(mysql -u root -e "SELECT BINLOG_GTID_POS('mysql-bin.000001', $MASTERPOS);" | awk 'FNR == 2')
     echo "BINLOG_GTID_POS = $GTID_POS"
     echo "Stopping slave..."
     mysql -h 172.16.0.50 -u root --password=XXXXXXXX -e "STOP SLAVE;"
     echo "Syncing slave with master via GTID..."
     mysql -h 172.16.0.50 -u root --password=XXXXXXXX -e "
        RESET SLAVE;
        SET GLOBAL gtid_slave_pos = '$GTID_POS';
        CHANGE MASTER TO master_use_gtid=slave_pos,
                master_host='172.16.0.5',
                master_user='slave_usr',
                master_password='XXXXXXXX';
                START SLAVE;"
     echo "Check if slave SQL is running..."
     sleep 2
     SCHECK=$(mysql -h 172.16.0.50 -u root --password=XXXXXXXX -e "SHOW SLAVE STATUS\G;" | grep Slave_SQL_Running)
     echo $SCHECK

  else exit
  fi
  
else
 echo "Something happend with Slave... :("
 exit
fi
