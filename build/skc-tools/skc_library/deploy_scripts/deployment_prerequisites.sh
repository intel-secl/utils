#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" || "$VER" == "8.4" ]]; then
		echo "installing libgda and softhsm"
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || exit 1
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/fedora/linux/releases/33/Everything/x86_64/os/Packages/s/softhsm-2.6.1-3.fc33.4.x86_64.rpm || exit 1
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/fedora/linux/releases/33/Everything/x86_64/os/Packages/l/libgda-5.2.9-6.fc33.x86_64.rpm || exit 1
		$PKGMGR install -qy https://dl.fedoraproject.org/pub/fedora/linux/releases/33/Everything/x86_64/os/Packages/l/libgda-sqlite-5.2.9-6.fc33.x86_64.rpm || exit 1
		echo "installing devel packages"
		$PKGMGR install -qy yum-utils tar wget gcc-c++ kernel-devel kernel-headers dkms make jq protobuf jsoncpp jsoncpp-devel || exit 1
		\cp -rpf bin/pkcs11.so $LIB_DIR/engines-1.1/
		ln -sf $LIB_DIR/engines-1.1/pkcs11.so $LIB_DIR/engines-1.1/libpkcs11.so
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
		$PKGMGR install -y build-essential ocaml automake autoconf libtool tar wget python libssl-dev || exit 1
		$PKGMGR-get install -y libcurl4-openssl-dev libprotobuf-dev curl || exit 1
		$PKGMGR install -y dkms make jq libjsoncpp1 libjsoncpp-dev softhsm libgda-5.0-4 || exit 1
		\cp -rpf bin/pkcs11.so /usr/lib/x86_64-linux-gnu/engines-1.1/
		ln -sf $LIB_DIR/x86_64-linux-gnu/engines-1.1/pkcs11.so $LIB_DIR/x86_64-linux-gnu/engines-1.1/libpkcs11.so
	else
		echo "${red} Unsupported OS. Please use RHEL 8.1/8.2/8.4 or Ubuntu 18.04/20.04 ${reset}"
		exit 1
	fi
	\cp -rpf bin/libp11.so.3.4.3 $LIB_DIR
	ln -sf $LIB_DIR/libp11.so.3.4.3 $LIB_DIR/libp11.so
	ln -sf $LIB_DIR/libjsoncpp.so $LIB_DIR/libjsoncpp.so.0
}

install_pre_requisites
