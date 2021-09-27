#!/bin/bash
source ../config
if [ $? -ne 0 ]; then
	echo "${red} unable to read config variables ${reset}"
	exit 1
fi

# read from environment variables file if it exists
if [ -f ./kbs.conf ]; then
	echo "Reading Installation variables from $(pwd)/kbs.conf"
	source kbs.conf
	if [ $? -ne 0 ]; then
		echo "${red} please set correct values in kbs.conf ${reset}"
		exit 1
	fi
fi

CACERT_PATH=cmsca.pem
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"
AAS_BASE_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1

rm -rf output *response.* *debug.* *.log

response=`curl -s -k -H "Accept: application/x-pem-file" -o $CACERT_PATH -w %{http_code} https://$SYSTEM_IP:$CMS_PORT/cms/v1/ca-certificates`
if [ $? -ne 0 ] || [ $response -ne 200 ]; then
	echo "${red} Failed to get CMS CA certificate ${reset}"
	exit 1
fi

echo "${green} Fetched CMS Root CA Certificate ${reset}"

if [ "$OS" == "rhel" ]; then
	dnf -qy install jq || exit 1
elif [ "$OS" == "ubuntu" ]; then
	apt-get install jq -y || exit 1
fi

aas_token=`curl -s -k -H "$CONTENT_TYPE" -H "$ACCEPT" --data \{\"username\":\"$AAS_USERNAME\",\"password\":\"$AAS_PASSWORD\"\} $AAS_BASE_URL/token`
if [ $? -ne 0 ]; then
	echo "${red} Failed to get Authservice token ${reset}"
	exit 1
fi

echo "${green} Fetched Authservice Token ${reset}"

# Create EnterPriseAdmin User and assign the roles.
user_="\"username\":\"$ENTERPRISE_ADMIN\""
password_="\"password\":\"$ENTERPRISE_PASSWORD\""
response=`curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -o /dev/null -w %{http_code} --data \{$user_,$password_\} $http_header $AAS_BASE_URL/users`
if [[ $? -ne 0 || $response -ne 400 && $response -ne 201 ]]; then
	echo "${red} Failed to Create Enterprise Admin ${reset}"
	exit 1
fi

echo "${green} Enterprise Admin User Created ${reset}"

user_details=`curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -w %{http_code} $AAS_BASE_URL/users?name=$ENTERPRISE_ADMIN`
if [ $? -ne 0 ]; then
	echo "${red} Failed to get Enterprise Admin User Details from Authservice ${reset}"
	exit 1
fi
user_id=`echo $user_details| awk 'BEGIN{RS="user_id\":\""} {print $1}' | sed -n '2p' | awk 'BEGIN{FS="\",\"username\":\""} {print $1}'`

# createRoles("KMS","KeyCRUD","","permissions:["*:*:*"]")
response=`curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -o /dev/null -w %{http_code} --data \{\"service\":\"KBS\",\"name\":\"KeyCRUD\",\"permissions\":[\"*:*:*\"]\} $http_header $AAS_BASE_URL/roles`
if [[ $? -ne 0 || $response -ne 400 && $response -ne 201 ]]; then
	echo "${red} Failed to create Key Broker Key CRUD Roles ${reset}"
	exit 1
fi
role_details=`curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer $aas_token" -w %{http_code} $AAS_BASE_URL/roles?service=KBS\&name=KeyCRUD`
role_id1=`echo $role_details | cut -d '"' -f 4`

echo "${green} Key CRUD Role created for Enterprise Admin User ${reset}"

# map Key CRUD roles to enterprise admin
response=`curl -s -k -H "$CONTENT_TYPE" -H "Authorization: Bearer ${aas_token}" -w %{http_code} --data \{\"role_ids\":\[\"$role_id1\"\]\} -w %{http_code} $AAS_BASE_URL/users/$user_id/roles`
if [ $? -ne 0 ] || [ $response -ne 201 ]; then
	echo "${red} Failed to Map Key CRUD Roles to Enterprise Admin ${reset}"
	exit 1
