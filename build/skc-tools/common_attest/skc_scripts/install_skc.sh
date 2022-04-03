#!/bin/bash
source install_enterprise_skc.sh
if [ $? -ne 0 ]
then
        echo "${red} Basic components installation failed ${reset}"
        exit 1
fi

\cp -pf ./env/fds.env $HOME_DIR
\cp -pf ./env/ihub.env $HOME_DIR

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

echo "Uninstalling Feature Discovery Service...."
fds uninstall --purge
echo "Removing Feature Discovery Service Database...."
pushd $PWD
cd /usr/local/pgsql
sudo -u postgres dropdb $FDS_DB_NAME
echo "Uninstalling Integration HUB...."
ihub uninstall --purge --exec
popd

pushd $PWD
cd ~

echo "Creating FDS database....."
bash create_db.sh $FDS_DB_NAME $FDS_DB_USERNAME $FDS_DB_PASSWORD
if [ $? -ne 0 ]; then
        echo "${red} fds db creation failed ${reset}"
        exit 1
fi
echo "FDS database created successfully"

popd

AAS_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1
CMS_URL=https://$SYSTEM_IP:$CMS_PORT/cms/v1/
echo "Updating Populate users env ...."
ISECL_INSTALL_COMPONENTS=FDS,IHUB
sed -i "s@^\(ISECL_INSTALL_COMPONENTS\s*=\s*\).*\$@\1$ISECL_INSTALL_COMPONENTS@" ~/populate-users.env
sed -i "s@^\(AAS_API_URL\s*=\s*\).*\$@\1$AAS_URL@" ~/populate-users.env

sed -i "s/^\(AAS_ADMIN_USERNAME\s*=\s*\).*\$/\1$AAS_ADMIN_USERNAME/" ~/populate-users.env
sed -i "s/^\(AAS_ADMIN_PASSWORD\s*=\s*\).*\$/\1$AAS_ADMIN_PASSWORD/" ~/populate-users.env

sed -i "s@^\(IH_CERT_SAN_LIST\s*=\s*\).*\$@\1$SYSTEM_SAN@" ~/populate-users.env
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

echo "Getting AAS Admin user token...."
INSTALL_ADMIN_TOKEN=`curl --noproxy "*" -k -X POST https://$SYSTEM_IP:$AAS_PORT/aas/v1/token -d '{"username": "'"$INSTALL_ADMIN_USERNAME"'", "password": "'"$INSTALL_ADMIN_PASSWORD"'"}'`
if [ $? -ne 0 ]; then
	echo "${red} could not get AAS Admin token ${reset}"
	exit 1
fi
popd

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
cd $BINARY_DIR
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
sed -i '/^[^#]/ s/\(^.*HVS_BASE_URL.*$\)/#\ \1/' ~/ihub.env

echo "Installing Integration HUB...."
./ihub-*.bin
ihub status > /dev/null
if [ $? -ne 0 ]; then
	echo "${red} Integration HUB Installation Failed ${reset}"
	exit 1
fi
echo "${green} Installed Integration HUB.... ${reset}"
