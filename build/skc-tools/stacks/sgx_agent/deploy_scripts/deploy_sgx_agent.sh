#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

uninstall()
{
	echo "uninstalling PCKIDRetrieval Tool"
	rm -rf $USR_BIN_DIR/libdcap_quoteprov.so.1 $USR_BIN_DIR/pck_id_retrieval_tool_enclave.signed.so $USR_BIN_DIR/PCKIDRetrievalTool
        rm -rf $USR_LOCALBIN_DIR/libdcap_quoteprov.so.1 $USR_LOCALBIN_DIR/pck_id_retrieval_tool_enclave.signed.so $USR_LOCALBIN_DIR/PCKIDRetrievalTool
        rm -rf $USR_SBIN_DIR/libdcap_quoteprov.so.1 $USR_SBIN_DIR/pck_id_retrieval_tool_enclave.signed.so $USR_SBIN_DIR/PCKIDRetrievalTool

	echo "Uninstalling existing SGX Agent Installation...."
	sgx_agent uninstall --purge
}

install_prerequisites()
{
	source deployment_prerequisites.sh
	if [[ $? -ne 0 ]]; then
		echo "${red} sgx agent pre-requisite package installation failed. exiting ${reset}"
		exit 1
	fi
	echo "${green} sgx agent pre-requisite package installation completed ${reset}"
}


install_pckretrieval_tool()
{
        \cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so $USR_LOCALBIN_DIR
        \cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so $USR_SBIN_DIR
	echo "${green} pckid retrieval tool installed ${reset}"
}

install_sgx_agent() {

	if [[ "$INKERNEL_SGX" -eq 1 ]]; then
		echo "inbuilt sgx driver not found, exiting sgx agent installation"
		exit 1
	else
		echo "found inbuilt sgx driver, proceeding with sgx agent installation"
	fi

	\cp -pf sgx_agent.env ~/sgx_agent.env

	source agent.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in agent.conf ${reset}"
		exit 1
	fi
	CMS_URL=https://$CMS_IP:$CMS_PORT/cms/v1
	SCS_URL=https://$SCS_IP:$SCS_PORT/scs/sgx
	sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/sgx_agent.env
	sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/sgx_agent.env
	sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/sgx_agent.env
	if [ -z $SHVS_IP ]; then
		sed -i "/SHVS_BASE_URL/d" ~/sgx_agent.env
	else
		SHVS_URL=https://$SHVS_IP:$SHVS_PORT/sgx-hvs/v2
		sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/sgx_agent.env
	fi
	LONG_LIVED_TOKEN=`./create_roles.sh`
	if [ $? -ne 0 ]; then
		echo "${red} sgx_agent token generation failed. exiting ${reset}"
		exit 1
	fi
	echo "${green} sgx agent roles created ${reset}"

	sed -i "s|BEARER_TOKEN=.*|BEARER_TOKEN=$LONG_LIVED_TOKEN|g" ~/sgx_agent.env

	echo "Installing SGX Agent...."
	$SGX_AGENT_BIN/sgx_agent-v*.bin
	sgx_agent status > /dev/null
	if [ $? -ne 0 ]; then
		echo "${red} SGX Agent Installation Failed ${reset}"
		exit 1
	fi
	echo "${green} SGX Agent Installation Successful ${reset}"
}

uninstall
install_prerequisites
install_pckretrieval_tool
install_sgx_agent
