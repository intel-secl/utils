#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_sgxsdk()
{
        wget -q $INTEL_SGX_STACK_REPO/intelsgxstack.repo || exit 1
        yum-config-manager --add-repo file://$PWD/intelsgxstack.repo || exit 1
        $PKGMGR install -y linux-sgx-sdk
        source $SGX_INSTALL_DIR/sgxsdk/environment
        if [ $? -ne 0 ]; then
                echo "${red} failed while setting sgx environment ${reset}"
                exit 1
        fi
	rm -rf intelsgxstack.repo
}

install_sgxsdk
