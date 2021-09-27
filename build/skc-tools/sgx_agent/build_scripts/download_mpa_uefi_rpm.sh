#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

fetch_mpa_uefi_rpm() {
	if [ "$OS" == "rhel" ]; then
		wget -q $MPA_URL/sgx_rpm_local_repo.tgz -O - | tar -xz || exit 1
		\cp sgx_rpm_local_repo/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm $SGX_AGENT_BIN_DIR
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz
	elif [ "$OS" == "ubuntu" ]; then
		wget -q https://download.01.org/intel-sgx/sgx-dcap/$DCAP_VERSION/linux/tools/SGXMultiPackageAgent/$OS_FLAVOUR-server/debian_pkgs/libs/libsgx-ra-uefi/libsgx-ra-uefi_1.11.100.2-bionic1_amd64.deb -P $SGX_AGENT_BIN_DIR || exit 1
	fi
}

fetch_mpa_uefi_rpm
