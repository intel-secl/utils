#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

SAMPLEAPPS_BIN=bin

uninstall()
{
	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "uninstalling sgxssl"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	echo "uninstalling sgx psw/qgl"
	$PKGMGR remove -y libsgx-uae-service libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel
}

install_prerequisites()
{
	source deployment_prerequisites.sh 
	if [[ $? -ne 0 ]]; then
		echo "${red} pre requisites installation failed ${reset}"
		exit 1
	fi
}

install_psw_qgl()
{
	$PKGMGR install -qy --nogpgcheck libsgx-uae-service libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel || exit 1
	echo "${green} sgx psw and qgl libraries installed ${reset}"
	sed -i "s|PCCS_URL=.*|PCCS_URL=https://<csp-scs-ip>:<scs-port>/scs/sgx/certification/v1/|g" /etc/sgx_default_qcnl.conf
	sed -i "s|.*USE_SECURE_CERT=.*|USE_SECURE_CERT=FALSE|g" /etc/sgx_default_qcnl.conf
}

install_sgxssl()
{
        \cp -prf sgxssl $SGX_INSTALL_DIR
	echo "${green} sgxssl installed ${reset}"
}

uninstall
install_prerequisites
install_psw_qgl
install_sgxssl
