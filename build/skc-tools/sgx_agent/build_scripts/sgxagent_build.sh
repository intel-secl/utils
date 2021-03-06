#!/bin/bash
SGX_AGENT_DIR=sgx_agent
TAR_NAME=$(basename $SGX_AGENT_DIR)

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')

create_sgx_agent_tar()
{
	\cp -pf ../deploy_scripts/*.sh $SGX_AGENT_DIR
	\cp -pf ../deploy_scripts/README.install $SGX_AGENT_DIR
	\cp -pf ../deploy_scripts/agent.conf $SGX_AGENT_DIR
	tar -cf $TAR_NAME.tar -C $SGX_AGENT_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "sgx_agent.tar file and sgx_agent.sha2 checksum file created"
}

if [ "$OS" == "rhel" ]
then
 rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

source build_prerequisites.sh
if [ $? -ne 0 ]
then
	echo "failed to resolve package dependencies"
	exit
fi

source download_dcap_driver.sh  
if [ $? -ne 0 ]
then
        echo "sgx dcap driver download failed"
        exit
fi

source install_sgxsdk.sh
if [ $? -ne 0 ]
then
        echo "sgxsdk install failed"
        exit
fi

source download_sgx_psw_qgl.sh
if [ $? -ne 0 ]
then
        echo "sgx psw, qgl rpms download failed"
        exit
fi

source download_mpa_uefi_rpm.sh  
if [ $? -ne 0 ]
then
        echo "mpa uefi rpm download failed"
        exit
fi

source build_pckretrieval_tool.sh
if [ $? -ne 0 ]
then
        echo "pckretrieval tool build failed"
        exit
fi

source build_sgx_agent.sh
if [ $? -ne 0 ]
then
        echo "sgx agent build failed"
        exit
fi

if [ "$OS" == "rhel" ]
then
	source build_sgx_agent_docker.sh
	if [ $? -ne 0 ]
	then
		echo "sgx agent docker build failed"
		exit
	fi
fi

create_sgx_agent_tar
