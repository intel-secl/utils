#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

TAR_NAME=$(basename $SAMPLEAPPS_DIR)

install_prerequisites()
{
	pushd $PWD
	cd ../../../sample_apps/build_scripts
	source build_prerequisites.sh	
	if [ $? -ne 0 ]; then
		"Pre-build step failed"
		exit 1
	fi
	popd
}

create_sample_apps_tar()
{
	\cp -pf ../../../sample_apps/deploy_scripts/README.install $SAMPLEAPPS_DIR
	\cp -pf ../../../sample_apps/deploy_scripts/*.conf $SAMPLEAPPS_DIR
        \cp -pf ../../../sample_apps/deploy_scripts/run_sample_apps.sh $SAMPLEAPPS_DIR
	\cp -pf ../../../sample_apps/deploy_scripts/deployment_prerequisites.sh $SAMPLEAPPS_DIR
	\cp -pf ../deploy_scripts/deploy_sgx_dependencies.sh $SAMPLEAPPS_DIR
	\cp -pf ../../../config $SAMPLEAPPS_DIR
        \cp -rpf ../../../../../../utils/tools/sample-sgx-attestation/out/ $SAMPLEAPPS_DIR
        rm -f $SAMPLEAPPS_DIR/out/rootca.pem
	tar -cf $TAR_NAME.tar -C $SAMPLEAPPS_DIR . --remove-files || exit 1
	sha256sum $TAR_NAME.tar > $TAR_NAME.sha2
        chmod 755 $TAR_NAME.sha2
	echo "sample_apps.tar file and sample_apps.sha2 checksum file created"
}

install_sgxsdk()
{
	pushd $PWD
	cd ../../stack_scripts
	source install_sgxsdk.sh
	if [ $? -ne 0 ]; then
        	echo "${red} sgxsdk install failed ${reset}"
        	exit 1
	fi
	popd
}

install_sgxrpm()
{
	pushd $PWD
	cd ../../stack_scripts
	source install_sgxrpms.sh
	if [ $? -ne 0 ]; then
		echo "sgx psw/qgl rpm installation failed"
		exit 1
	fi
	popd
}
	
install_sgxssl()
{
        pushd $PWD
        cd ../../../sample_apps/build_scripts
	source install_sgxssl.sh
	if [ $? -ne 0 ]; then
		echo "sgxssl installation failed"
		exit 1
	fi
	popd
	\cp -rpf $SGXSSL_PREFIX $SAMPLEAPPS_DIR
}

build_sample_apps()
{
	pushd $PWD
	cd ../../../sample_apps/build_scripts
	source build_sampleapps.sh
	if [ $? -ne 0 ]; then
		echo "sample apps build failed"
		exit 1
	fi
	popd
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
