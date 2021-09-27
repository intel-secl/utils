#!/bin//bash
source ../../../../../build/skc-tools/config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
		$PKGMGR install -qy wget tar git gcc-c++ make curl-devel skopeo || exit 1
		$PKGMGR install -qy https://download-ib01.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/m/makeself-2.4.2-1.el8.noarch.rpm || exit 1
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
		$PKGMGR install -y wget tar build-essential libcurl4-openssl-dev makeself || exit 1
	else
		echo "Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04/20.04"
		exit 1
	fi
}

install_pre_requisites
