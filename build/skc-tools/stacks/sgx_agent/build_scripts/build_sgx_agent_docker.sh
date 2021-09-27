#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SGX_AGENT_DIR)

create_sgx_agent_tar()
{
	\cp -pf ../deploy_scripts/agent_container_prereq.sh $SGX_AGENT_DIR
	\cp -pf ../../../sgx_agent/deploy_scripts/deployment_prerequisites.sh $SGX_AGENT_DIR
	\cp -pf ../../../sgx_agent/deploy_scripts/README.install $SGX_AGENT_DIR
	\cp -pf ../../../config $SGX_AGENT_DIR
	tar -cf $TAR_NAME.tar -C $SGX_AGENT_DIR . --remove-files
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
	echo "${green} sgx_agent.tar file and sgx_agent.sha2 checksum file created ${reset}"
}

build_sgx_agent_docker()
{
	pushd $PWD
	\cp -prf $SGX_AGENT_BIN_DIR ../../../../../../sgx_agent/dist/image/
	if [ "$OS" == "rhel" ]; then
		wget -q $INTEL_SGX_STACK_REPO/intelsgxstack.repo -P ../../../../../../sgx_agent/dist/image/bin/ || exit 1
		wget -q $DCAP_SIGNED_LIBRARIES
		tar -xf prebuilt_dcap_1.11.tar.gz
		\cp -prf psw/ ../../../../../../sgx_agent/dist/image/bin/
		rm -rf psw/ prebuilt_dcap_1.11.tar.gz
	fi
	cd ../../../../../../sgx_agent
	make oci-archive_stacks || exit 1
	rm -rf dist/image/bin
	popd
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

pushd $PWD
cd ../../stack_scripts
source install_sgxsdk.sh
if [ $? -ne 0 ]; then
        echo "${red} sgxsdk install failed ${reset}"
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
mkdir -p $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/libdcap_quoteprov.so.1 $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/pck_id_retrieval_tool_enclave.signed.so $SGX_AGENT_BIN_DIR
\cp -pf ../../../sgx_agent/build_scripts/sgx_agent/bin/PCKIDRetrievalTool $SGX_AGENT_BIN_DIR

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
