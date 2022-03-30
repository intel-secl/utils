#!/bin//bash
source ../../../config
if [ $? -ne 0 ]; then
        echo "unable to read config variables"
        exit 1
fi

install_dcap_pre_req()
{
	if [ "$OS" == "rhel" ]; then
		wget -q $SGX_URL/sgx_rpm_local_repo.tgz || exit 1
		tar -xf sgx_rpm_local_repo.tgz || exit 1
		pushd $PWD
		cd sgx_rpm_local_repo/
		rpm -ivh libsgx-dcap-ql-$MP_RPM_VER.el8.x86_64.rpm --nodeps
		rpm -ivh libsgx-qe3-logic-$MP_RPM_VER.el8.x86_64.rpm --nodeps
		rpm -ivh libsgx-dcap-ql-devel-$MP_RPM_VER.el8.x86_64.rpm --nodeps
		popd
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tgz
	elif [ "$OS" == "ubuntu" ]; then
                echo $SGX_LIBS_REPO | sudo tee /etc/apt/sources.list.d/intel-sgx.list
                wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
                $PKGMGR update -y || exit 1
                $PKGMGR install -y libsgx-dcap-ql  libsgx-qe3-logic || exit 1
                $PKGMGR install -qy libsgx-dcap-ql-dev || exit 1
	fi
}

install_dcap_pre_req
