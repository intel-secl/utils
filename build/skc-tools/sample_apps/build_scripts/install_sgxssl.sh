#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

install_sgxssl()
{
        pushd $PWD

        rm -rf $GIT_CLONE_SGXSSL
        mkdir -p $GIT_CLONE_SGXSSL

        git clone $SGX_SSL_REPO $GIT_CLONE_SGXSSL || exit 1

        cd $GIT_CLONE_SGXSSL/openssl_source/
        wget -nv https://ftp.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz || exit 1

        cd $GIT_CLONE_SGXSSL/Linux
        make sgxssl_no_mitigation
        if [[ "$OS" == "rhel" &&  "$VER" == "8.2" || "$VER" == "8.4" ]]; then
                make install || exit 1
        elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
                sudo make install
        else
                echo "Unsupported OS. Please use RHEL 8.2/8.4 or Ubuntu 18.04/20.04"
                exit 1
        fi
        popd

        \cp -rpf $SGXSSL_PREFIX $SAMPLEAPPS_DIR
}

check_prerequisites()
{
        if [ ! -f /opt/intel/sgxsdk/bin/x64/sgx_edger8r ];then
                echo "sgx sdk is required for building sgxssl."
                exit 1
        fi
}

check_prerequisites
install_sgxssl
