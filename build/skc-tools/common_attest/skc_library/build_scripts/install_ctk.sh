#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

SKCLIB_DIR=$PWD/skc_library

install_cryptoapitoolkit()
{
	pushd $PWD
	mkdir -p $GIT_CLONE_PATH
        rm -rf $GIT_CLONE_SGX_CTK
        git clone $CTK_REPO $GIT_CLONE_SGX_CTK || exit 1
        cd $GIT_CLONE_SGX_CTK
	sed -i "s/#define NONCE_LENGTH 32/#define NONCE_LENGTH 128/g" $GIT_CLONE_SGX_CTK/src/p11/trusted/SoftHSMv2/common/QuoteGenerationDefs.h
        bash autogen.sh || exit 1
        ./configure --with-p11-kit-path=$P11_KIT_PATH --prefix=$CTK_INSTALL --enable-dcap --disable-ephemeral-quote --disable-multiprocess-support || exit 1
	make install || exit 1
	popd
	\cp -rpf $CTK_INSTALL $SKCLIB_DIR
	\cp -rpf $SGXSSL_PREFIX $SKCLIB_DIR
}

check_prerequisites()
{
        if [ ! -f /opt/intel/sgxsdk/bin/x64/sgx_edger8r ];then
                echo "${red} sgx sdk is required for building cryptokit ${reset}"
                exit 1
        fi

	if [ "$OS" == "rhel" ]; then
                rpm -q p11-kit-devel | grep $P11KIT_DEV_VERSION
                if [ $? -ne 0 ]; then
                        echo "${red} p11-kit-devel-$P11KIT_DEV_VERSION is required for building cryptokit ${reset}"
                        exit 1
                fi
        fi
}

check_prerequisites
install_cryptoapitoolkit
