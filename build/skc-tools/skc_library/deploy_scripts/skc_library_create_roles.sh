#!/bin/bash
# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"

if [ "$OS" == "rhel" ]; then
	echo "${red} Unsupported OS. Please use Ubuntu 20.04 ${reset}"
	exit 1
elif [ "$OS" == "ubuntu" ]; then
	apt install -qy jq || exit 1
fi

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

source create_roles.conf
if [ $? -ne 0 ]; then
	echo " ${red} please set correct values in skc_library.conf ${reset}"
	exit 1
fi

CURL_OPTS="-s -k"
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/jwt"
SGX_DEFAULT_PATH=/etc/sgx_default_qcnl.conf
aas_url=https://$AAS_IP:$AAS_PORT/aas/v1

mkdir -p /tmp/skclib
tmpdir=$(mktemp -d -p /tmp/skclib)

Bearer_token=`curl $CURL_OPTS -H "$CONTENT_TYPE" -H "$ACCEPT" -X POST $aas_url/token -d \{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"\}`
if [ $? -ne 0 ]; then
	echo "${red} could not get AAS Admin token ${reset}"
	exit 1
fi

# This routine checks if skc_library user exists and returns user id
# it creates a new user if one does not exist
create_skclib_user()
{
cat > $tmpdir/user.json << EOF
{
"username":"$SKC_USER",
"password":"$SKC_USER_PASSWORD"
}
EOF
	# check if user already exists
	curl $CURL_OPTS -H "Authorization: Bearer ${Bearer_token}" -o $tmpdir/user_response.json -w "%{http_code}" $aas_url/users?name=$SKC_USER > $tmpdir/user_response.status
	if [ $? -ne 0 ]; then
		echo "${red} failed to check if skc_library user already exists ${reset}"
		exit 1
	fi
	len=$(jq '. | length' < $tmpdir/user_response.json)
	if [ $len -ne 0 ]; then
		user_id=$(jq -r '.[0] .user_id' < $tmpdir/user_response.json)
	else
		curl $CURL_OPTS -X POST -H "$CONTENT_TYPE" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/user.json -o $tmpdir/user_response.json -w "%{http_code}" $aas_url/users > $tmpdir/user_response.status
		if [ $? -ne 0 ]; then
			echo "${red} failed to create skc_library user ${reset}"
			exit 1
		fi

		local status=$(cat $tmpdir/user_response.status)
		if [ $status -ne 201 ]; then
			return 1
		fi

		if [ -s $tmpdir/user_response.json ]; then
			user_id=$(jq -r '.user_id' < $tmpdir/user_response.json)
			if [ -n "$user_id" ]; then
				echo "${green} Created skc_library user, id: $user_id ${reset}"
			fi
		fi
	fi
}

