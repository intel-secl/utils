#!/bin//bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "${red} unable to read config variables ${reset}" && exit 1
fi

if [ -z $TEE_SERVER_IP ]; then
	echo "${red} TEE_SERVER_IP value missing in ../../../config ${reset}" && exit 1
fi

install_prereqs()
{
        if [ "$OS" == "rhel" ]; then
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || exit 1
                $PKGMGR install -y msr-tools || exit 1
		$PKGMGR install -y yum-utils gcc-c++ git wget make kernel-devel kernel-headers dkms tar curl-devel || exit 1
        elif [ "$OS" == "ubuntu" ]; then
		$PKGMGR install -y git wget make dkms tar libcurl4-openssl-dev || exit 1
                $PKGMGR install -y msr-tools || exit 1
                sed -i "/msr/d" /etc/modules
                sed -i "$ a msr" /etc/modules
                modprobe msr || exit 1
	else
		echo "${red} Unknown OS ${reset}" && exit 1
        fi

}

check_sgx_flc_enabled()
{
        var=$(echo $(rdmsr -d 0x3A))
        echo "Rdmsr decimal output: " $var
        res_17=$(echo $((($var & (1 << 17)) != 0)))
        if [ "$res_17" == "1" ]; then
                echo "${green} SGX is enabled ${reset}"
        else
                echo "${red} SGX is not enabled ${reset}" && exit 1
        fi
        res_18=$(echo $((($var & (1 << 18)) != 0)))
        if [ "$res_18" == "1" ]; then
                echo "${green} FLC is enabled ${reset}"
        else
                echo "${red} FLC is not enabled ${reset}" && exit 1
        fi
}

check_dam_disabled()
{
	rdmsr -x 0x503
	if [ $? -ne 0 ]; then
		echo "${red} DAM is enabled ${reset}" && exit 1
	else
		echo "${green} DAM is not enabled. Hence proceeding further.... ${reset}"
	fi
}

check_cpu()
{
	dmesg | grep -I 'revision=0xa\|revision=0xb\|revision=0xc'
	preprod=$?
	dmesg | grep -I revision=0xd
	prod=$?
	if [ "$preprod" == "0" ]; then
		echo "${green} Host has Pre-Production CPU ${reset}"
	elif [ "$prod" == "0" ]; then
		echo "${green} Host has Production CPU ${reset}"
	else
		echo "${red} Host CPU is unknown ${reset}" && exit 1
	fi
}

uninstall()
{
        echo "uninstalling sgx psw/qgl and multi-package agent rpm"
        if [ "$OS" == "rhel" ]; then
                $PKGMGR remove -y libsgx-ra-uefi libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl libsgx-ae-pce libsgx-enclave-common libsgx-pce-logic libsgx-headers libsgx-dcap-quote-verify libsgx-dcap-quote-verify-devel sgx-pck-id-retrieval-tool || exit 1
        elif [ "$OS" == "ubuntu" ]; then
                $PKGMGR remove -y libsgx-ra-uefi libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-dev libsgx-dcap-default-qpl-dev libsgx-dcap-default-qpl
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
		else
                	echo "Skipping uninstallation of sgx dcap driver"
		fi
        else
                echo " $SGX_DRIVER_VERSION found inbuilt sgx driver, skipping dcap driver uninstallation"
        fi
}

install_sgxsdk()
{

	if [ "$OS" == "rhel" ]; then
        	wget -q $SGX_URL_TEE_UB/sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin || exit 1
	elif [ "$OS" == "ubuntu" ]; then
		wget -q $SGX_URL_TEE_UB/sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin || exit 1
	fi
        chmod u+x sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin
        ./sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin -prefix=$SGX_INSTALL_DIR || exit 1
        source $SGX_INSTALL_DIR/sgxsdk/environment
        if [ $? -ne 0 ]; then
                echo "${red} failed while setting sgx environment ${reset}"
                exit 1
        fi
        rm -rf sgx_linux_x64_sdk_$SGX_SDK_VERSION_TEE.bin
}

