#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

build_sgx_agent()
{
	pushd $PWD
	cd ../../../../../sgx_agent
	make installer || exit 1
	mkdir -p $SGX_AGENT_BIN_DIR
	\cp -pf out/sgx_agent-*.bin $SGX_AGENT_BIN_DIR
	\cp -pf dist/linux/sgx_agent.env $SGX_AGENT_DIR
	popd
}

build_sgx_agent
