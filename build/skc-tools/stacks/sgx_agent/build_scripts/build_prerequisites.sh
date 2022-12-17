#!/bin//bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.4" ]]; then
		$PKGMGR install -qy wget tar git gcc-c++ make curl-devel || exit 1
		$PKGMGR install -qy https://download-ib01.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/m/makeself-2.4.2-1.el8.noarch.rpm || exit 1
	else
		echo "Unsupported OS. Please use RHEL 8.4"
		exit 1
	fi
}

install_pre_requisites