install_dcap_driver()
{
	wget -q $SGX_URL/sgx_linux_x64_driver_$SGX_DRIVER_VERSION.bin || exit 1
        chmod u+x sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
        if [[ "$INKERNEL_SGX" -eq 1 ]]; then
                if [[ "$DRIVER_VERSION" == ""  || "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]]; then
			echo "Installing sgx dcap driver...."
			./sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
			echo "${green} sgx dcap driver installed successfully ${reset}"
                elif [ "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]; then
                        echo "${red} incompatible sgx dcap driver loaded, uninstall the existing driver before proceeding ${reset}"
                        exit 1
                fi
        else
                echo "${green} found $SGX_DRIVER_VERSION inbuilt sgx driver, skipping dcap driver installation ${reset}"
        fi
	rm -rf sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
}

install_multipackage_agent_rpm()
{
        if [ "$OS" == "rhel" ]; then
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz
		wget -q $SGX_URL_TEE_UB/sgx_rpm_local_repo.tar.gz -O - | tar -xz || exit 1
                yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck libsgx-ra-uefi || exit 1
                
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
                rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz
        elif [ "$OS" == "ubuntu" ]; then
		wget -q https://download.01.org/intel-sgx/sgx-dcap/$DCAP_VERSION/linux/tools/SGXMultiPackageAgent/$OS_FLAVOUR-server/debian_pkgs/libs/libsgx-ra-uefi/libsgx-ra-uefi_1.12.100.3-focal1_amd64.deb || exit 1
			$PKGMGR install -y libsgx-ra-uefi
		rm -rf libsgx-ra-uefi*.deb

        fi
        echo "${green} sgx multipackage registration agent installed ${reset}"
}

install_psw_qgl()
{
        if [ "$OS" == "rhel" ]; then
		pushd $PWD
                cd /opt/intel/
                wget -q $SGX_URL_TEE_UB/libsgx_dcap_quoteverify.so.sbx || exit 1
                popd
		wget -q $SGX_URL_TEE_UB/libPCKCertSelection.so || exit 1
		\cp -pf libPCKCertSelection.so /usr/lib64/libPCKCertSelection.so
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz
		wget -q $SGX_URL_TEE_UB/sgx_rpm_local_repo.tar.gz || exit 1
                tar -xf sgx_rpm_local_repo.tar.gz || exit 1
                yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
                $PKGMGR install -qy --nogpgcheck libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl libsgx-ae-pce libsgx-enclave-common libsgx-pce-logic libsgx-headers libsgx-dcap-quote-verify libsgx-dcap-quote-verify-devel || exit 1
                rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
        elif [ "$OS" == "ubuntu" ]; then
                echo $SGX_LIBS_REPO | sudo tee /etc/apt/sources.list.d/intel-sgx.list
                wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
                $PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-launch libsgx-uae-service libsgx-urts || exit 1
                $PKGMGR install -y libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-dev libsgx-dcap-default-qpl-dev libsgx-dcap-default-qpl || exit 1

        fi
        echo "${green} sgx psw and qgl libraries installed ${reset}"
}

install_pckretrieval_tool()
{
        if [ "$OS" == "rhel" ]; then
		rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz
		wget -q $SGX_URL_TEE_UB/sgx_rpm_local_repo.tar.gz || exit 1
                tar -xf sgx_rpm_local_repo.tar.gz || exit 1
                yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck sgx-pck-id-retrieval-tool  || exit 1
		cp /opt/intel/sgx-pck-id-retrieval-tool/PCKIDRetrievalTool /usr/bin/
		cp /opt/intel/sgx-pck-id-retrieval-tool/libsgx_id_enclave.signed.so /usr/bin/
		cp /opt/intel/sgx-pck-id-retrieval-tool/libsgx_pce.signed.so /usr/bin/
                rm -rf sgx_rpm_local_repo sgx_rpm_local_repo.tar.gz /etc/yum.repos.d/*sgx_rpm_local_repo.repo
        elif [ "$OS" == "ubuntu" ]; then
		rm -rf $GIT_CLONE_PATH
		pushd $PWD
		git clone $SGX_DCAP_REPO $GIT_CLONE_PATH || exit 1
		cp -pf remove_pccs_connect.diff $GIT_CLONE_PATH/tools/PCKRetrievalTool
		cd $GIT_CLONE_PATH/
		git checkout $SGX_DCAP_TAG
		cd $GIT_CLONE_PATH/tools/PCKRetrievalTool
		git apply remove_pccs_connect.diff
		make || exit 1
		\cp -pf libdcap_quoteprov.so.1 pck_id_retrieval_tool_enclave.signed.so $USR_BIN_DIR
		\cp -pf PCKIDRetrievalTool $USR_BIN_DIR
		rm -rf $GIT_CLONE_PATH
        	popd
	fi

        echo "${green} pckid retrieval tool installed ${reset}"
	PCKIDRetrievalTool | grep -Iw "pckid_retrieval.csv has been generated successfully!"
	if [ $? -ne 0 ]; then
                echo "${red} Factory Reset is required ${reset}"
                exit 1
        else
		echo "${green} pckid retrieval tool is running successfully ${reset}"
		rm -rf pckid_retrieval.csv
	fi
}

install_prereqs
check_sgx_flc_enabled
check_dam_disabled
check_cpu
uninstall
install_sgxsdk
install_dcap_driver
install_psw_qgl
install_multipackage_agent_rpm
install_pckretrieval_tool
