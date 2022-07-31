#!/bin/bash

#sleep 10000
set -x;
rm -rf $PGDATANEW/*
cd /tmp
ln -sFT $PGDATAOLD 11
ln -sFT $PGDATANEW 14

# Perform database initialization with new version
export PGDATA=$PGDATANEW
initdb --username="$POSTGRES_USER" --pwfile=<(echo "$POSTGRES_PASSWORD")

# Remove the postmaster.pid and start/stop the pg instances gracefully
rm -rf $PGDATAOLD/postmaster.pid

$PGBINOLD/pg_ctl start -w -D $PGDATAOLD
$PGBINOLD/pg_ctl stop -w -D $PGDATAOLD

sleep 15
pg_upgrade -b $PGBINOLD -B $PGBINNEW -d $PGDATAOLD -D $PGDATANEW --check -U $POSTGRES_USER
if [ $? -eq 0 ]; then  
  pg_upgrade -b $PGBINOLD -B $PGBINNEW -d $PGDATAOLD -D $PGDATANEW --clone -U $POSTGRES_USER
  sleep 2
  exit 0
fi
echo "Failed to upgrade database version"
exit 1
