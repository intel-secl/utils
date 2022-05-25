#!/bin/sh

DCAP_RELEASE=2.13.91.2
INSTALL_DIR=/opt/intel
SGX_RPM_REPO_URL=http://10.105.168.247/intel-sgx/sgx-dcap/1.10.9.1/linux/distro/rhel8.4-server

download_sandbox_qvl() {
    wget -qO ${INSTALL_DIR}/libsgx_dcap_quoteverify.so.sbx ${SGX_RPM_REPO_URL}/libsgx_dcap_quoteverify.so.sbx
}

download_pckcertselection_library() {
    wget -qO /usr/lib64/libPCKCertSelection.so ${SGX_RPM_REPO_URL}/libPCKCertSelection.so
}

download_and_install_sgxsdk() {
    wget -q ${SGX_RPM_REPO_URL}/sgx_linux_x64_sdk_${DCAP_RELEASE}.bin
    chmod u+x sgx_linux_x64_sdk_${DCAP_RELEASE}.bin
    ./sgx_linux_x64_sdk_${DCAP_RELEASE}.bin -prefix=${INSTALL_DIR}
    if [ $? != 0 ]; then
        echo "Failed to install sgxsdk"
        return 1
    fi	
    source ${INSTALL_DIR}/sgxsdk/environment
}

download_and_configure_local_repo() {
    wget -q ${SGX_RPM_REPO_URL}/sgx_rpm_local_repo.tar.gz
    tar -xzvf sgx_rpm_local_repo.tar.gz >/dev/null
    if [ $? != 0 ]; then
        echo "Failed to untar sgx_rpm_local_repo.tar.gz"
        return 1
    fi
    yum -y install yum-utils
    if [ $? != 0 ]; then
        echo "Failed to install yum-utils"
        return 1
    fi
    yum-config-manager --add-repo file://$(pwd)/sgx_rpm_local_repo/
}

install_dcap_packages() {
    yum install -y --setopt=install_weak_deps=False --nogpgcheck libtdx-attest-devel libsgx-dcap-ql-devel libsgx-dcap-quote-verify-devel libsgx-dcap-default-qpl
    if [ $? != 0 ]; then
        echo "Failed to install dcap packages"
        return 1
    fi
}

main() {
    download_sandbox_qvl
    download_pckcertselection_library
    download_and_install_sgxsdk
    if [ $? != 0 ]; then
        echo "Failed to install SGX SDK. Exiting..."
        exit 1
    fi

    download_and_configure_local_repo
    if [ $? != 0 ]; then
        echo "Failed to configure SGX RPM local repo. Exiting..."
        exit 1
    fi

    install_dcap_packages
    if [ $? != 0 ]; then
        echo "Failed to install DCAP packages. Exiting..."
        exit 1
    fi
}

export no_proxy=$no_proxy,10.105.168.247
main
