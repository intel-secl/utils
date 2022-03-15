#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

SKCLIB_DIR=skc_library
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

create_skc_library_tar()
{
	\cp -pf ../deploy_scripts/*.sh $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/skc_library_create_roles.sh $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/deployment_prerequisites.sh $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/skc_library.conf $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/create_roles.conf $SKCLIB_DIR
        \cp -pf ../../../skc_library/deploy_scripts/credential_agent.sh $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/README.install $SKCLIB_DIR
	\cp -pf ../../../config $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/nginx.patch $SKCLIB_DIR
	\cp -pf ../../../skc_library/deploy_scripts/openssl.patch $SKCLIB_DIR
	tar -cf $TAR_NAME.tar -C $SKCLIB_DIR . --remove-files || exit 1
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "${green} skc_library.tar file and skc_library.sha2 checksum file created ${reset}"
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

rm -rf $SKCLIB_DIR

if [ "$OS" == "rhel" ]; then
        rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

install_prerequisites
install_sgxsdk
install_sgxrpm
install_ctk
build_skc_library
create_skc_library_tar
