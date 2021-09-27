#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SKCLIB_DIR)

install_prerequisites()
{
	source build_prerequisites.sh	
	if [ $? -ne 0 ]; then
		echo "${red} Pre-build step failed ${reset}"
		exit 1
	fi
}

install_sgxsdk()
{
	source install_sgxsdk.sh
	if [ $? -ne 0 ]; then
		echo "${red} sgx sdk installation failed ${reset}"
		exit 1
	fi
}

install_sgxrpm()
{
	source install_sgxrpms.sh
	if [ $? -ne 0 ]; then
		echo "${red} sgx psw/qgl rpm installation failed ${reset}"
		exit 1
	fi
}
	
install_ctk()
{
	source install_ctk.sh
	if [ $? -ne 0 ]; then
		echo "${red} cryptoapitoolkit installation failed ${reset}"
		exit 1
	fi
}

build_skc_library()
{
	source build_skclib.sh
	if [ $? -ne 0 ]; then
		echo "${red} skc_library build failed ${reset}"
		exit 1
	fi
}

build_skc_library_docker()
{
        pushd $PWD
        \cp -prf $SKCLIB_DIR/cryptoapitoolkit ../../../../../skc_library/dist/image/
        \cp -prf $SKCLIB_DIR/sgxssl ../../../../../skc_library/dist/image/
        \cp -prf ../deploy_scripts/skc_library.conf ../../../../../skc_library/dist/image/
        \cp -prf $SKCLIB_BIN_DIR ../../../../../skc_library/dist/image/
        \cp -prf ../deploy_scripts/credential_agent.sh ../../../../../skc_library/dist/image/
        \cp -prf ../../config ../../../../../skc_library/dist/image/
	if [ "$OS" == "rhel" ]
	then
		tar -xf ../../../../../skc_library/dist/image/bin/sgx_rpm_local_repo.tgz -C ../../../../../skc_library/dist/image/bin/ || exit 1
	fi
        cd ../../../../../skc_library
        mkdir -p out
        make oci-archive || exit 1
        rm -rf dist/image/cryptoapitoolkit dist/image/sgxssl dist/image/bin dist/image/skc_library.conf dist/image/credential_agent.sh
        popd
}

rm -rf $SKCLIB_DIR

if [ "$OS" == "rhel" ]; then
	rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

install_prerequisites
install_sgxsdk
install_sgxrpm
install_ctk
build_skc_library
build_skc_library_docker
if [ $? -ne 0 ]; then
	echo "${red} skc_library docker build failed ${reset}"
	exit 1
fi
