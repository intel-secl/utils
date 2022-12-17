#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

download_psw_qpl_qgl()
{
	wget -q $SGX_URL/sgx_rpm_local_repo.tgz -P $SGX_AGENT_BIN_DIR || exit 1
}

download_psw_qpl_qgl
