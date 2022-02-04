#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $FD_AGENT_DIR)

create_fd_agent_tar()
{
	\cp -pf ../deploy_scripts/*.sh $FD_AGENT_DIR
        \cp -pf ../../../sgx_agent/deploy_scripts/deployment_prerequisites.sh $FD_AGENT_DIR
        \cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/* $FD_AGENT_DIR/bin
	\cp -pf ../deploy_scripts/README.install $FD_AGENT_DIR
	\cp -pf ../deploy_scripts/fdagent.conf $FD_AGENT_DIR
	\cp -pf ../../../config $FD_AGENT_DIR
	tar -cf $TAR_NAME.tar -C $FD_AGENT_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
        rm -rf ../../../sgx_agent/build_scripts/sgx_agent/
	echo "${green} fd_agent.tar file and fd_agent.sha2 checksum file created ${reset}"
}

if [ "$OS" == "rhel" ]; then
	rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

pushd $PWD
cd ../../../sgx_agent/build_scripts
source build_prerequisites.sh
if [ $? -ne 0 ]; then
	echo "${red} failed to resolve package dependencies ${reset}"
	exit
fi
popd

source install_sgxsdk.sh
if [ $? -ne 0 ]; then
        echo "${red} sgxsdk install failed ${reset}"
        exit
fi

source download_dcap_driver.sh  
if [ $? -ne 0 ]; then
        echo "${red} sgx dcap driver download failed ${reset}"
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

pushd $PWD
cd ../../../sgx_agent/build_scripts
source build_pckretrieval_tool.sh
if [ $? -ne 0 ]; then
        echo "${red} pckretrieval tool build failed ${reset}"
        exit
fi
popd

source build_fd_agent.sh
if [ $? -ne 0 ]; then
        echo "${red} fd agent build failed ${reset}"
        exit
fi

create_fd_agent_tar
