#!/bin/bash
verify_checksum()
{
	sha256sum -c fd_agent.sha2 > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "checksum verification failed"
		exit 1
	fi
	tar -xf fd_agent.tar
	echo "fd agent untar completed"
	echo "Please update the fd_agent.conf and then run ./deploy_fd_agent.sh"
}

verify_checksum
