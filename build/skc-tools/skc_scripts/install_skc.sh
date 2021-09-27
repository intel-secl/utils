#!/bin/bash
source install_enterprise_skc.sh
if [ $? -ne 0 ]
then
        echo "${red} Basic components installation failed ${reset}"
        exit 1
fi

source install_orchestrator.sh
if [ $? -ne 0 ]
then
        echo "${red} SHVS/IHUB installation failed ${reset}"
        exit 1
fi
