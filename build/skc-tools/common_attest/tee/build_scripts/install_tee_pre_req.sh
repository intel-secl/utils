#!/bin//bash
source ../../../config
if [ $? -ne 0 ]; then
        echo "unable to read config variables"
        exit 1
fi

install_tee_pre_req()
{
	if [ "$OS" == "rhel" ]; then
		wget -q $SGX_URL_TEE/libPCKCertSelection.so || exit 1
		\cp -pf libPCKCertSelection.so /usr/lib64/libPCKCertSelection.so
		wget -q $SGX_URL_TEE/sgx_rpm_local_repo.tgz || exit 1
		tar -xf sgx_rpm_local_repo.tgz || exit 1
		pushd $PWD
		cd sgx_rpm_local_repo/
		rpm -ivh libsgx-dcap-default-qpl-$DCAP_QL_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-dcap-quote-verify-$DCAP_QL_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-ae-pce-$DCAP_PCE_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-ae-qve-$DCAP_QL_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-enclave-common-$DCAP_PCE_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-urts-$DCAP_PCE_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-pce-logic-$DCAP_QL_VERSION_TEE.el8.x86_64.rpm
		rpm -ivh libsgx-headers-$DCAP_PCE_VERSION_TEE.el8.x86_64.rpm
		popd
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz libPCKCertSelection.so
	elif [ "$OS" == "ubuntu" ]; then
		echo "${red} Not implemented yet for Ubuntu OS ${reset}"
	fi
}

install_tee_pre_req
