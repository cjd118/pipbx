#!/bin/bash

echo "Fixing permissions"
chown -R asterisk:asterisk /backup

echo "Starting mysql"
service mysql start

echo "Starting apache"
service apache2 start

echo "Starting freepbx"
fwconsole start

echo "Attempting to load previous backup"
if [ -f /backup/new.tar.gz ]; then
  fwconsole backup --restore /backup/new.tar.gz
else
  echo "No backup found - is this a new install?"  
fi

echo "starting backups"
/scripts/backup.sh


while /bin/true; do
  ps aux |grep mysqld |grep -q -v grep
  MYSQL_STATUS=$?
  ps aux |grep asterisk |grep -q -v grep
  ASTERISK_STATUS=$?

  if [ $ASTERISK_STATUS -ne 0 -o $MYSQL_STATUS -ne 0 ]; then
    echo "One of the processes has exited."
    exit 1
  fi
  sleep 60
done
