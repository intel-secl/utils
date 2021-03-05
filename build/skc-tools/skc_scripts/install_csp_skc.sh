#!/bin/bash
HOME_DIR=~/
SKC_BINARY_DIR=$HOME_DIR/binaries

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

CMS_PORT=8445
AAS_PORT=8444
SCS_PORT=9000
SQVS_PORT=12000
SHVS_PORT=13000
KBS_PORT=9443

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

if [[ "$OS" == "rhel" && "$VER" == "8.1" || "$VER" == "8.2" ]]; then
	dnf install -qy jq
elif [[ "$OS" == "ubuntu" && "$VER" == "18.04" ]]; then
	apt install -y jq curl
else
	echo "${red} Unsupported OS. Please use RHEL 8.1/8.2 or Ubuntu 18.04 ${reset}"
	exit 1
fi

# Copy env files to Home directory
\cp -pf ./env/cms.env $HOME_DIR
\cp -pf ./env/authservice.env $HOME_DIR
\cp -pf ./env/scs.env $HOME_DIR
\cp -pf ./env/shvs.env $HOME_DIR
\cp -pf ./env/ihub.env $HOME_DIR
\cp -pf ./env/iseclpgdb.env $HOME_DIR
\cp -pf ./env/populate-users.env $HOME_DIR

# Copy DB and user/role creation script to Home directory
\cp -pf ./install_pg.sh $HOME_DIR
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

    if [[ "$SCS_DB_NAME" == "$SHVS_DB_NAME" || "$AAS_DB_NAME" == "$SHVS_DB_NAME" || "$SCS_DB_NAME" == "$AAS_DB_NAME" ]]; then
        echo "${red} SCS_DB_NAME, SHVS_DB_NAME & AAS_DB_NAME should not be same. Please change in csp_skc.conf ${reset}"
        exit 1
    fi
    env_file_exports=$(cat ./csp_skc.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
    if [ -n "$env_file_exports" ]; then eval export $env_file_exports; fi
fi

echo "Uninstalling Certificate Management Service...."
cms uninstall --purge
echo "Uninstalling AuthService...."
authservice uninstall --purge
echo "Removing AuthService Database...."
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb $AAS_DB_NAME
echo "Uninstalling SGX Caching Service...."
scs uninstall --purge
echo "Removing SGX Caching Service Database...."
sudo -u postgres dropdb $SCS_DB_NAME
echo "Uninstalling SGX Host Verification Service...."
shvs uninstall --purge
echo "Removing SGX Host Verification Service Database...."
sudo -u postgres dropdb $SHVS_DB_NAME
echo "Uninstalling Integration HUB...."
ihub uninstall --purge
popd

pushd $PWD
cd ~

echo "Installing Postgres....."
bash install_pg.sh
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

echo "Creating SCS database....."
bash create_db.sh $SCS_DB_NAME $SCS_DB_USERNAME $SCS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} scs db creation failed ${reset}"
        exit 1
fi
echo "SCS database created successfully"

echo "Creating SHVS database....."
bash create_db.sh $SHVS_DB_NAME $SHVS_DB_USERNAME $SHVS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} shvs db creation failed ${reset}"
        exit 1
fi
echo "SHVS database created successfully"

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
CMS_TOKEN=`cms setup cms_auth_token --force | grep 'JWT Token:' | awk '{print $3}'`
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
ISECL_INSTALL_COMPONENTS=AAS,SCS,SHVS,SIH
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/populate-users.env

