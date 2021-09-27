#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

uninstall()
{
	echo "uninstalling sgx psw/qgl and multi-package agent rpm"
	if [ "$OS" == "rhel" ]; then
		$PKGMGR remove -y libsgx-dcap-ql libsgx-ra-uefi
	elif [ "$OS" == "ubuntu" ]; then
		$PKGMGR remove -y libsgx-dcap-ql libsgx-ra-uefi
	fi
	echo "uninstalling PCKIDRetrieval Tool"
	rm -rf $USR_BIN_DIR/libdcap_quoteprov.so.1 $USR_BIN_DIR/pck_id_retrieval_tool_enclave.signed.so $USR_BIN_DIR/PCKIDRetrievalTool
	
	if [[ "$INKERNEL_SGX" -eq 1 ]]; then
		if [[ "$DRIVER_LOADED" -ne 0 ]]; then
			echo "SGX DCAP driver not installed"
		elif [ "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]; then
			echo "uninstalling sgx dcap driver"
			systemctl stop aesmd
			sh $SGX_INSTALL_DIR/sgxdriver/uninstall.sh
			if [[ $? -ne 0 ]]; then
				echo "${red} sgx dcap driver uninstallation failed. exiting ${reset}"
				exit 1
			fi
			systemctl start aesmd
		fi
	else
                echo "found inbuilt sgx driver, skipping dcap driver uninstallation"
        fi

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

install_dcap_driver()
{
	chmod u+x $SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	if [[ "$INKERNEL_SGX" -eq 1 ]]; then
                if [[ "$DRIVER_VERSION" == ""  || "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]]; then
                        echo "Installing sgx dcap driver...."
                        ./$SGX_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
                        echo "${green} sgx dcap driver installed successfully ${reset}"
		elif [ "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]; then
			echo "${red} incompatible sgx dcap driver loaded, uninstall the existing driver before proceeding ${reset}"
			exit 1
                fi
        else
                echo "found inbuilt sgx driver, skipping dcap driver installation"
        fi
}

install_psw_qgl()
{
	if [ "$OS" == "rhel" ]; then
		tar -xf $SGX_AGENT_BIN/sgx_rpm_local_repo.tgz
		yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck libsgx-dcap-ql || exit 1
		rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	elif [ "$OS" == "ubuntu" ]; then
                echo $SGX_LIBS_REPO | sudo tee /etc/apt/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
		$PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-dcap-ql || exit 1
	fi
	echo "${green} sgx psw and qgl installed ${reset}"
}
	
install_multipackage_agent_rpm()
{
	if [ "$OS" == "rhel" ]; then
		rpm -ivh $SGX_AGENT_BIN/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm || exit 1
	elif [ "$OS" == "ubuntu" ]; then
		$PKGMGR install -y libsgx-ra-uefi || exit 1
	fi
	echo "${green} sgx multipackage registration agent installed ${reset}"
}

install_pckretrieval_tool()
{
	\cp -pf $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so $USR_BIN_DIR
	\cp -pf $SGX_AGENT_BIN/PCKIDRetrievalTool $USR_BIN_DIR
	echo "${green} pckid retrieval tool installed ${reset}"
}

install_sgx_agent() { 
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
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
install_sgx_agent
