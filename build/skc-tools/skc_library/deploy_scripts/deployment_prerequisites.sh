#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "ubuntu" && "$VER" == "20.04" ]]; then
		$PKGMGR install -y build-essential ocaml automake autoconf libtool tar wget python libssl-dev || exit 1
		$PKGMGR-get install -y libcurl4-openssl-dev libprotobuf-dev curl || exit 1
		$PKGMGR install -y dkms make jq libjsoncpp1 libjsoncpp-dev softhsm libgda-5.0-4 || exit 1
		\cp -rpf bin/pkcs11.so /usr/lib/x86_64-linux-gnu/engines-1.1/
		ln -sf $LIB_DIR/x86_64-linux-gnu/engines-1.1/pkcs11.so $LIB_DIR/x86_64-linux-gnu/engines-1.1/libpkcs11.so
	else
		echo "${red} Unsupported OS. Please use Ubuntu 20.04 ${reset}"
		exit 1
	fi
	\cp -rpf bin/libp11.so.3.5.0 $LIB_DIR
	ln -sf $LIB_DIR/libp11.so.3.5.0 $LIB_DIR/libp11.so
	ln -sf $LIB_DIR/libjsoncpp.so $LIB_DIR/libjsoncpp.so.0
}

install_pre_requisites
