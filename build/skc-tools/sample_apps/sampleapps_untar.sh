#!/bin/bash
verify_checksum()
{
	sha256sum -c sample_apps.sha2 > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "checksum verification failed"
		exit 1
	fi
	tar -xf sample_apps.tar
	echo "Sample Apps untar completed."
	echo "Update sample_apps.conf file and run Sample Apps."
}

verify_checksum
