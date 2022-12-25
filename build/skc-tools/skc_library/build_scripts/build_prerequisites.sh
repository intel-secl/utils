#!/bin//bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "ubuntu" && "$VER" == "20.04" ]]; then
		$PKGMGR install -y build-essential ocaml ocamlbuild automake autoconf libtool cmake perl libcppunit-dev libssl-dev || exit 1
		wget http://archive.ubuntu.com/ubuntu/pool/main/libt/libtasn1-6/libtasn1-6_4.16.0-2_amd64.deb || exit 1
		wget http://archive.ubuntu.com/ubuntu/pool/main/libf/libffi/libffi8_3.4.2-4_amd64.deb || exit 1
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit0_0.23.20-1ubuntu0.1_amd64.deb || exit 1
		wget http://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit-dev_0.23.20-1ubuntu0.1_amd64.deb || exit 1
		$PKGMGR install -f -y ./libtasn1-6_4.16.0-2_amd64.deb || exit 1
		$PKGMGR install -f -y ./libffi8_3.4.2-4_amd64.deb || exit 1
		$PKGMGR install -f -y ./libp11-kit0_0.23.20-1ubuntu0.1_amd64.deb  || exit 1
		$PKGMGR install -f -y ./libp11-kit-dev_0.23.20-1ubuntu0.1_amd64.deb || exit 1
		rm -rf *.deb
	else
		echo "${red} Unsupported OS. Please use Ubuntu 20.04 ${reset}"
		exit 1
	fi
}

install_pre_requisites
