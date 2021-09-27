#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SKCLIB_DIR)

install_prerequisites()
{
	pushd $PWD
	cd ../../../skc_library/build_scripts
	source build_prerequisites.sh
	if [ $? -ne 0 ]; then
		echo "${red} Pre-build step failed ${reset}"
		exit 1
	fi
	popd
}

install_sgxsdk()
{
	pushd $PWD	
	cd ../../stack_scripts
	source install_sgxsdk.sh
	if [ $? -ne 0 ]; then
		echo "${red} sgx sdk installation failed ${reset}"
		exit 1
	fi
	popd
}

install_sgxrpm()
{
	pushd $PWD
	cd ../../stack_scripts
	source install_sgxrpms.sh	
	if [ $? -ne 0 ]; then
		echo "${red} sgx psw/qgl rpm installation failed ${reset}"
		exit 1
	fi
	popd
}

install_ctk()
{
	pushd $PWD
	cd ../../../skc_library/build_scripts
	source install_ctk.sh
	if [ $? -ne 0 ]; then
		echo "${red} cryptoapitoolkit installation failed ${reset}"
		exit 1
	fi
	popd
	source ../../../config
	mkdir -p $SKCLIB_DIR
	\cp -rpf $CTK_INSTALL $SKCLIB_DIR
	\cp -rpf $SGXSSL_PREFIX $SKCLIB_DIR

}

build_skc_library()
{
	mkdir -p $SKCLIB_BIN_DIR
	pushd $PWD
	cd ../../../skc_library/build_scripts
	source build_skclib.sh
	if [ $? -ne 0 ]; then
		echo "${red} skc_library build failed ${reset}"
		exit 1
	fi
	popd
	\cp -pf $LIB_DIR/engines-1.1/pkcs11.so $SKCLIB_BIN_DIR

}

build_skc_library_docker()
{
	pushd $PWD
	\cp -prf $SKCLIB_DIR/cryptoapitoolkit ../../../../../../skc_library/dist/image/
	\cp -prf $SKCLIB_DIR/sgxssl ../../../../../../skc_library/dist/image/
	\cp -prf ../../../skc_library/deploy_scripts/skc_library.conf ../../../../../../skc_library/dist/image/
	\cp -prf $SKCLIB_BIN_DIR ../../../../../../skc_library/dist/image/
	\cp -prf ../../../skc_library/deploy_scripts/credential_agent.sh ../../../../../../skc_library/dist/image/
	\cp -prf ../../../config ../../../../../../skc_library/dist/image/
	if [ "$OS" == "rhel" ]
	then
		wget -q $INTEL_SGX_STACK_REPO/intelsgxstack.repo -P ../../../../../../skc_library/dist/image/bin/ || exit 1
	fi
	cd ../../../../../../skc_library
	mkdir -p out
	make oci-archive_stacks || exit 1
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