# This routine checks if skc_library CertApprover/KeyTransfer roles exist and returns those role ids
# it creates above roles if not present in AAS db
create_roles()
{
cat > $tmpdir/certroles.json << EOF
{
	"service": "CMS",
	"name": "CertApprover",
	"context": "CN=$SKC_USER;CERTTYPE=TLS-Client"
}
EOF

cat > $tmpdir/keytransferroles.json << EOF
{
	"service": "KBS",
	"name": "KeyTransfer",
	"context": "permissions=$PERMISSION"
}
EOF
	# check if CertApprover role already exists
	curl $CURL_OPTS -H "Authorization: Bearer ${Bearer_token}" -o $tmpdir/role_response.json -w "%{http_code}" $aas_url/roles?contextContains=CN=$SKC_USER > $tmpdir/role_response.status
	if [ $? -ne 0 ]; then
		echo "${red} failed to check if CertApprover role exists ${reset}"
		exit 1
	fi

	len=$(jq '. | length' < $tmpdir/role_response.json)
        if [ $len -ne 0 ]; then
                cms_role_id=$(jq -r '.[0] .role_id' < $tmpdir/role_response.json)
        else
		curl $CURL_OPTS -X POST -H "$CONTENT_TYPE" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/certroles.json -o $tmpdir/role_response.json -w "%{http_code}" $aas_url/roles > $tmpdir/role_response-status.json
		if [ $? -ne 0 ]; then
			echo "${red} failed to create CertApprover role for skc_library user ${reset}"
			exit 1
		fi

		local status=$(cat $tmpdir/role_response-status.json)
		if [ $status -ne 201 ]; then
			return 1
		fi

		if [ -s $tmpdir/role_response.json ]; then
			cms_role_id=$(jq -r '.role_id' < $tmpdir/role_response.json)
		fi
	fi

	# check if KeyTransfer role already exists
	curl $CURL_OPTS -H "Authorization: Bearer ${Bearer_token}" -o $tmpdir/role_resp.json -w "%{http_code}" $aas_url/roles?name=KeyTransfer > $tmpdir/role_resp.status
	if [ $? -ne 0 ]; then
		echo "${red} failed to check if KeyTransfer role exists ${reset}"
		exit 1
	fi

	len=$(jq '. | length' < $tmpdir/role_resp.json)
	if [ $len -ne 0 ]; then
		kbs_role_id=$(jq -r '.[0] .role_id' < $tmpdir/role_resp.json)
	else
		curl $CURL_OPTS -X POST -H "$CONTENT_TYPE" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/keytransferroles.json -o $tmpdir/role_resp.json -w "%{http_code}" $aas_url/roles > $tmpdir/role_resp-status.json
		if [ $? -ne 0 ]; then
			echo "${red} failed to create KeyTransfer role for skc_library user ${reset}"
			exit 1
		fi

		local status=$(cat $tmpdir/role_resp-status.json)
		if [ $status -ne 201 ]; then
			return 1
		fi

		if [ -s $tmpdir/role_resp.json ]; then
			kbs_role_id=$(jq -r '.role_id' < $tmpdir/role_resp.json)
		fi
	fi
	ROLE_ID_TO_MAP=`echo \"$cms_role_id\",\"$kbs_role_id\"`
}

# Map skc_library User to Roles
mapUser_to_role() {
cat >$tmpdir/mapRoles.json <<EOF
{
	"role_ids": [$ROLE_ID_TO_MAP]
}
EOF
	curl $CURL_OPTS -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${Bearer_token}" --data @$tmpdir/mapRoles.json -o $tmpdir/mapRoles_response.json -w "%{http_code}" $aas_url/users/$user_id/roles > $tmpdir/mapRoles_response-status.json
	if [ $? -ne 0 ]; then
		echo "${red} failed to map CertApprover/KeyTransfer role to skc_library user ${reset}"
		exit 1
	fi

	local actual_status=$(cat $tmpdir/mapRoles_response-status.json)
	if [ $actual_status -ne 201 ]; then
		return 1
	fi
}

SKCLIB_SETUP="create_skclib_user create_roles mapUser_to_role"
status=
for api in $SKCLIB_SETUP
do
	eval $api
	status=$?
	if [ $status -ne 0 ]; then
		echo "${red} skc_library user/roles creation failed: $api ${reset}"
		exit 1
	fi
done

# Get Token for SKC_Library user
curl $CURL_OPTS -X POST -H "$CONTENT_TYPE" -H "$ACCEPT" --data @$tmpdir/user.json -o $tmpdir/skclib_token-response.json -w "%{http_code}" $aas_url/token > $tmpdir/skclibtoken-response.status
if [ $? -ne 0 ]; then
	echo "${red} failed to get aas token for skc_library user ${reset}"
	exit 1
fi

status=$(cat $tmpdir/skclibtoken-response.status)
if [ $status -ne 200 ]; then
	echo "${red} Couldn't get bearer token for skc_library user ${reset}"
	exit 1
else
	SKC_TOKEN=`cat $tmpdir/skclib_token-response.json`
	echo $SKC_TOKEN
fi

echo "${green} skc_library user and roles created ${reset}"
rm -rf $tmpdir
