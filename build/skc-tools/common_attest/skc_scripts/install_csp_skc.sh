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
\cp -pf ./env/fds.env $HOME_DIR
\cp -pf ./env/ihub.env $HOME_DIR
\cp -pf ./env/iseclpgdb.env $HOME_DIR
\cp -pf ./env/populate-users.env $HOME_DIR

# Copy DB and user/role creation script to Home directory
\cp -pf ./install_pgdb.sh $HOME_DIR
\cp -pf ./create_db.sh $HOME_DIR
\cp -pf ./populate-users.sh $HOME_DIR

# read from environment variables file if it exists
if [ -f ./csp_skc.conf ]; then
	echo "Reading Installation variables from $(pwd)/csp_skc.conf"
	source csp_skc.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in csp_skc.conf ${reset}"
		exit 1
	fi
	if [[ "$TCS_DB_NAME" == "$FDS_DB_NAME" || "$AAS_DB_NAME" == "$FDS_DB_NAME" || "$TCS_DB_NAME" == "$AAS_DB_NAME" ]]; then
 	echo "${red} TCS_DB_NAME, FDS_DB_NAME & AAS_DB_NAME should not be same. Please change in csp_skc.conf ${reset}"
		exit 1
	fi
	env_file_exports=$(cat ./csp_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
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
echo "Uninstalling Feature Discovery Service...."
fds uninstall --purge
echo "Removing Feature Discovery Service Database...."
sudo -u postgres dropdb $FDS_DB_NAME
echo "Uninstalling Integration HUB...."
ihub uninstall --purge --exec
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

echo "Creating FDS database....."
bash create_db.sh $FDS_DB_NAME $FDS_DB_USERNAME $FDS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} fds db creation failed ${reset}"
        exit 1
fi
echo "FDS database created successfully"

popd

echo "Installing Certificate Management Service...."
AAS_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1
sed -i "s/^\(AAS_TLS_SAN\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/cms.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/cms.env
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/cms.env

./cms-v*.bin
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
ISECL_INSTALL_COMPONENTS=AAS,TCS,FDS,IHUB
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/populate-users.env

AAS_ADMIN_USERNAME=$(cat ~/authservice.env | grep ^AAS_ADMIN_USERNAME= | cut -d'=' -f2)
AAS_ADMIN_PASSWORD=$(cat ~/authservice.env | grep ^AAS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s@^\(IH_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(TCS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(FDS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env

IHUB_SERVICE_USERNAME=$(cat ~/ihub.env | grep ^IHUB_SERVICE_USERNAME= | cut -d'=' -f2)
IHUB_SERVICE_PASSWORD=$(cat ~/ihub.env | grep ^IHUB_SERVICE_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(IHUB_SERVICE_USERNAME\s*=\s*\).*\$/\1$IHUB_SERVICE_USERNAME/" ~/populate-users.env
sed -i "s/^\(IHUB_SERVICE_PASSWORD\s*=\s*\).*\$/\1$IHUB_SERVICE_PASSWORD/" ~/populate-users.env

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

echo "Updating Feature Discovery Service env.... "
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/fds.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/fds.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/fds.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/fds.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/fds.env
sed -i "s@^\(TCS_BASE_URL\s*=\s*\).*\$@\1$TCS_URL@" ~/fds.env
sed -i "s/^\(DB_NAME\s*=\s*\).*\$/\1$FDS_DB_NAME/"  ~/fds.env
sed -i "s/^\(DB_USERNAME\s*=\s*\).*\$/\1$FDS_DB_USERNAME/"  ~/fds.env
sed -i "s/^\(DB_PASSWORD\s*=\s*\).*\$/\1$FDS_DB_PASSWORD/"  ~/fds.env
sed -i "s|.*DB_HOSTNAME=.*|DB_HOSTNAME=localhost|g" ~/fds.env
sed -i "s|.*DB_PORT=.*|DB_PORT=5432|g" ~/fds.env


echo "Installing Feature Discovery Service...."
./fds-*.bin
fds status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} Feature Discovery Service Installation Failed ${reset}"
	exit 1
fi
echo "${green} Installed Feature Discovery Service.... ${reset}"

echo "Updating Integration HUB env...."
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/ihub.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/ihub.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/ihub.env
sed -i "s@^\(AAS_BASE_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/ihub.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/ihub.env
FDS_URL=https://$SYSTEM_IP:$FDS_PORT/fds/v1
K8S_URL=https://$K8S_IP:$K8S_PORT/
sed -i "s@^\(FDS_BASE_URL\s*=\s*\).*\$@\1$FDS_URL@" ~/ihub.env
sed -i "s@^\(KUBERNETES_URL\s*=\s*\).*\$@\1$K8S_URL@" ~/ihub.env
sed -i "s@^\(KUBERNETES_TOKEN\s*=\s*\).*\$@\1$K8S_TOKEN@" ~/ihub.env
sed -i "s@^\(TENANT\s*=\s*\).*\$@\1$TENANT@" ~/ihub.env
sed -i '/^[^#]/ s/\(^.*HVS_BASE_URL.*$\)/#\ \1/' ~/ihub.env

echo "Installing Integration HUB...."
./ihub-*.bin
ihub status > /dev/null
if [ $? -ne 0 ]; then
        echo "${red} Integration HUB Installation Failed ${reset}"
        exit 1
fi
echo "${green} Installed Integration HUB.... ${reset}"
