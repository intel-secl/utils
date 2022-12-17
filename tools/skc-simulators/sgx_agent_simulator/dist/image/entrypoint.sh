#!/bin/bash

source /etc/secret-volume/secrets.txt
export CCC_ADMIN_USERNAME
export CCC_ADMIN_PASSWORD

COMPONENT_NAME=sgx_agent
PRODUCT_HOME=/opt/$COMPONENT_NAME
BIN_PATH=$PRODUCT_HOME/bin
LOG_PATH=/var/log/$COMPONENT_NAME
CONFIG_PATH=/etc/$COMPONENT_NAME
CERTS_PATH=$CONFIG_PATH/certs
CERTDIR_TRUSTEDJWTCERTS=$CERTS_PATH/trustedjwt
CERTDIR_TRUSTEDCAS=$CERTS_PATH/trustedca

if [ ! -f $CONFIG_PATH/.setup_done ]; then
  for directory in $LOG_PATH $CONFIG_PATH $BIN_PATH $CERTS_PATH $CERTDIR_TRUSTEDJWTCERTS $CERTDIR_TRUSTEDCAS; do
    mkdir -p $directory
    if [ $? -ne 0 ]; then
      echo "Cannot create directory: $directory"
      exit 1
    fi
    chmod 700 $directory
    chmod g+s $directory
  done
  export BEARER_TOKEN=`./create_roles.sh`
  if [ $? -ne 0 ]; then
        echo "sgx_agent token generation failed. exiting"
        exit 1
  fi
  sgx_agent setup all
  if [ $? -ne 0 ]; then
    exit 1
  fi
  touch $CONFIG_PATH/.setup_done
fi
# to get actual hostname inside the container
cp /etc/hostname /proc/sys/kernel/hostname

if [ ! -z "$SETUP_TASK" ]; then
  cp $CONFIG_PATH/config.yml /tmp/config.yml
  IFS=',' read -ra ADDR <<< "$SETUP_TASK"
  for task in "${ADDR[@]}"; do
    if [ "$task" == "update_service_config" ]; then
        sgx_agent setup $task
        if [ $? -ne 0 ]; then
          cp /tmp/config.yml $CONFIG_PATH/config.yml
          exit 1
        fi
        continue 1
    fi
    sgx_agent setup $task --force
    if [ $? -ne 0 ]; then
      cp /tmp/config.yml $CONFIG_PATH/config.yml
      exit 1
    fi
  done
  rm -rf /tmp/config.yml
fi

sgx_agent run
