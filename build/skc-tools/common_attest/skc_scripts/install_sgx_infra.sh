#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "${red} unable to read config variables ${reset}"
	exit 1
fi

HOME_DIR=~/
BINARY_DIR=$HOME_DIR/binaries

if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2"  || "$VER" == "8.4" ]]; then
        dnf install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || exit 1
        dnf install -qy curl || exit 1
elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" || "$VER" == "20.04" ]]; then
        apt install -y curl || exit 1
else
        echo "${red} Unsupported OS. Please use RHEL 8.1/8.2/8.4 or Ubuntu 18.04/20.04 ${reset}"
        exit 1
fi

# Copy env files to Home directory
\cp -pf ./env/cms.env $HOME_DIR
\cp -pf ./env/authservice.env $HOME_DIR
\cp -pf ./env/tcs.env $HOME_DIR
\cp -pf ./env/aps.env $HOME_DIR
\cp -pf ./env/qvs.env $HOME_DIR
\cp -pf ./env/apc.env $HOME_DIR
\cp -pf ./env/iseclpgdb.env $HOME_DIR
\cp -pf ./env/populate-users.env $HOME_DIR

# Copy DB and user/role creation script to Home directory
\cp -pf ./install_pgdb.sh $HOME_DIR
\cp -pf ./create_db.sh $HOME_DIR
\cp -pf ./populate-users.sh $HOME_DIR

# read from environment variables file if it exists
if [ -f ./enterprise_skc.conf ]; then
	echo "Reading Installation variables from $(pwd)/enterprise_skc.conf"
	source enterprise_skc.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in enterprise_skc.conf ${reset}"
		exit 1
	fi

	if [[ "$TCS_DB_NAME" == "$AAS_DB_NAME" || "$AAS_DB_NAME" == $APS_DB_NAME ]]; then
		echo "${red} TCS_DB_NAME, APS_DB_NAME & AAS_DB_NAME should not be same. Please change in enterprise_skc.conf ${reset}"
	exit 1
	fi
	env_file_exports=$(cat ./enterprise_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
	if [ -n "$env_file_exports" ]; then
		eval export $env_file_exports;
	fi
fi

echo "Uninstalling Certificate Management Service...."
cms uninstall --purge
echo "Uninstalling AuthService...."
authservice uninstall --purge
echo "Removing AuthService Database...."
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb $AAS_DB_NAME
echo "Uninstalling TEE Caching Service...."
tcs uninstall --purge
echo "Removing TEE Caching Service Database...."
sudo -u postgres dropdb $TCS_DB_NAME
echo "Uninstalling Application Policy Service...."
aps uninstall --purge
echo "Removing Application Policy Service Database...."
sudo -u postgres dropdb $APS_DB_NAME
echo "Uninstalling Quote Verification Service...."
qvs uninstall --purge
echo "Uninstalling Application Policy Creator Service...."
apc uninstall --purge
popd

pushd $PWD
cd ~

echo "Installing Postgres....."
bash install_pgdb.sh
if [ $? -ne 0 ]; then
        echo "${red} postgres installation failed ${reset}"
        exit 1
fi
echo "Postgres installated successfully"

echo "Creating AAS database....."
bash create_db.sh $AAS_DB_NAME $AAS_DB_USERNAME $AAS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} aas db creation failed ${reset}"
        exit 1
fi
echo "AAS database created successfully"

echo "Creating TCS database....."
bash create_db.sh $TCS_DB_NAME $TCS_DB_USERNAME $TCS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} tcs db creation failed ${reset}"
        exit 1
fi
echo "TCS database created successfully"

echo "Creating APS database....."
bash create_db.sh $APS_DB_NAME $APS_DB_USERNAME $APS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} aps db creation failed ${reset}"
        exit 1
fi
echo "APS database created successfully"

popd

echo "Installing Certificate Management Service...."
AAS_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1
sed -i "s/^\(AAS_TLS_SAN\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/cms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/cms.env
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/cms.env

./cms-*.bin
cms status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} Certificate Management Service Installation Failed $reset}"
	exit 1
fi
echo "${green} Installed Certificate Management Service.... ${reset}"

echo "Installing AuthService...."

echo "Copying Certificate Management Service token to AuthService...."
export AAS_TLS_SAN=$SYSTEM_SAN
CMS_TOKEN=`cms setup cms-auth-token --force | grep 'JWT Token:' | awk '{print $3}'`
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$CMS_TOKEN/"  ~/authservice.env

CMS_TLS_SHA=`cms tlscertsha384`
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/"  ~/authservice.env

CMS_URL=https://$SYSTEM_IP:$CMS_PORT/cms/v1/
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@"  ~/authservice.env

sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/"  ~/authservice.env
sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/"  ~/authservice.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/"  ~/authservice.env
sed -i "s/^\(AAS_DB_NAME\s*=\s*\).*\$/\1$AAS_DB_NAME/"  ~/authservice.env
sed -i "s/^\(AAS_DB_USERNAME\s*=\s*\).*\$/\1$AAS_DB_USERNAME/"  ~/authservice.env
sed -i "s/^\(AAS_DB_PASSWORD\s*=\s*\).*\$/\1$AAS_DB_PASSWORD/"  ~/authservice.env

./authservice-*.bin
authservice status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} AuthService Installation Failed ${reset}"
	exit 1
