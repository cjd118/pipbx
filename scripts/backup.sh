#!/bin/bash

while /bin/true; do
  echo "Waiting 30 mins for the next automatic backup..."
  sleep 1800
  echo "Running backup and storing to /backup/new.tgz..."
  cd /backup
  fwconsole bu --backup 1dc542cb-83fe-4068-a1ee-11784bce1f99
  if [ "$?" != "0" ]; then
    echo "Error creating automatic backup"
  else
    mv /backup/new.tar.gz /backup/old.tar.gz
    mv 2* new.tar.gz
    echo "Backup saved to /backup/new.tar.gz"
  fi
done