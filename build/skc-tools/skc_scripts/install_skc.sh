#!/bin/bash
source install_enterprise_skc.sh
if [ $? -ne 0 ]
then
        echo "${red} Basic components installation failed ${reset}"
        exit 1
fi

\cp -pf $BINARY_DIR/env/shvs.env $HOME_DIR
\cp -pf $BINARY_DIR/env/ihub.env $HOME_DIR

if [ -f ./orchestrator.conf ]; then
	echo "Reading Installation variables from $(pwd)/orchestrator.conf"
	source orchestrator.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in orchestrator.conf ${reset}"
		exit 1
	fi
	env_file_exports=$(cat ./orchestrator.conf | grep -E '^[A-Z0-9_]+\s*=' | cut -d = -f 1)
	if [ -n "$env_file_exports" ]; then
		eval export $env_file_exports;
	fi
fi

echo "Uninstalling SGX Host Verification Service...."
shvs uninstall --purge
echo "Removing SGX Host Verification Service Database...."
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb $SHVS_DB_NAME
echo "Uninstalling Integration HUB...."
ihub uninstall --purge --exec
popd

pushd $PWD
cd ~

echo "Creating SHVS database....."
bash create_db.sh $SHVS_DB_NAME $SHVS_DB_USERNAME $SHVS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} shvs db creation failed ${reset}"
        exit 1
fi
echo "SHVS database created successfully"

popd

AAS_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1
CMS_URL=https://$SYSTEM_IP:$CMS_PORT/cms/v1/
echo "Updating Populate users env ...."
ISECL_INSTALL_COMPONENTS=SHVS,SIH
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/populate-users.env

AAS_ADMIN_USERNAME=$(cat ~/authservice.env | grep ^AAS_ADMIN_USERNAME= | cut -d'=' -f2)
AAS_ADMIN_PASSWORD=$(cat ~/authservice.env | grep ^AAS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s@^\(IH_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
sed -i "s@^\(SHVS_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env

IHUB_SERVICE_USERNAME=$(cat ~/ihub.env | grep ^IHUB_SERVICE_USERNAME= | cut -d'=' -f2)
IHUB_SERVICE_PASSWORD=$(cat ~/ihub.env | grep ^IHUB_SERVICE_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(IHUB_SERVICE_USERNAME\s*=\s*\).*\$/\1$IHUB_SERVICE_USERNAME/" ~/populate-users.env
sed -i "s/^\(IHUB_SERVICE_PASSWORD\s*=\s*\).*\$/\1$IHUB_SERVICE_PASSWORD/" ~/populate-users.env

SHVS_SERVICE_USERNAME=$(cat ~/shvs.env | grep ^SHVS_ADMIN_USERNAME= | cut -d'=' -f2)
SHVS_SERVICE_PASSWORD=$(cat ~/shvs.env | grep ^SHVS_ADMIN_PASSWORD= | cut -d'=' -f2)
sed -i "s/^\(SHVS_SERVICE_USERNAME\s*=\s*\).*\$/\1$SHVS_SERVICE_USERNAME/" ~/populate-users.env
sed -i "s/^\(SHVS_SERVICE_PASSWORD\s*=\s*\).*\$/\1$SHVS_SERVICE_PASSWORD/" ~/populate-users.env

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

echo "Getting AAS Admin user token...."
INSTALL_ADMIN_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:$AAS_PORT/aas/v1/token -d '{"username": "'"$INSTALL_ADMIN_USERNAME"'", "password": "'"$INSTALL_ADMIN_PASSWORD"'"}'`
if [ $? -ne 0 ]; then
	echo "${red} could not get AAS Admin token ${reset}"
	exit 1
fi
popd

CMS_TLS_SHA=`cms tlscertsha384`
echo "Updating SGX Host Verification Service env...."
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
K8S_URL=https://$K8S_IP:$K8S_PORT/
sed -i "s@^\(SHVS_BASE_URL\s*=\s*\).*\$@\1$SHVS_URL@" ~/ihub.env
sed -i "s@^\(KUBERNETES_URL\s*=\s*\).*\$@\1$K8S_URL@" ~/ihub.env
if [[ "$OS" != "ubuntu" ]]; then
	OPENSTACK_AUTH_URL=http://$OPENSTACK_IP:$OPENSTACK_AUTH_PORT/
	OPENSTACK_PLACEMENT_URL=http://$OPENSTACK_IP:$OPENSTACK_PLACEMENT_PORT/
	sed -i "s@^\(OPENSTACK_AUTH_URL\s*=\s*\).*\$@\1$OPENSTACK_AUTH_URL@" ~/ihub.env
	sed -i "s@^\(OPENSTACK_PLACEMENT_URL\s*=\s*\).*\$@\1$OPENSTACK_PLACEMENT_URL@" ~/ihub.env
fi
sed -i "s@^\(TENANT\s*=\s*\).*\$@\1$TENANT@" ~/ihub.env

echo "Installing Integration HUB...."
./ihub-*.bin
ihub status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} Integration HUB Installation Failed ${reset}"
	exit 1
fi
echo "${green} Installed Integration HUB.... ${reset}"