fi
echo "${green} Installed AuthService.... ${reset}"

echo "Updating Populate users env ...."
ISECL_INSTALL_COMPONENTS=AAS,TCS,APC,APS,QVS
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/populate-users.env

sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s@^\(TCS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(APC_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(APS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(QVS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env

APS_ADMIN_USERNAME=$(cat ~/aps.env | grep ^APS_ADMIN_USERNAME= | cut -d'=' -f2)
APS_ADMIN_PASSWORD=$(cat ~/aps.env | grep ^APS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(APS_SERVICE_USERNAME\s*=\s*\).*\$/\1$APS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(APS_SERVICE_PASSWORD\s*=\s*\).*\$/\1$APS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s/^\(INSTALL_ADMIN_USERNAME\s*=\s*\).*\$/\1$INSTALL_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(INSTALL_ADMIN_PASSWORD\s*=\s*\).*\$/\1$INSTALL_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s/^\(GLOBAL_ADMIN_USERNAME\s*=\s*\).*\$/\1$GLOBAL_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(GLOBAL_ADMIN_PASSWORD\s*=\s*\).*\$/\1$GLOBAL_ADMIN_PASSWORD/" ~/populate-users.env

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

echo "Updating TEE Caching Service env...."
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/"  ~/tcs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/"  ~/tcs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/tcs.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/tcs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/tcs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER@" ~/tcs.env
sed -i "s@^\(INTEL_PCS_API_KEY\s*=\s*\).*\$@\1$INTEL_PCS_API_KEY@" ~/tcs.env
sed -i "s/^\(DB_NAME\s*=\s*\).*\$/\1$TCS_DB_NAME/"  ~/tcs.env
sed -i "s/^\(DB_USERNAME\s*=\s*\).*\$/\1$TCS_DB_USERNAME/"  ~/tcs.env
sed -i "s/^\(DB_PASSWORD\s*=\s*\).*\$/\1$TCS_DB_PASSWORD/"  ~/tcs.env
sed -i "s|.*DB_SSL_CERT_SOURCE=.*|DB_SSL_CERT_SOURCE=/usr/local/pgsql/data/server.crt|g" ~/tcs.env

echo "Installing TEE Caching Service...."
./tcs-*.bin
tcs status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} TEE Caching Service Installation Failed ${reset}"
	exit 1
fi
echo "${green} Installed TEE Caching Service.... ${reset}"

#Post Installation Steps for TCS
sed -i '/RuntimeDirectoryMode=0775/a Environment=HTTPS_PROXY=http://proxy-us.intel.com:911' /etc/systemd/system/tcs.service
systemctl daemon-reload
tcs stop > /dev/null
tcs start > /dev/null

echo "Updating Attestation Policy Service env.... "
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/aps.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/aps.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/aps.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/aps.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/aps.env
QVS_URL=https://$SYSTEM_IP:$QVS_PORT/qvs/v1/
sed -i "s@^\(QVS_BASE_URL\s*=\s*\).*\$@\1$QVS_URL@" ~/aps.env
sed -i "s/^\(DB_NAME\s*=\s*\).*\$/\1$APS_DB_NAME/"  ~/aps.env
sed -i "s/^\(DB_USERNAME\s*=\s*\).*\$/\1$APS_DB_USERNAME/"  ~/aps.env
sed -i "s/^\(DB_PASSWORD\s*=\s*\).*\$/\1$APS_DB_PASSWORD/"  ~/aps.env
sed -i "s|.*APS_SERVICE_USERNAME=.*|APS_SERVICE_USERNAME=admin@aps|g" ~/aps.env
sed -i "s|.*APS_SERVICE_PASSWORD=.*|APS_SERVICE_PASSWORD=apsAdminPass|g" ~/aps.env

echo "Installing Attestation Policy' Service...."
./aps-*.bin
aps status > /dev/null
if [ $? -ne 0 ]; then
        echo "${red} Attestation Policy Service Installation Failed ${reset}"
        exit 1
fi
echo "${green} Installed Attestation Policy Service.... ${reset}"

echo "Updating Quote Verification Service env...."
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/"  ~/qvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/"  ~/qvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/qvs.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/qvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/qvs.env
TCS_URL=https://$SYSTEM_IP:$TCS_PORT/tcs/v4/sgx/
sed -i "s@^\(TCS_BASE_URL\s*=\s*\).*\$@\1$TCS_URL@" ~/qvs.env
sed -i "s@^\(SANDBOX_QVL\s*=\s*\).*\$@\1$SANDBOX_QVL@" ~/qvs.env

echo "Installing Quote Verification Service...."
./qvs-*.bin
qvs status > /dev/null
if [ $? -ne 0 ]; then
        echo "${red} Quote Verification Service Installation Failed ${reset}"
        exit 1
fi
echo "${green} Installed Quote Verification Service....${reset}"

echo "Updating Attestation Policy Creator Service env...."
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/"  ~/apc.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/apc.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/apc.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/apc.env

echo "Installing Attestation Policy Creator Service...."
./apc-*.bin
#apc status > /dev/null
if [ $? -ne 0 ]; then
        echo "${red} Attestation Policy Creator Service Installation Failed ${reset}"
        exit 1
fi
echo "${green} Installed Attestation Policy Creator Service....${reset}"
