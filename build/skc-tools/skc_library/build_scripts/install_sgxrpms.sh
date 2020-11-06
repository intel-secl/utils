#!/bin/bash
SKCLIB_DIR=$PWD/skc_library
SKCLIB_BIN_DIR=$SKCLIB_DIR/bin
SGX_VERSION=2.11
OS_FLAVOUR="rhel8.2"
SGX_URL="https://download.01.org/intel-sgx/sgx-linux/${SGX_VERSION}/distro/$OS_FLAVOUR-server"

install_psw_qpl_qgl()
{
	wget -q $SGX_URL/sgx_rpm_local_repo.tgz || exit 1
	\cp -pf sgx_rpm_local_repo.tgz $SKCLIB_BIN_DIR
        tar -xf sgx_rpm_local_repo.tgz
        yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
        dnf install -y --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-dcap-ql-devel || exit 1

	rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
}

install_psw_qpl_qgl
