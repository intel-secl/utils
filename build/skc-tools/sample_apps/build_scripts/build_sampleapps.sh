#!/bin/bash

build_sample_apps()
{
	pushd $PWD
	cd ../../../../../utils/tools/sample-sgx-attestation
        touch rootca.pem
	make all
	if [ $? -ne 0 ]; then
		echo "ERROR: sample apps build failed with $?"
		exit 1
	fi
	popd
}

build_sample_apps
