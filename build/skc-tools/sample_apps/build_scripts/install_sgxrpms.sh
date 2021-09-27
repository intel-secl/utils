#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_psw_qpl_qgl()
{
	mkdir -p $SAMPLEAPPS_BIN_DIR
	if [ "$OS" == "rhel" ]; then
		wget -q $SGX_URL/sgx_rpm_local_repo.tgz || exit 1
                \cp -pf sgx_rpm_local_repo.tgz $SAMPLEAPPS_BIN_DIR
		tar -xf sgx_rpm_local_repo.tgz || exit 1
		yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-dcap-ql-devel || exit 1
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	elif [ "$OS" == "ubuntu" ]; then
		echo 'deb [arch=amd64] https://download.01.org/intel-sgx/sgx_repo/ubuntu/ bionic main' | sudo tee /etc/$PKGMGR/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo $PKGMGR-key add - || exit 1
		$PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-launch libsgx-uae-service libsgx-urts libsgx-dcap-ql-dev || exit 1
	fi
}

install_psw_qpl_qgl
