#!/bin/bash
verify_checksum()
{
	sha256sum -c skc_library.sha2 > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		echo "checksum verification failed"
		exit 1
	fi
	tar -xf skc_library.tar
	echo "skc_library untar completed."
	echo "Please update create_roles.conf and then run ./skc_library_create_roles.sh. Copy the generated token printed on the console."
	echo "Please update skc_library.conf with the token obtained from previous step and other details and then run ./deploy_skc_library.sh"
}

verify_checksum
