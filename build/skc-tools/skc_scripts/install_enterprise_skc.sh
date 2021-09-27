#!/bin/bash
source install_sgx_infra.sh
if [ $? -ne 0 ]; then
	echo "${red} unable to deploy SGX Attestation Infrastructure services ${reset}"
	exit 1
fi

\cp -pf $BINARY_DIR/env/kbs.env $HOME_DIR

# read from environment variables file if it exists
if [ -f ./enterprise_skc.conf ]; then
	echo "Reading Installation variables from $(pwd)/enterprise_skc.conf"
	source enterprise_skc.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in enterprise_skc.conf ${reset}"
		exit 1
	fi
	env_file_exports=$(cat ./enterprise_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
	if [ -n "$env_file_exports" ]; then
		eval export $env_file_exports;
	fi
fi

echo "Updating Populate users env ...."
ISECL_INSTALL_COMPONENTS=SKBS
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(KBS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
KBS_SERVICE_USERNAME=$(cat ~/kbs.env | grep ^KBS_SERVICE_USERNAME= | cut -d'=' -f2)
KBS_SERVICE_PASSWORD=$(cat ~/kbs.env | grep ^KBS_SERVICE_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(KBS_SERVICE_USERNAME\s*=\s*\).*\$/\1$KBS_SERVICE_USERNAME/" ~/populate-users.env
sed -i "s/^\(KBS_SERVICE_PASSWORD\s*=\s*\).*\$/\1$KBS_SERVICE_PASSWORD/" ~/populate-users.env

if [ $CCC_ADMIN_USERNAME != "" ] && [ $CCC_ADMIN_PASSWORD != "" ]; then
	sed -i "s/^\(CCC_ADMIN_USERNAME\s*=\s*\).*\$/\1$CCC_ADMIN_USERNAME/" ~/populate-users.env
	sed -i "s/^\(CCC_ADMIN_PASSWORD\s*=\s*\).*\$/\1$CCC_ADMIN_PASSWORD/" ~/populate-users.env
else
	sed -i "/CCC_ADMIN_USERNAME/d" ~/populate-users.env
	sed -i "/CCC_ADMIN_PASSWORD/d" ~/populate-users.env
fi

echo "Invoking populate users script...."
pushd $PWD
cd ~
./populate-users.sh
if [ $? -ne 0 ]; then
	echo "${red} populate user script failed ${reset}"
	exit 1
fi
popd

echo "Getting AuthService Admin token...."
INSTALL_ADMIN_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:$AAS_PORT/aas/v1/token -d '{"username": "'"$INSTALL_ADMIN_USERNAME"'", "password": "'"$INSTALL_ADMIN_PASSWORD"'"}'`

if [ $? -ne 0 ]; then
	echo "${red} Could not get AuthService Admin token ${reset}"
	exit 1
fi

echo "Updating Key Broker Service env...."
KBS_HOSTNAME=$("hostname")
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN,$KBS_HOSTNAME/" ~/kbs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/kbs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/kbs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/kbs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/kbs.env
SQVS_URL=https://$SYSTEM_IP:$SQVS_PORT/svs/v1
sed -i "s@^\(SQVS_URL\s*=\s*\).*\$@\1$SQVS_URL@" ~/kbs.env
ENDPOINT_URL=https://$SYSTEM_IP:$KBS_PORT/kbs/v1
sed -i "s@^\(ENDPOINT_URL\s*=\s*\).*\$@\1$ENDPOINT_URL@" ~/kbs.env

echo "Updating KMIP Server conf...."
sed -i "s@^\(KMIP_SERVER_IP\s*=\s*\).*\$@\1$SYSTEM_IP@" ~/kbs.env
sed -i "s@^\(KMIP_SERVER_PORT\s*=\s*\).*\$@\1$KMIP_SERVER_PORT@" ~/kbs.env
sed -i "s@^\(KMIP_CLIENT_CERT_PATH\s*=\s*\).*\$@\1$KMIP_CLIENT_CERT_PATH@" ~/kbs.env
sed -i "s@^\(KMIP_CLIENT_KEY_PATH\s*=\s*\).*\$@\1$KMIP_CLIENT_KEY_PATH@" ~/kbs.env
sed -i "s@^\(KMIP_ROOT_CERT_PATH\s*=\s*\).*\$@\1$KMIP_ROOT_CERT_PATH@" ~/kbs.env

sed -i "s@^\(hostname\s*=\s*\).*\$@\1$SYSTEM_IP@" kbs_script/server.conf
sed -i "s@^\(port\s*=\s*\).*\$@\1$KMIP_SERVER_PORT@" kbs_script/server.conf

sed -i "s@^\(HOSTNAME_IP\s*=\s*\).*\$@\1'$SYSTEM_IP'@" kbs_script/rsa_create.py
sed -i "s@^\(SERVER_PORT\s*=\s*\).*\$@\1'$KMIP_SERVER_PORT'@" kbs_script/rsa_create.py
sed -i "s@^\(CERT_PATH\s*=\s*\).*\$@\1'$KMIP_CLIENT_CERT_PATH'@" kbs_script/rsa_create.py
sed -i "s@^\(KEY_PATH\s*=\s*\).*\$@\1'$KMIP_CLIENT_KEY_PATH'@" kbs_script/rsa_create.py
sed -i "s@^\(CA_PATH\s*=\s*\).*\$@\1'$KMIP_ROOT_CERT_PATH'@" kbs_script/rsa_create.py

echo "Installing KMIP Server....."
pushd $PWD
cd kbs_script/
bash install_pykmip.sh
if [ $? -ne 0 ]; then
	echo "${red} KMIP Server Installation Failed ${reset}"
	exit 1
fi
popd
echo "KMIP Server installed successfully"

echo "Installing Key Broker Service...."
./kbs-*.bin
kbs status > /dev/null
if [ $? -ne 0 ]; then
  echo "${red} Key Broker Service Installation Failed ${reset}"
  exit 1
fi
echo "${green} Installed Key Broker Service.... ${reset}"
