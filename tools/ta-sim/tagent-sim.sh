#!/bin/bash

if [ "$1" = "start" ] || [ "$1" = "restart" ]
then
  ULIMIT=50000
  OPTIND=2
  while getopts :u:h opt; do
    case "$opt" in
    u) ULIMIT="${OPTARG}" ;;
    h) echo "Usage: $0 $1 -u "$ULIMIT""
    exit 0 ;;
    *) echo "Usage: $0 $1 -u "$ULIMIT""
    exit 1;;
    esac
  done
fi

if [ "$1" = "start" ]
then
    ulimit -n $ULIMIT
    ./ta-sim start &>> logs/tagent-sim.log &
elif [ "$1" = "stop" ]
then
    ps axf | grep ta-sim | grep -v grep | awk '{print "kill -9 " $1}' | sh
elif [ "$1" = "restart" ]
then
    ulimit -n $ULIMIT
    ./ta-sim start &>> logs/tagent-sim.log &
    sleep 2
    ps axf | grep ta-sim | grep -v grep | awk '{print "kill -9 " $1}' | sh
elif [ "$1" = "create-all-hosts" ]
then
    ./ta-sim create-all-hosts &>> logs/tagent-sim.log &
elif [ "$1" = "create-all-flavors" ]
then
    ./ta-sim create-all-flavors &>> logs/tagent-sim.log &
elif [ "$1" = "version" ]
then
    ./ta-sim version
else
    echo "   ####### Trustagent Simulator ####### "
    echo " tagent-sim.sh start [-u ulimit]   : To start simulator "
    echo " tagent-sim.sh stop                : To stop simulator"
    echo " tagent-sim.sh restart [-u ulimit] : To restart simulator"
    echo " tagent-sim.sh create-all-hosts    : To create all hosts"
    echo " tagent-sim.sh create-all-flavors  : To create all flavors"
fi
