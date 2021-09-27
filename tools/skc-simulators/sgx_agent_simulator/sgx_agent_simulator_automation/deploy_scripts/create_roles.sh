#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

source agent.conf
if [ $? -ne 0 ]; then
        echo "${red} please set correct values in agent.conf ${reset}"
        exit 1
fi

AAS_BASE_URL=https://$AAS_IP:$AAS_PORT/aas/v1
CURL_OPTS="-s -k"
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/jwt"

mkdir -p /tmp/sgx_agent
tmpdir=$(mktemp -d -p /tmp/sgx_agent)

#Get the Custom Claims Creator Admin JWT Token
ADMIN_TOKEN=`curl $CURL_OPTS -H "$CONTENT_TYPE" -H "$ACCEPT" -X POST $AAS_BASE_URL/token -d \{\"username\":\"$CCC_ADMIN_USERNAME\",\"password\":\"$CCC_ADMIN_PASSWORD\"\}`
if [ $? -ne 0 ]; then
        echo "${red} failed to get custom claims creator admin token ${reset}"
        exit 1
fi

HW_UUID=`dmidecode -s system-uuid`

SECONDS_PER_DAY=86400
VALIDITY_SECONDS=$(( VALIDITY_DAYS * SECONDS_PER_DAY ))

cat > $tmpdir/request_data.json << EOF
{
    "subject": "$HW_UUID",
    "validity_seconds": $VALIDITY_SECONDS,
    "claims": {
        "roles": [{
            "service": "SCS",
            "name": "HostDataUpdater"
        },
        {
            "service": "SCS",
            "name": "HostDataReader"
        },
        {
            "service": "SHVS",
            "name": "HostDataUpdater"
        }]
    }
}
EOF

LONG_LIVED_TOKEN=`curl $CURL_OPTS -H "$CONTENT_TYPE" -H "$ACCEPT" -H "Authorization: Bearer $ADMIN_TOKEN" -X POST $AAS_BASE_URL/custom-claims-token -d @$tmpdir/request_data.json`
if [ $? -ne 0 ]; then
        echo "${red} failed to get long-lived token ${reset}"
        exit 1
fi
echo $LONG_LIVED_TOKEN

# cleanup
rm -rf $tmpdir
