#!/bin/bash
source ../../../../../build/skc-tools/config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SGX_AGENT_DIR)

create_sgx_agent_tar()
{
	\cp -pf ../deploy_scripts/deployment_prerequisites.sh $SGX_AGENT_DIR
	\cp -pf ../deploy_scripts/README.install $SGX_AGENT_DIR
	\cp -pf ../../config $SGX_AGENT_DIR
	tar -cf $TAR_NAME.tar -C $SGX_AGENT_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "${green} sgx_agent.tar file and sgx_agent.sha2 checksum file created ${reset}"
}

build_sgx_agent_docker()
{
	pushd $PWD
	\cp -prf $SGX_AGENT_BIN_DIR ../../../../../sgx_agent/dist/image/
	if [ "$OS" == "rhel" ]; then
		tar -xf ../../../../../sgx_agent/dist/image/bin/sgx_rpm_local_repo.tgz -C ../../../../../sgx_agent/dist/image/bin/
	fi
	cd ../../../../../sgx_agent
	make oci-archive || exit 1
	rm -rf dist/image/bin
	popd
}

if [ "$OS" == "rhel" ]; then
	rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

source build_prerequisites.sh
if [ $? -ne 0 ]; then
	echo "${red} failed to resolve package dependencies ${reset}"
	exit
fi

source download_dcap_driver.sh  
if [ $? -ne 0 ]; then
	echo "${red} sgx dcap driver download failed ${reset}"
	exit
fi

source install_sgxsdk.sh
if [ $? -ne 0 ]; then
	echo "${red} sgxsdk install failed ${reset}"
	exit
fi

source download_sgx_psw_qgl.sh
if [ $? -ne 0 ]; then
	echo "${red} sgx psw, qgl rpms download failed ${reset}"
	exit
fi

source download_mpa_uefi_rpm.sh  
if [ $? -ne 0 ]; then
	echo "${red} mpa uefi rpm download failed ${reset}"
	exit
fi

source build_pckretrieval_tool.sh
if [ $? -ne 0 ]; then
	echo "${red} pckretrieval tool build failed ${reset}"
	exit
fi

build_sgx_agent_docker
if [ $? -ne 0 ]; then
	echo "${red} sgx agent docker build failed ${reset}"
	exit
fi

create_sgx_agent_tar
if [ $? -ne 0 ]; then
	echo "${red} failed to create sgx agent tar ${reset}"
	exit
fi
