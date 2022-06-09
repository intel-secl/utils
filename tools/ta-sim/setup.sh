#!/bin/bash

TA_SIMULATOR_HOME=/opt/go-ta-simulator
TA_SIMULATOR_LOGS=$TA_SIMULATOR_HOME/logs
mkdir -p $TA_SIMULATOR_HOME
mkdir -p $TA_SIMULATOR_LOGS

DEFAULT_PRIVACY_CA_CERT_PATH=/etc/hvs/certs/trustedca/privacy-ca/privacy-ca-cert.pem
DEFAULT_PRIVACY_CA_KEY_PATH=/etc/hvs/trusted-keys/privacy-ca.key
DEFAULT_SIM_TLS_CERT_CN="TA Simulator TLS Certificate"
DEFAULT_SIM_TLS_CERT_SAN="*"
DEFAULT_CMS_PORT=8445
DEFAULT_AAS_PORT=8444
DEFAULT_HVS_PORT=8443
DEFAULT_TA_PORT=1443
DEFAULT_TA_SERVICE_MODE=http

PRIVACY_CA_CERT_PATH="${PRIVACY_CA_CERT_PATH:-$DEFAULT_PRIVACY_CA_CERT_PATH}"
PRIVACY_CA_KEY_PATH="${PRIVACY_CA_KEY_PATH:-$DEFAULT_PRIVACY_CA_KEY_PATH}"
SIM_TLS_CERT_CN="${SIM_TLS_CERT_CN:-$DEFAULT_SIM_TLS_CERT_CN}"
SIM_TLS_CERT_SAN="${SIM_TLS_CERT_SAN:-$DEFAULT_SIM_TLS_CERT_SAN}"
CMS_PORT="${CMS_PORT:-$DEFAULT_CMS_PORT}"
AAS_PORT="${AAS_PORT:-$DEFAULT_AAS_PORT}"
HVS_PORT="${HVS_PORT:-$DEFAULT_HVS_PORT}"
TA_PORT="${TA_PORT:-$DEFAULT_TA_PORT}"
TA_SERVICE_MODE="${TA_SERVICE_MODE:-DEFAULT_TA_SERVICE_MODE}"

function GetValue()
{

	local re="\"($1)\":\"([^\"]*)\""
	if [[ $2 =~ $re ]]; then
		echo "${BASH_REMATCH[2]}"
	fi
}



if [ -f ~/go-ta-sim.env ]; then
  echo "Loading environment variables from  $(cd ~ && pwd)/go-ta-sim.env"
  . ~/go-ta-sim.env
  env_file_exports=$(cat ~/go-ta-sim.env | grep -E '^[A-ZX0-9_]+\s*=' | cut -d = -f 1)
fi

