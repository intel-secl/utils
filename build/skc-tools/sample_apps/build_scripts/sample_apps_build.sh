#!/bin/bash
source ../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SAMPLEAPPS_DIR)

install_prerequisites()
{
	source build_prerequisites.sh	
	if [ $? -ne 0 ]; then
		"Pre-build step failed"
		exit 1
	fi
}

create_sample_apps_tar()
{
	\cp -pf install_sgxsdk.sh $SAMPLEAPPS_DIR
	\cp -pf ../deploy_scripts/README.install $SAMPLEAPPS_DIR
	\cp -pf ../deploy_scripts/*.conf $SAMPLEAPPS_DIR
	\cp -pf ../deploy_scripts/*.sh $SAMPLEAPPS_DIR
	sed -i 's+../../config+config+g' $SAMPLEAPPS_DIR/install_sgxsdk.sh
	\cp -pf ../../config $SAMPLEAPPS_DIR
        \cp -rpf ../../../../../utils/tools/sample-sgx-attestation/out/ $SAMPLEAPPS_DIR
        rm -f $SAMPLEAPPS_DIR/out/rootca.pem
	tar -cf $TAR_NAME.tar -C $SAMPLEAPPS_DIR . --remove-files || exit 1
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
        chmod 755 $TAR_NAME.sha2
	echo "sample_apps.tar file and sample_apps.sha2 checksum file created"
}

install_sgxsdk()
{
	source install_sgxsdk.sh
	if [ $? -ne 0 ]; then
		echo "sgx sdk installation failed"
		exit 1
	fi
}

install_sgxrpm()
{
	source install_sgxrpms.sh
	if [ $? -ne 0 ]; then
		echo "sgx psw/qgl rpm installation failed"
		exit 1
	fi
}
	
install_sgxssl()
{
	source install_sgxssl.sh
	if [ $? -ne 0 ]; then
		echo "sgxssl installation failed"
		exit 1
	fi
}

build_sample_apps()
{
	source build_sampleapps.sh
	if [ $? -ne 0 ]; then
		echo "sample apps build failed"
		exit 1
	fi
}

rm -rf $SAMPLEAPPS_DIR

if [ "$OS" == "rhel" ]; then
	rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

install_prerequisites
install_sgxsdk
install_sgxrpm
install_sgxssl
build_sample_apps
create_sample_apps_tar
