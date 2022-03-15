#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi


install_psw_qpl_qgl()
{
        rm -rf $GIT_CLONE_PATH
        wget -q $SGX_STACK_URL/sgx_rpm_local_repo.tgz || exit 1
        tar -xf sgx_rpm_local_repo.tgz || exit 1
        yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
        $PKGMGR install -qy --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-dcap-ql-devel || exit 1
        rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
}

install_psw_qpl_qgl
