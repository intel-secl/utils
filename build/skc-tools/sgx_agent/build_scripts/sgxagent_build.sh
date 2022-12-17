#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SGX_AGENT_DIR)

create_sgx_agent_tar()
{
	\cp -pf ../deploy_scripts/*.sh $SGX_AGENT_DIR
	\cp -pf ../deploy_scripts/README.install $SGX_AGENT_DIR
	\cp -pf ../deploy_scripts/agent.conf $SGX_AGENT_DIR
	\cp -pf ../../config $SGX_AGENT_DIR
	tar -cf $TAR_NAME.tar -C $SGX_AGENT_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "${green} sgx_agent.tar file and sgx_agent.sha2 checksum file created ${reset}"
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

if [ "$OS" == "rhel" ]; then
	source download_sgx_psw_qgl.sh
	if [ $? -ne 0 ]; then
	        echo "${red} sgx psw, qgl rpms download failed ${reset}"
	        exit
	fi
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

source build_sgx_agent.sh
if [ $? -ne 0 ]; then
        echo "${red} sgx agent build failed ${reset}"
        exit
fi

create_sgx_agent_tar
