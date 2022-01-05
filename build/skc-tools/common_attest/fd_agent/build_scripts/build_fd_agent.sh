#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

build_fda()
{
	pushd $PWD
	cd ../../../../../../intel-secl-tee
	make fda-installer || exit 1
	mkdir -p $FD_AGENT_BIN_DIR
	\cp -pf deployments/installer/fda-*.bin $FD_AGENT_BIN_DIR
	\cp -pf deployments/installer/fda.env $FD_AGENT_DIR
	popd
}

build_fda
