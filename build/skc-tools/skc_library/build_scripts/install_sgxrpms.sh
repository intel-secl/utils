#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_psw_qpl_qgl()
{
	mkdir -p $SKCLIB_BIN_DIR
	rm -rf $GIT_CLONE_PATH
	if [ "$OS" == "rhel" ]; then
		echo "${red} Unsupported OS. Please use Ubuntu 20.04 ${reset}"
		exit 1
	elif [ "$OS" == "ubuntu" ]; then
        echo $SGX_LIBS_REPO | sudo tee /etc/$PKGMGR/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo $PKGMGR-key add - || exit 1
		$PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-launch libsgx-uae-service libsgx-urts libsgx-dcap-ql-dev || exit 1
	fi
}

install_psw_qpl_qgl