AAS_ADMIN_USERNAME=$(cat ~/authservice.env | grep ^AAS_ADMIN_USERNAME= | cut -d'=' -f2)
AAS_ADMIN_PASSWORD=$(cat ~/authservice.env | grep ^AAS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s@^\(IH_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(SCS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(SHVS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env

IHUB_SERVICE_USERNAME=$(cat ~/ihub.env | grep ^IHUB_SERVICE_USERNAME= | cut -d'=' -f2)
IHUB_SERVICE_PASSWORD=$(cat ~/ihub.env | grep ^IHUB_SERVICE_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(IHUB_SERVICE_USERNAME\s*=\s*\).*\$/\1$IHUB_SERVICE_USERNAME/" ~/populate-users.env
sed -i "s/^\(IHUB_SERVICE_PASSWORD\s*=\s*\).*\$/\1$IHUB_SERVICE_PASSWORD/" ~/populate-users.env

SCS_ADMIN_USERNAME=$(cat ~/scs.env | grep ^SCS_ADMIN_USERNAME= | cut -d'=' -f2)
SCS_ADMIN_PASSWORD=$(cat ~/scs.env | grep ^SCS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(SCS_SERVICE_USERNAME\s*=\s*\).*\$/\1$SCS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(SCS_SERVICE_PASSWORD\s*=\s*\).*\$/\1$SCS_ADMIN_PASSWORD/" ~/populate-users.env

SHVS_ADMIN_USERNAME=$(cat ~/shvs.env | grep ^SHVS_ADMIN_USERNAME= | cut -d'=' -f2)
SHVS_ADMIN_PASSWORD=$(cat ~/shvs.env | grep ^SHVS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(SHVS_SERVICE_USERNAME\s*=\s*\).*\$/\1$SHVS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(SHVS_SERVICE_PASSWORD\s*=\s*\).*\$/\1$SHVS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s/^\(INSTALL_ADMIN_USERNAME\s*=\s*\).*\$/\1$INSTALL_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(INSTALL_ADMIN_PASSWORD\s*=\s*\).*\$/\1$INSTALL_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "/GLOBAL_ADMIN_USERNAME/d" ~/populate-users.env
sed -i "/GLOBAL_ADMIN_PASSWORD/d" ~/populate-users.env

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

echo "Updating SGX Caching Service env...."
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/"  ~/scs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/"  ~/scs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/scs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/scs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER@" ~/scs.env
sed -i "s@^\(INTEL_PROVISIONING_SERVER_API_KEY\s*=\s*\).*\$@\1$INTEL_PROVISIONING_SERVER_API_KEY@" ~/scs.env
sed -i "s/^\(SCS_DB_NAME\s*=\s*\).*\$/\1$SCS_DB_NAME/"  ~/scs.env
sed -i "s/^\(SCS_DB_USERNAME\s*=\s*\).*\$/\1$SCS_DB_USERNAME/"  ~/scs.env
sed -i "s/^\(SCS_DB_PASSWORD\s*=\s*\).*\$/\1$SCS_DB_PASSWORD/"  ~/scs.env

echo "Installing SGX Caching Service...."
./scs-*.bin
scs status > /dev/null
if [ $? -ne 0 ]; then
  echo "${red} SGX Caching Service Installation Failed ${reset}"
  exit 1
fi
echo "${green} Installed SGX Caching Service.... ${reset}"

echo "Updating SGX Host Verification Service env.... "
sed -i "s/^\(SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/shvs.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/shvs.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/shvs.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/shvs.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/shvs.env
SCS_URL=https://$SYSTEM_IP:$SCS_PORT/scs/sgx/
sed -i "s@^\(SCS_BASE_URL\s*=\s*\).*\$@\1$SCS_URL@" ~/shvs.env
sed -i "s/^\(SHVS_DB_NAME\s*=\s*\).*\$/\1$SHVS_DB_NAME/"  ~/shvs.env
sed -i "s/^\(SHVS_DB_USERNAME\s*=\s*\).*\$/\1$SHVS_DB_USERNAME/"  ~/shvs.env
sed -i "s/^\(SHVS_DB_PASSWORD\s*=\s*\).*\$/\1$SHVS_DB_PASSWORD/"  ~/shvs.env

echo "Installing SGX Host Verification Service...."
./shvs-*.bin
shvs status > /dev/null
if [ $? -ne 0 ]; then
  echo "${red} SGX Host Verification Service Installation Failed ${reset}"
  exit 1
fi
echo "${green} Installed SGX Host Verification Service.... ${reset}"

echo "Updating Integration HUB env...."
sed -i "s/^\(TLS_SAN_LIST\s*=\s*\).*\$/\1$SYSTEM_SAN/" ~/ihub.env
sed -i "s/^\(BEARER_TOKEN\s*=\s*\).*\$/\1$INSTALL_ADMIN_TOKEN/" ~/ihub.env
sed -i "s/^\(CMS_TLS_CERT_SHA384\s*=\s*\).*\$/\1$CMS_TLS_SHA/" ~/ihub.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/ihub.env
sed -i "s@^\(CMS_BASE_URL\s*=\s*\).*\$@\1$CMS_URL@" ~/ihub.env
SHVS_URL=https://$SYSTEM_IP:$SHVS_PORT/sgx-hvs/v2
K8S_URL=https://$K8S_IP:6443/
sed -i "s@^\(ATTESTATION_SERVICE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/ihub.env
sed -i "s@^\(KUBERNETES_URL\s*=\s*\).*\$@\1$K8S_URL@" ~/ihub.env
if [[ "$OS" != "ubuntu" ]]; then
OPENSTACK_AUTH_URL=http://$OPENSTACK_IP:5000/
OPENSTACK_PLACEMENT_URL=http://$OPENSTACK_IP:8778/
sed -i "s@^\(OPENSTACK_AUTH_URL\s*=\s*\).*\$@\1$OPENSTACK_AUTH_URL@" ~/ihub.env
sed -i "s@^\(OPENSTACK_PLACEMENT_URL\s*=\s*\).*\$@\1$OPENSTACK_PLACEMENT_URL@" ~/ihub.env
fi
sed -i "s@^\(TENANT\s*=\s*\).*\$@\1$TENANT@" ~/ihub.env

echo "Installing Integration HUB...."
./ihub-*.bin
ihub status > /dev/null
if [ $? -ne 0 ]; then
  echo " ${red} Integration HUB Installation Failed ${reset}"
  exit 1
fi
echo "${green} Installed Integration HUB.... ${reset}"
