#!/bin/bash
HOME_DIR=$(pwd)/out
SGX_SDK_INSTALL_PATH=/opt/intel/sgxsdk/environment
ATTESTEDAPP_HOST=127.0.0.1
LIB_DIR=/usr/lib64

# Read from environment variables file if it exists
if [ -f ./sample_apps.conf ]; then
	echo "Reading Installation variables from $(pwd)/out.conf"
	source sample_apps.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in out.conf ${reset}"
		exit 1
	fi
	env_file_exports=$(cat ./sample_apps.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
	if [ -n "$env_file_exports" ]; then
		eval export $env_file_exports;
	fi
fi

# Kill if any process is running
ps -eaf  | grep "sgx-attested" | grep -v grep | awk '{print $2}' | xargs kill > /dev/null 2>&1

# Download CA Certificate from CMS
cd $HOME_DIR
curl -k -H 'Accept:application/x-pem-file' https://$ENTERPRISE_CMS_IP:$ENTERPRISE_CMS_PORT/cms/v1/ca-certificates > $HOME_DIR/rootca.pem
if [ $? -ne 0 ]; then
	echo "could not get Certificate Management Service Root CA Certificate"
	exit 1
fi

# Copying the libraries to default location
\cp -r $HOME_DIR/enclave.signed.so $LIB_DIR/libenclave.signed.so
\cp -r $HOME_DIR/untrusted.so $LIB_DIR/libuntrusted.so

# Update the configuration file
sed -i 's/attestedapp-host=.*/attestedapp-host='$ATTESTEDAPP_HOST'/' $HOME_DIR/config.yml
SQVS_URL=https://$SQVS_IP:$SQVS_PORT/svs/v1
sed -i "s@^\(sqvs-url\s*:\s*\).*\$@\1$SQVS_URL@" $HOME_DIR/config.yml

PCCS_URL=https://$SCS_IP:$SCS_PORT/scs/sgx/certification/v1/
sed -i "s@^\(PCCS_URL\s*=\s*\).*\$@\1$PCCS_URL@" /etc/sgx_default_qcnl.conf
sed -i "s|.*USE_SECURE_CERT=.*|USE_SECURE_CERT=FALSE|g" /etc/sgx_default_qcnl.conf

source $SGX_SDK_INSTALL_PATH
cd $HOME_DIR
rm -rf info.txt
echo "$(sgx_sign dump -enclave enclave.signed.so -dumpfile info.txt)"
echo "$HOME_DIR"

# Get the required enclave measurement values
MR_ENCLAVE=$(cat -n $HOME_DIR/info.txt | grep -A2 "metadata->enclave_css.body.enclave_hash.m:" | tr -d '\ \:\-\>\_\.' | sort -uk2 | sort -n | cut -f2- | tr -d '\n'| sed "s/metadataenclavecssbodyenclavehashm//g" | sed "s/0x//g")
MR_SIGNER=$(cat $HOME_DIR/info.txt | grep -A3 "mrsigner->value" | tr -d '\n\ \:\-\>' | sed "s/mrsignervalue//g" | sed "s/0x//g")

# Update the contents of sgx-quote-policy.txt file
sed -i "s@^\(MREnclave\s*:\s*\).*\$@\1$MR_ENCLAVE@" $HOME_DIR/sgx-quote-policy.txt
sed -i "s@^\(MRSigner\s*:\s*\).*\$@\1$MR_SIGNER@"  $HOME_DIR/sgx-quote-policy.txt

# Run the Sample Apps
sample_apps() {

	cd $HOME_DIR
	rm -rf attested_app_console_out.log attesting_app_console_out.log

	./sgx-attested-app run > attested_app_console_out.log 2>&1 &
	sleep 1
	if [ $RUN_ATTESTING_APP == "yes" ] ;then
		./sgx-attesting-app run > attesting_app_console_out.log 2>&1
		echo "Console logs can be found in out folder(attested_app_console_out.log and attesting_app_console_out.log). Please check the same for SGX Attestation Flow verification"
		exit
        fi
        echo "Console log can be found in out folder(attested_app_console_out.log). Please run the sgx attesting app for SGX Attestation Flow verification"
        exit
}

sample_apps
