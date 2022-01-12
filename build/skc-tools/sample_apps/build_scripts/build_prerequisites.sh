#!/bin//bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_pre_requisites()
{
	if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" || "$VER" == "8.4" ]]; then
		$PKGMGR install -qy bc wget tar git gcc-c++ make automake autoconf libtool yum-utils openssl-devel || exit 1
	elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
		$PKGMGR install -y build-essential ocaml ocamlbuild automake autoconf libtool cmake perl libssl-dev || exit 1
                wget http://archive.ubuntu.com/ubuntu/pool/main/libt/libtasn1-6/libtasn1-6_4.16.0-2_amd64.deb || exit 1
                wget http://archive.ubuntu.com/ubuntu/pool/main/libf/libffi/libffi8ubuntu1_3.4~20200819gead65ca871-0ubuntu5_amd64.deb || exit 1

                $PKGMGR install -f -y ./libtasn1-6_4.16.0-2_amd64.deb || exit 1
                $PKGMGR install -f -y ./libffi8ubuntu1_3.4~20200819gead65ca871-0ubuntu5_amd64.deb || exit 1

		rm -rf *.deb
	else
		echo "Unsupported OS. Please use RHEL 8.1/8.2/8.4 or Ubuntu 18.04/20.04"
		exit 1
	fi
}

install_pre_requisites
