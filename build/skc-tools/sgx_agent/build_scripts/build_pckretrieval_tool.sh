#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

build_PCKID_Retrieval_tool()
{
	rm -rf $GIT_CLONE_PATH
	pushd $PWD
	git clone $SGX_DCAP_REPO $GIT_CLONE_PATH || exit 1
	cp -pf remove_pccs_connect.diff $GIT_CLONE_PATH/tools/PCKRetrievalTool
	cd $GIT_CLONE_PATH/
	git checkout $SGX_DCAP_TAG
	cd $GIT_CLONE_PATH/tools/PCKRetrievalTool
	git apply remove_pccs_connect.diff
	make || exit 1
	mkdir -p $SGX_AGENT_BIN_DIR
	\cp -pf libdcap_quoteprov.so.1 pck_id_retrieval_tool_enclave.signed.so PCKIDRetrievalTool $SGX_AGENT_BIN_DIR
	rm -rf $GIT_CLONE_PATH
	popd
}

build_PCKID_Retrieval_tool
