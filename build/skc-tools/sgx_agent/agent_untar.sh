#!/bin/bash
verify_checksum()
{
	sha256sum -c sgx_agent.sha2 > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "checksum verification failed"
		exit 1
	fi
	tar -xf sgx_agent.tar
	echo "sgx agent untar completed"
	echo "Please update the agent.conf and then run ./deploy_sgx_agent.sh"
}

verify_checksum
