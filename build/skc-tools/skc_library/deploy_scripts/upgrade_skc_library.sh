#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

SKCLIB_INSTALL_DIR=/opt/skc
SKCLIB_DEVOPS_DIR=$SKCLIB_INSTALL_DIR/devops
SKC_DEVOPS_SCRIPTS_PATH=$SKCLIB_DEVOPS_DIR/scripts

uninstall_skc()
{
	if [[ -d $SGX_INSTALL_DIR/cryptoapitoolkit ]]; then
		echo "Uninstalling cryptoapitoolkit"
		rm -rf $SGX_INSTALL_DIR/cryptoapitoolkit
	fi

	if [[ -d $SGX_INSTALL_DIR/sgxssl ]]; then
		echo "uninstalling sgxssl"
		rm -rf $SGX_INSTALL_DIR/sgxssl
	fi

	echo "uninstalling sgx psw/qgl"
        if [ "$OS" == "rhel" ]; then
                $PKGMGR remove -y libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl
        elif [ "$OS" == "ubuntu" ]; then
                $PKGMGR remove -y libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-dev libsgx-dcap-default-qpl-dev libsgx-dcap-default-qpl
        fi

        if [[ "$INKERNEL_SGX" -eq 1 ]]; then
                if [[ "$DRIVER_LOADED" -ne 0 ]]; then
                        echo "SGX DCAP driver not installed"
                elif [ "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]; then
                        echo "uninstalling sgx dcap driver"
                        sh $SGX_INSTALL_DIR/sgxdriver/uninstall.sh
                        if [[ $? -ne 0 ]]; then
                                echo "${red} sgx dcap driver uninstallation failed. exiting ${reset}"
                                exit 1
                        fi
                fi
        else
                echo "found inbuilt sgx driver, skipping dcap driver uninstallation"
        fi
}

install_dcap_driver()
{
        chmod u+x $SKCLIB_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin
        if [[ "$INKERNEL_SGX" -eq 1 ]]; then
                if [[ "$DRIVER_VERSION" == ""  || "$DRIVER_VERSION" != "$SGX_DRIVER_VERSION" ]]; then
                        echo "Installing sgx dcap driver...."
                        ./$SKCLIB_BIN/sgx_linux_x64_driver_${SGX_DRIVER_VERSION}.bin -prefix=$SGX_INSTALL_DIR || exit 1
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
		tar -xf $SKCLIB_BIN/sgx_rpm_local_repo.tgz || exit 1
		yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo || exit 1
		$PKGMGR install -qy --nogpgcheck libsgx-launch libsgx-uae-service libsgx-urts libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel libsgx-dcap-default-qpl || exit 1
		rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo
	elif [ "$OS" == "ubuntu" ]; then
                echo $SGX_LIBS_REPO | sudo tee /etc/$PKGMGR/sources.list.d/intel-sgx.list
		wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo $PKGMGR-key add - || exit 1
		$PKGMGR update -y || exit 1
		$PKGMGR install -y libsgx-launch libsgx-uae-service libsgx-urts || exit 1
		$PKGMGR install -y libsgx-ae-qve libsgx-dcap-ql libsgx-dcap-ql-dev libsgx-dcap-default-qpl-dev libsgx-dcap-default-qpl || exit 1
	fi
}

install_sgxssl()
{
        \cp -prf sgxssl $SGX_INSTALL_DIR
	echo "${green} sgxssl installed ${reset}"
}

install_cryptoapitoolkit()
{
	\cp -prf cryptoapitoolkit $SGX_INSTALL_DIR
	echo "${green} crypto api toolkit installed ${reset}"
}

exit_on_error()
{
	if [ $? != 0 ]; then
		echo "$1"
		exit 1
	fi
}

install_skc_library_bin()
{
	$SKCLIB_BIN/skc_library_v*.bin
	exit_on_error "${red} skc_library installation failed ${reset}"
	echo "${green} skc_library modules installed ${reset}"
}

BACKUP_DIR=/tmp/skc_library_backup/
SGX_CONFIG=/etc/sgx_default_qcnl.conf

echo "Starting with the SKC library upgrade"

echo "Creating backup directory $BACKUP_DIR"
mkdir -p $BACKUP_DIR
exit_on_error "Failed to create backup directory"

echo "Creating config backup directory $BACKUP_DIR/config"
mkdir -p $BACKUP_DIR/config
exit_on_error "Failed to create config backup directory"

echo "Backing up SKC library to $BACKUP_DIR"
\cp -a $SKCLIB_INSTALL_DIR/* $BACKUP_DIR
exit_on_error "Failed to backup skc library"

echo "Backing up SKC library config to $BACKUP_DIR/config"
\cp -a $SGX_CONFIG $BACKUP_DIR/config/ 
exit_on_error "Failed to backup skc library config"

uninstall_skc
exit_on_error "Failed to uninstall existing SKC library"

install_dcap_driver
exit_on_error "Failed to install dcap library"

install_psw_qgl
exit_on_error "Failed to install psw qgl"

install_sgxssl
exit_on_error "Failed to install sgx ssl"

install_cryptoapitoolkit
exit_on_error "Failed to install crypto API toolkit"

install_skc_library_bin
exit_on_error "Failed to install SKC library"

echo "Restoring config"

echo "Restoring $SKCLIB_INSTALL_DIR/etc"
mkdir -p $SKCLIB_INSTALL_DIR/etc/
\cp -arf $BACKUP_DIR/etc/* $SKCLIB_INSTALL_DIR/etc/
exit_on_error "Failed to restore $SKCLIB_INSTALL_DIR/etc/"

echo "Restoring $SKCLIB_INSTALL_DIR/store"
mkdir -p $SKCLIB_INSTALL_DIR/store/
\cp -arf $BACKUP_DIR/store/* $SKCLIB_INSTALL_DIR/store/
exit_on_error "Failed to restore $SKCLIB_INSTALL_DIR/store/"

echo "Restoring $SKCLIB_INSTALL_DIR/tmp"
mkdir -p $SKCLIB_INSTALL_DIR/tmp/
\cp -arf $BACKUP_DIR/tmp/* $SKCLIB_INSTALL_DIR/tmp/
exit_on_error "Failed to restore $SKCLIB_INSTALL_DIR/tmp/"

echo "Restoring $SGX_CONFIG"
\cp -a $BACKUP_DIR/config/sgx_default_qcnl.conf $SGX_CONFIG
exit_on_error "Failed to restore $SGX_CONFIG"

echo "Completed SKC library upgrade"
