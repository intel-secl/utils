#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || exit 1
		$PKGMGR install -qy yum-utils kernel-devel dkms tar make jq || exit 1
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
		$PKGMGR install -y dkms tar make jq curl || exit 1
		sed -i "/msr/d" /etc/modules
		sed -i "$ a msr" /etc/modules
		modprobe msr || exit 1
	else
		echo "${red} Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04/20.04 ${reset}"
		exit 1
	fi
}

install_pre_requisites