cp ./* $TA_SIMULATOR_HOME/ -r
cd $TA_SIMULATOR_HOME
mkdir -p repository


# first make sure that we can create the
if [ -z "$AIK_CERT_PATH" ] || [ -z  "$AIK_KEY_PATH" ]; then
    echo "Creating aik certificate and signing it with Privacy CA..."
    openssl req -out ./configuration/aik_req.csr -newkey rsa:2048 -nodes -keyout ./configuration/aik.key.pem -subj "/CN=HVS Privacy Certificate" -sha256
    echo "authorityKeyIdentifier=keyid,issuer" > ./configuration/v3.ext
    echo "basicConstraints=CA:FALSE" >> ./configuration/v3.ext
    echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" >> v3.ext
    openssl x509 -req -days 365 -extfile ./configuration/v3.ext -in ./configuration/aik_req.csr -CA "$PRIVACY_CA_CERT_PATH" -CAkey "$PRIVACY_CA_KEY_PATH" -CAcreateserial -out ./configuration/aik.cert.pem
    if [ $? -ne 0 ]; then
      echo "ERROR - could not create create AIK certificate... Simulator will not work without it"
      echo "configuration/aik.req.csr can be used to create AIK certificate with Privacy CA. set AIK_CERT_PATH and AIK_KEY_PATH before running installation"
      exit 1
    fi
    rm -rf ./configuration/aik_req.csr
    rm -rf ./configuration/v3.ext

fi

[ -z "$TA_SIM_IP" ] && read -p "Enter the TA simulator ip (ex: 10.1.2.3):" TA_SIM_IP
sed -i "s/^\(IP\.1\s*=\s*\).*\$/\1$TA_SIM_IP/" configuration/opensslSAN.conf
sed -i "s/^\(SimulatorIP\s*:\s*\).*\$/\1$TA_SIM_IP/" configuration/config.yml

[ -z "$AAS_IP" ] && read -p "Enter the AAS ip (ex: 10.1.2.3):" AAS_IP
[ -z "$CMS_IP" ] && read -p "Enter the CMS ip (ex: 10.1.2.3) (Leave empty to use AAS IP - $AAS_IP):" CMS_IP
if [ -z "$CMS_IP" ]; then
  CMS_IP=$AAS_IP
fi

[ -z "$HVS_IP" ] && read -p "Enter the HVS ip (ex: 10.1.2.3) (Leave empty to use AAS IP - $AAS_IP):" HVS_IP
if [ -z "$HVS_IP" ]; then
  HVS_IP=$AAS_IP
fi

if [ "$TA_SERVICE_MODE" == "outbound" ]; then
  [ -z "$NATS_SERVERS" ] && read -p "Enter NATS server IP (ex: 10.1.2.3:4222) :" NATS_SERVERS
  [ -z "$TA_HOST_ID" ] && read -p "Enter TA host ID):" TA_HOST_ID
  echo -e "NatsServers : "$NATS_SERVERS >> configuration/config.yml
  echo -e "TaHostID : "$TA_HOST_ID >> configuration/config.yml
else
  [ -z "$TA_IP" ] && read -p "Enter the TA ip (ex: 10.1.2.3) (Leave empty to use the default response files):" TA_IP
  TA_URL=https://$TA_IP:$TA_PORT
fi

sed -i "s/^\(HvsApiUrl\s*:\s*\).*\$/\1https:\/\/$HVS_IP:$HVS_PORT\/hvs\/v2\//" configuration/config.yml
sed -i "s/^\(AasApiUrl\s*:\s*\).*\$/\1https:\/\/$AAS_IP:$AAS_PORT\/aas\/v1\//" configuration/config.yml
sed -i "s/^\(CmsApiUrl\s*:\s*\).*\$/\1https:\/\/$CMS_IP:$CMS_PORT\/cms\/v1\//" configuration/config.yml

[ -z "$AAS_USERNAME" ] && read -p "Enter the AAS Admin username (Also, has access to all TA and VS APIs):" AAS_USERNAME
sed -i "s/^\(ApiUserName\s*:\s*\).*\$/\1$AAS_USERNAME/" configuration/config.yml

[ -z "$AAS_PASSWORD" ] && read -p "Enter the AAS Admin pass:" AAS_PASSWORD
sed -i "s/^\(ApiUserPassword\s*:\s*\).*\$/\1$AAS_PASSWORD/" configuration/config.yml

echo "Setting up environment............"
echo "Downloading token that can be used get/add certificate role..."
TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:$AAS_PORT/aas/v1/token -d '{"username": "'"$AAS_USERNAME"'", "password": "'"$AAS_PASSWORD"'" }'`
RESPONSE=`curl --noproxy "*" -k https://$AAS_IP:$AAS_PORT/aas/v1/users?name=$AAS_USERNAME -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json'`
USER_ID=$(GetValue user_id $RESPONSE)
if [ -z "$USER_ID" ]; then
  echo "ERROR - cannot get user id"
  exit 1
fi
echo userid:$USER_ID

# Get the RoleID
echo "Checking if role exists for retrieving certificate.. "
RESPONSE=`curl --noproxy "*" -G --data-urlencode service="CMS" --data-urlencode name="CertApprover" --data-urlencode context="CN=$SIM_TLS_CERT_CN;SAN=$SIM_TLS_CERT_SAN;certType=TLS" --insecure https://$AAS_IP:$AAS_PORT/aas/v1/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json'`
ROLE_ID=$(GetValue role_id $RESPONSE)
if [ -z $ROLE_ID ]; then
  echo "Certificate Request roles does not exist. Creating new role.."
	RESPONSE=`curl --noproxy "*" -k  -X POST https://$AAS_IP:$AAS_PORT/aas/v1/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"service": "CMS","name": "CertApprover","context": "CN='"$SIM_TLS_CERT_CN"';SAN='$SIM_TLS_CERT_SAN';certType=TLS"}'`
	echo Response:$RESPONSE
	ROLE_ID=$(GetValue role_id $RESPONSE)
fi
if [ -z "$ROLE_ID" ]; then
  echo "ERROR - cannot get role id"
  exit 1
fi

echo role_id:$ROLE_ID
# assign user to role id. Don't care about return code..
echo "Adding certificate role to user in case user does not already have it...."
curl --noproxy "*" -k  -X POST https://$AAS_IP:$AAS_PORT/aas/v1/users/$USER_ID/roles -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"role_ids": ["'"$ROLE_ID"'"]}'

echo "Obtaining new token with additional role for user..."
TOKEN=`curl --noproxy "*" -k -X POST https://$AAS_IP:$AAS_PORT/aas/v1/token -d '{"username": "'"$AAS_USERNAME"'", "password": "'"$AAS_PASSWORD"'" }'`

echo "Token with role to request certificate : $TOKEN"

echo "Creating certificate request..."
CSR_FILE=configuration/sslcert.csr
openssl req -out $CSR_FILE -newkey rsa:3072 -nodes -keyout configuration/key.pem -config configuration/opensslSAN.conf -subj "/CN=$SIM_TLS_CERT_SAN" -sha384
echo "Requesting token from CMS...."
curl --noproxy "*" -k -X POST https://$CMS_IP:$CMS_PORT/cms/v1/certificates?certType=TLS -H 'Accept: application/x-pem-file' -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/x-pem-file' --data-binary "@$CSR_FILE" > configuration/cert.pem

if [ "$TA_SERVICE_MODE" == "outbound" ] && [ -n "$NATS_SERVERS" ] && [ -n "$TA_HOST_ID" ]; then
  echo "Requesting Nats credentials for TA simulator as publisher from AAS...."
  curl --noproxy "*" -X POST -H "Authorization: Bearer $TOKEN" -H "Accept:application/xml" -H "Content-Type:application/json" https://$AAS_IP:$AAS_PORT/aas/v1/credentials -k -d '{"type" : "TA","parameters" : {"host-id" : ""}}' > ./repository/ta-sim.creds
  echo "Requesting Nats credentials to download data from TA..."
  curl --noproxy "*" -X POST -H "Authorization: Bearer $TOKEN" -H "Accept:application/xml" -H "Content-Type:application/json" https://$AAS_IP:$AAS_PORT/aas/v1/credentials -k -d '{"type" : "HVS","parameters" : {"host-id" : ""}}' > ./repository/ta-sub.creds
  echo "Downloading data from Trust Agent in outbound mode..."
  ./ta-sim get-host-data-from-nats
elif [ "$TA_SERVICE_MODE" == "http" ]; then
    if [ -n "$TA_IP" ]; then
      echo "Downloading data from Trust Agent in http mode..."
      curl --noproxy "*" -H "Authorization: Bearer $TOKEN" -H "Accept:application/json" $TA_URL/v2/host -k > ./repository/host_info.json
      FILE_SIZE=`wc -c < ./repository/host_info.json`
      if [ -z "$FILE_SIZE" ] || [[ $FILE_SIZE == 0 ]]; then
        echo "ERROR : Installation incomplete - unable to download content from Trust Agent at $TA_IP:$TA_PORT"
        exit 1
      fi
      curl --noproxy "*" -X POST -H "Authorization: Bearer $TOKEN" -H "Accept:application/xml" -H "Content-Type:application/json" $TA_URL/v2/tpm/quote -k -d '{"nonce":"+c4ZEmco4aj1G5dTXQvjIMGFd44=","pcrs":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23],"pcrbanks":["SHA1", "SHA256", "SHA384"]}' > ./repository/quote.xml
    else
      echo "Using sample host-info and quote in http mode"
    fi
else
  echo "ERROR: TA IP address or NATS_SERVER information with TA host ID must be given to download data from a trustagent"
fi

echo "Done"

chmod 755 $TA_SIMULATOR_HOME/*.sh
chmod 755 $TA_SIMULATOR_HOME/ta-sim
echo "Trust Agent Simulator installation completed"

if [ -z "$BINDING_KEY_CERT_PATH" ]; then
  echo "creating binding key certificate as no path to valid binding key provided"
  $TA_SIMULATOR_HOME/ta-sim create-binding-key-cert --pca-cert=$PRIVACY_CA_CERT_PATH --pca-key=$PRIVACY_CA_KEY_PATH
  if [ $? -ne 0 ]; then
    cat "Binding key certificate does not exist" > $TA_SIMULATOR_HOME/configuration/bk.cert
    echo "ERROR: failed to create binding key certificate. TA simulator will still function - but APIs such as WLS get flavor-key will not work"
    echo "The ta-sim binary can be used to generate the binding key certificate as follows"
    echo "\t ./ta-sim create-binding-key-cert --pca-cert=/root/privacy-ca-cert.pem --pca-key=/root/privacy-ca.key"
  fi
else
  cp $BINDING_KEY_CERT_PATH $TA_SIMULATOR_HOME/configuration/bk.cert
fi