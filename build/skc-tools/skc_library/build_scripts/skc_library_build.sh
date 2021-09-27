#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

SKCLIB_DIR=skc_library
TAR_NAME=$(basename $SKCLIB_DIR)

install_prerequisites()
{
	source build_prerequisites.sh	
	if [ $? -ne 0 ]; then
		echo "${red} Pre-build step failed ${reset}"
		exit 1
	fi
}

create_skc_library_tar()
{
	\cp -pf ../deploy_scripts/*.sh $SKCLIB_DIR
	\cp -pf ../deploy_scripts/skc_library.conf $SKCLIB_DIR
	\cp -pf ../deploy_scripts/create_roles.conf $SKCLIB_DIR
	\cp -pf ../deploy_scripts/README.install $SKCLIB_DIR
	\cp -pf ../../config $SKCLIB_DIR
	if [[ "$OS" == "rhel" && "$VER" == "8.2" ]]; then
	        \cp -pf ../deploy_scripts/nginx.patch $SKCLIB_DIR
	        \cp -pf ../deploy_scripts/openssl.patch $SKCLIB_DIR
        elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
	        \cp -pf ../deploy_scripts/nginx_ubuntu.patch $SKCLIB_DIR
	        \cp -pf ../deploy_scripts/openssl_ubuntu.patch $SKCLIB_DIR
        fi
	tar -cf $TAR_NAME.tar -C $SKCLIB_DIR . --remove-files || exit 1
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "${green} skc_library.tar file and skc_library.sha2 checksum file created ${reset}"
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
