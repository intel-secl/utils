#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" || "$VER" == "8.4" ]]; then
		echo "installing devel packages"
		$PKGMGR install -qy yum-utils tar wget gcc-c++ make protobuf || exit 1
		if [[ "$VER" == "8.4" ]]; then
			$PKGMGR install -y linux-sgx-sdk || exit 1
		fi
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
		$PKGMGR install -y build-essential ocaml automake autoconf libtool tar wget python libssl-dev || exit 1
		$PKGMGR-get install -y libcurl4-openssl-dev libprotobuf-dev curl || exit 1
		$PKGMGR install -y make || exit 1
	else
		echo "${red} Unsupported OS. Please use RHEL 8.1/8.2/8.4 or Ubuntu 18.04/20.04 ${reset}"
		exit 1
	fi
}

install_pre_requisites
