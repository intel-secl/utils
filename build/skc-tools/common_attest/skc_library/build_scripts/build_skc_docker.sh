#!/bin/bash
source ../../../config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi


rm -rf $SKCLIB_DIR

if [ "$OS" == "rhel" ]; then
	rm -f /etc/yum.repos.d/*sgx_rpm_local_repo.repo
fi

install_skc_lib_and_deps()
{
        source skc_library_build.sh
        if [ $? -ne 0 ]; then
                echo "${red} cryptoapitoolkit installation failed ${reset}"
                exit 1
        fi
}
build_skc_library_docker()
{
	pushd $PWD
	cd ../../../skc_library/build_scripts
	source build_skc_docker.sh
	if [ $? -ne 0 ]; then
		echo "${red} skc_library build failed ${reset}"
		exit 1
	fi
	popd
}
install_skc_lib_and_deps
build_skc_library_docker
