#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SGX_AGENT_DIR)

create_sgx_agent_tar()
{
	\cp -pf ../deploy_scripts/*.sh $SGX_AGENT_DIR
	\cp -pf ../../../sgx_agent/deploy_scripts/README.install $SGX_AGENT_DIR
	\cp -pf ../../../sgx_agent/deploy_scripts/agent.conf $SGX_AGENT_DIR
        \cp -pf ../../../sgx_agent/deploy_scripts/deployment_prerequisites.sh $SGX_AGENT_DIR
        \cp -pf ../../../sgx_agent/deploy_scripts/create_roles.sh $SGX_AGENT_DIR
	\cp -pf ../../../config $SGX_AGENT_DIR
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

pushd $PWD
cd ../../stack_scripts
source install_sgxsdk.sh
if [ $? -ne 0 ]; then
        echo "${red} sgxsdk install failed ${reset}"
        exit
fi
popd

pushd $PWD
cd ../../../sgx_agent/build_scripts
source build_pckretrieval_tool.sh
if [ $? -ne 0 ]; then
        echo "${red} pckretrieval tool build failed ${reset}"
        exit
fi
popd
mkdir -p $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/libdcap_quoteprov.so.1 $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/pck_id_retrieval_tool_enclave.signed.so $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/PCKIDRetrievalTool $SGX_AGENT_BIN_DIR


pushd $PWD
cd ../../../sgx_agent/build_scripts
source build_sgx_agent.sh
if [ $? -ne 0 ]; then
        echo "${red} sgx agent build failed ${reset}"
        exit
fi
popd
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/sgx_agent-*.bin $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/sgx_agent.env $SGX_AGENT_DIR


create_sgx_agent_tar
