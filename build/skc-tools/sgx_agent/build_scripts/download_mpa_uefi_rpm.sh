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
		if [ "$VER" == "20.04" ]; then
			wget -q  $MPA_URL/sgx_debian_local_repo.tgz -O - | tar -xz || exit 1
			\cp sgx_debian_local_repo/pool/main/libs/libsgx-ra-uefi/libsgx-ra-uefi_$MP_RPM_VER-focal1_amd64.deb $SGX_AGENT_BIN_DIR
			rm -rf sgx_debian_local_repo.tgz
		fi
	fi
}

fetch_mpa_uefi_rpm
