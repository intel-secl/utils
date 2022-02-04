#!/bin/bash
source config
if [ $? -ne 0 ]; then
	echo "unable to read config variables"
	exit 1
fi

source fdagent.conf
if [ $? -ne 0 ]; then
        echo "${red} please set correct values in fdagent.conf ${reset}"
        exit 1
fi

HW_UUID=`dmidecode -s system-uuid`

cat > tcs-custom-claims-request.json << EOF
{
    "subject": "$HW_UUID",
    "validity_seconds": 8640000,
    "claims": {
        "permissions": [
                {
                        "rules": [
                                "platforms:push:*",
                                "tcb_status:retrieve:*",
                                "platform_collateral:refresh:*"
                        ],
                        "service": "TCS"
                },
                {
                        "rules": [
                                "hosts:create:*"
                        ],

                        "service": "FDS"
                }
        ]
    }
}
EOF

AAS_BASE_URL=https://$AAS_IP:$AAS_PORT/aas/v1
CURL_OPTS="-k -H"
CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"

#Get the AAS Admin Token
aas_token=`curl $CURL_OPTS "$CONTENT_TYPE" -H "$ACCEPT" --data \{\"username\":\"$AAS_USERNAME\",\"password\":\"$AAS_PASSWORD\"\} $AAS_BASE_URL/token`

if [ $? -ne 0 ]; then
        echo "${red} failed to get AAS admin token ${reset}"
        exit 1
fi

curl -H "Authorization: Bearer ${aas_token}" -H "$CONTENT_TYPE" -k \
                        -H "$ACCEPT" --data @tcs-custom-claims-request.json  -o tcs-custom-claim-response.json -w "%{http_code}" \
                                $AAS_BASE_URL/custom-claims-token

echo -ne "\n"
LONG_LIVED_TOKEN=`cat tcs-custom-claim-response.json`
if [ $? -ne 0 ]; then
        echo "${red} failed to get long-lived token ${reset}"
        exit 1
fi
#echo $LONG_LIVED_TOKEN
