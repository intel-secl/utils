#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
       echo "unable to read config variables"
       exit 1
fi

build_skc_library_docker()
{
	pushd $PWD
	cd ../../../../../skc_library
	make oci-archive
	popd
}

build_skc_library_docker