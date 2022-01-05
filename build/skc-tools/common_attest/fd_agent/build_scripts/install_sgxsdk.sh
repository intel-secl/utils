#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
        echo "unable to read config variables"
        exit 1
fi

install_sgxsdk()
{
	wget -q $SGX_URL_TEE/sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin || exit 1
        chmod u+x sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin
        ./sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin -prefix=$SGX_INSTALL_DIR || exit 1
        source $SGX_INSTALL_DIR/sgxsdk/environment
        if [ $? -ne 0 ]; then
                echo "${red} failed while setting sgx environment ${reset}"
                exit 1
        fi
	rm -f sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin
}

install_sgxsdk
