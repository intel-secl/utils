#!/bin/bash
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

source skc_library.conf
if [ $? -ne 0 ]; then
	echo " ${red} please set correct values in skc_library.conf ${reset}"
	exit 1
fi

SKCLIB_INST_PATH=/opt/skc
KMS_NPM_PATH=$SKCLIB_INST_PATH/etc/kms_npm.ini
CREDENTIAL_PATH=$SKCLIB_INST_PATH/etc/credential_agent.ini
CURL_OPTS="-s -k"
SGX_DEFAULT_PATH=/etc/sgx_default_qcnl.conf

update_credential_ini()
{
	sed -i "s|server=.*|server=https:\/\/$KBS_HOSTNAME:${KBS_PORT:-9443}/kbs|g" $KMS_NPM_PATH
	sed -i "s|request_params=.*|request_params=\"\/CN=$SKC_USER\"|g" $CREDENTIAL_PATH
	sed -i "s|server=.*|server=$CMS_IP|g" $CREDENTIAL_PATH
	sed -i "s|port=.*|port=${CMS_PORT:-8445}|g" $CREDENTIAL_PATH
	sed -i "s|^token=.*|token=\"$SKC_TOKEN\"|g" $CREDENTIAL_PATH
	curl $CURL_OPTS -H 'Accept:application/x-pem-file' https://$CMS_IP:${CMS_PORT:-8445}/cms/v1/ca-certificates > $SKCLIB_INST_PATH/store/cms-ca.cert || exit 1
	if [ $? -ne 0 ]; then
		echo "${red} could not get Certificate Management Service Root CA Certificate ${reset}"
		exit 1
	fi
}

run_credential_agent()
{
	$SKCLIB_INST_PATH/bin/credential_agent_init
	if [ $? -ne 0 ]; then
		echo "${red} failed to obtain TLS client certificate from cms ${reset}"
		exit 1
	fi
	echo "${green} obtained TLS client certificate from cms ${reset}"
}

update_dcap_qcnl_conf()
{
	sed -i "s|PCCS_URL=.*|PCCS_URL=https:\/\/$CSP_SCS_IP:${CSP_SCS_PORT:-9000}/scs/sgx/certification/v1/|g" $SGX_DEFAULT_PATH
}

update_kbshostname_in_conf_file()
{
	grep -q "^$KBS_IP" /etc/hosts && sed -i "s/^$KBS_IP.*//" /etc/hosts && sed  -i '/^$/d' /etc/hosts
	sed -i "1i $KBS_IP $KBS_HOSTNAME" /etc/hosts
}

update_credential_ini
run_credential_agent
update_dcap_qcnl_conf
update_kbshostname_in_conf_file