fi

echo "${green} Mapped Key CRUD Role to Enterprise Admin User ${reset}"

# get updated user token
BEARER_TOKEN=`curl -s -k -H "$CONTENT_TYPE" -H "$ACCEPT" -H "Authorization: Bearer $aas_token" --data \{\"username\":\"$ENTERPRISE_ADMIN\",\"password\":\"$ENTERPRISE_PASSWORD\"\} $AAS_BASE_URL/token`
if [ $? -ne 0 ]; then
	echo "${red} Failed to Get Updated Enterprise Admin Token ${reset}"
	exit 1
fi
echo "${green} Fetching AuthService Token for Enterprise Admin ${reset}"

response=`curl -s -H "Authorization: Bearer ${BEARER_TOKEN}" -H "$CONTENT_TYPE" --cacert $CACERT_PATH \
	-H "$ACCEPT" --data @transfer_policy_request.json  -o transfer_policy_response.json -w "%{http_code}" \
	https://$SYSTEM_IP:$KBS_PORT/v1/key-transfer-policies 2>transfer_policy_debug.log`
if [ $? -ne 0 ] || [ $response -ne 201 ]; then
	echo "${red} Failed to Create Key Transfer Policy ${reset}"
exit 1
fi
transfer_policy_id=$(cat transfer_policy_response.json | jq '.id');

echo "${green} Key Transfer Policy Created ${reset}"

#create a RSA key
if [ "$1" = "reg" ]; then
	if [ -z "${KMIP_KEY_ID}" ]; then
		source gen_cert_key.sh
            printf "{
            \"key_information\":{
                    \"algorithm\":\"RSA\",
                    \"key_length\":3072,
                    \"key_string\":\"$(cat ${SERVER_PKCS8_KEY} | tr '\r\n' '@')\"
            },
                    \"transfer_policy_ID\": ${transfer_policy_id}
            }" > key_request.json

            sed -i "s/@/\\\n/g" key_request.json

        else
            printf "{
            \"key_information\":{
                    \"algorithm\":\"RSA\",
                    \"key_length\":3072,
                    \"kmip_key_id\":\"${KMIP_KEY_ID}\"
            },
                    \"transfer_policy_ID\": ${transfer_policy_id}
            }" > key_request.json

            sed -i "s/@/\\\n/g" key_request.json

        fi
else
# create a AES key
    printf "{
    \"key_information\":{
        \"algorithm\":\"AES\",
        \"key_length\":256
    },
    \"transfer_policy_ID\":${transfer_policy_id}
    }" > key_request.json
fi

response=`curl -s -H "Authorization: Bearer ${BEARER_TOKEN}" -H "$CONTENT_TYPE" --cacert $CACERT_PATH \
    -H "$ACCEPT" --data @key_request.json -o key_response.json -w "%{http_code}" \
    https://$SYSTEM_IP:$KBS_PORT/v1/keys 2>key_debug.log`
if [ $? -ne 0 ] || [ $response -ne 201 ]; then
	echo "${red} Failed to Create a Key ${reset}"
	exit 1
fi
key_id=$(cat key_response.json | jq '.key_information.id' | tr -d '""');

if [ "$1" = "reg" ]; then
	file_name=$(echo $key_id | sed -e "s|\"||g")
	if [ -z "${KMIP_KEY_ID}" ]; then
		mv output/server.cert output/$file_name.crt 2>/dev/null
		echo "${green} Key Certificate Path: $(realpath output/$file_name.crt) ${reset}"
	else
		mv ${SERVER_CERT} $file_name.crt 2>/dev/null
		echo "${green} Key Certificate Path: $(realpath $file_name.crt) ${reset}"
	fi
fi

echo "${green} Created Key: $key_id ${reset}"
