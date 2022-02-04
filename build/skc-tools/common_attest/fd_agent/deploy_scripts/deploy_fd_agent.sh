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

	echo "Uninstalling existing Feature Discovery Agent Installation...."
	fda uninstall --purge
}

install_prerequisites()
{
	source deployment_prerequisites.sh
	if [[ $? -ne 0 ]]; then
		echo "${red} fd agent pre-requisite package installation failed. exiting ${reset}"
		exit 1
	fi
	echo "${green} fd agent pre-requisite package installation completed ${reset}"
}

install_dcap_driver()
{
	chmod u+x $FD_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
	if [[ "$INKERNEL_SGX" -eq 1 ]]; then
                if [[ "$DRIVER_VERSION" == ""  || "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]]; then
                        echo "Installing sgx dcap driver...."
                        ./$FD_AGENT_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
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
		tar -xf $FD_AGENT_BIN/sgx_rpm_local_repo.tgz || exit 1
		yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck libsgx-dcap-ql || exit 1
                $PKGMGR install -qy --nogpgcheck libsgx-dcap-ql-devel || exit 1
		rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	elif [ "$OS" == "ubuntu" ]; then
                echo $SGX_LIBS_REPO | sudo tee /etc/apt/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
		$PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-dcap-ql || exit 1
                $PKGMGR install -qy --nogpgcheck libsgx-dcap-ql-devel || exit 1
	fi
	echo "${green} sgx psw and qgl installed ${reset}"
}
	
install_multipackage_agent_rpm()
{
	if [ "$OS" == "rhel" ]; then
		rpm -ivh $FD_AGENT_BIN/libsgx-ra-uefi-$MP_RPM_VER.el8.x86_64.rpm || exit 1
	elif [ "$OS" == "ubuntu" ]; then
		$PKGMGR install -y libsgx-ra-uefi || exit 1
	fi
	echo "${green} sgx multipackage registration agent installed ${reset}"
}

install_pckretrieval_tool()
{
	\cp -pf $FD_AGENT_BIN/libdcap_quoteprov.so.1 $FD_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so $USR_BIN_DIR
	\cp -pf $FD_AGENT_BIN/PCKIDRetrievalTool $USR_BIN_DIR
	echo "${green} pckid retrieval tool installed ${reset}"
}

install_fd_agent() { 
	\cp -pf fda.env ~/fda.env

	source fdagent.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in fdagent.conf ${reset}"
		exit 1
	fi
	CMS_URL=https://$CMS_IP:$CMS_PORT/cms/v1
	TCS_URL=https://$TCS_IP:$TCS_PORT/tcs/v4/sgx/
	sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/fda.env
	sed -i "s@^\(TCS_BASE_URL\s*=\s*\).*\$@\1$TCS_URL@" ~/fda.env
	sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/fda.env

	if [ -z $FDS_IP ]; then
		sed -i "/FDS_BASE_URL/d" ~/fda.env
	else
		FDS_URL=https://$FDS_IP:$FDS_PORT/fds/v1
		sed -i "s@^\(FDS_BASE_URL\s*=\s*\).*\$@\1$FDS_URL@" ~/fda.env
	fi
	
	./create_roles.sh && LONG_LIVED_TOKEN=`cat tcs-custom-claim-response.json`

	if [ $? -ne 0 ]; then
		echo "${red} fd_agent token generation failed. exiting ${reset}"
		exit 1
	fi
	echo "${green} fd agent roles created ${reset}"

	sed -i "s|CUSTOM_TOKEN=.*|CUSTOM_TOKEN=$LONG_LIVED_TOKEN|g" ~/fda.env

	echo "Installing Feature Discovery Agent...."
	$FD_AGENT_BIN/fda-v*.bin
	fda status > /dev/null
	if [ $? -ne 0 ]; then
		echo "${red} Feature Discovery Agent Installation Failed ${reset}"
		exit 1
	fi
	echo "${green} Feature Discovery Agent Installation Successful ${reset}"
}

uninstall
install_prerequisites
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
install_fd_agent
