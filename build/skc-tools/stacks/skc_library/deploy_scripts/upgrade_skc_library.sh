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

        $PKGMGR remove -y libsgx-uae-service libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel || exit 1
}


install_psw_qgl()
{
	if [ "$OS" == "rhel" ]; then
		$PKGMGR install -qy --nogpgcheck libsgx-uae-service libsgx-dcap-ql-devel libsgx-dcap-default-qpl-devel || exit 1
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
