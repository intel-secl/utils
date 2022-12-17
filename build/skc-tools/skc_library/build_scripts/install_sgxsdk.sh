#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_sgxsdk()
{
	wget -q $SGX_URL/sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin || exit 1
	chmod +x sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
	./sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin -prefix=$SGX_INSTALL_DIR || exit 1
	source $SGX_INSTALL_DIR/sgxsdk/environment
	if [ $? -ne 0 ]; then
		echo "failed while setting sgx environment"
		exit 1
	fi
	rm -rf sgx_linux_x64_sdk_$SGX_SDK_VERSION.bin
}

install_sgxsdk
