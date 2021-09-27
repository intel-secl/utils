#!/bin/bash
build_skc_library()
{
	pushd $PWD
	cd ../../../../../skc_library
	./scripts/build.sh
	if [ $? -ne 0 ]; then
		echo "ERROR: skc_library build failed with $?"
		exit 1
	fi

	./scripts/generate_bin.sh $SKCLIB_VERSION
	if [ $? -ne 0 ]; then
                echo "ERROR: skc_library binary generation failed with $?"
                exit 1
        fi
	
	\cp -pf skc_library_v*.bin $SKCLIB_BIN_DIR
	popd
        if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
                \cp -pf $LIB_DIR/engines-1.1/pkcs11.so $SKCLIB_BIN_DIR
        elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" ]]; then
                \cp -pf $LIB_DIR/x86_64-linux-gnu/engines-1.1/pkcs11.so $SKCLIB_BIN_DIR
        fi
        \cp -pf $LIB_DIR/libp11.so.3.4.3 $SKCLIB_BIN_DIR
}

build_skc_library
