#!/bin/bash

USER_ID=${USER_ID:-1001}
SERVICES="cms ihub kbs sqvs"
SERVICES_WITH_DB="scs shvs aas"

services=$(eval "echo \$SERVICES")
services_db=$(eval "echo \$SERVICES_WITH_DB")

BASE_PATH=isecl
LOG_PATH=logs
CONFIG_PATH=config
DB_PATH=db

mkdir -p $BASE_PATH && chmod 711 -R $BASE_PATH && chown -R $USER_ID:$USER_ID $BASE_PATH
for service in $services; do
  service=$BASE_PATH/$service
  mkdir -p $service && chown -R $USER_ID:$USER_ID $service
  mkdir -p $service/$LOG_PATH
  mkdir -p $service/$CONFIG_PATH
  chown -R $USER_ID:$USER_ID $service/$CONFIG_PATH
  chown -R $USER_ID:$USER_ID $service/$LOG_PATH
  if [ $service == "$BASE_PATH/kbs" ]; then
    mkdir $service/opt
    chown -R $USER_ID:$USER_ID $service/opt
  fi
done

for service in $services_db; do
  service=$BASE_PATH/$service
  mkdir -p $service && chown -R $USER_ID:$USER_ID $service
  mkdir -p $service/$LOG_PATH
  mkdir -p $service/$CONFIG_PATH
  mkdir -p $service/$DB_PATH
  chown -R $USER_ID:$USER_ID $service/$CONFIG_PATH
  chown -R $USER_ID:$USER_ID $service/$LOG_PATH
  chown -R $USER_ID:$USER_ID $service/$DB_PATH
done
