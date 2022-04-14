#set -x
TOKEN_KBS="kbs"
TOKEN_APS="aps"
TOKEN_FDA="fda"
AAS_PORT=30444

SYSTEM_IP=$2
AAS_USERNAME=$3
AAS_PASSWORD=$4

AAS_BASE_URL=https://$SYSTEM_IP:$AAS_PORT/aas/v1
CURRENT_PATH=`realpath .`/resources/custom-claim-token

CONTENT_TYPE="Content-Type: application/json"
ACCEPT="Accept: application/json"


if [ -z "$1" -o  -z "$2" -o -z "$3"  -o  -z "$4" ]; then
	echo "./$0 <$TOKEN_KBS/$TOKEN_FDA> <controlplane-ip> <aasuser> <aaspass>"
	exit 1
fi

if [ "$1" != $TOKEN_KBS ] && [ "$1" != $TOKEN_FDA ] && [ "$1" != $TOKEN_APS ]; then
	echo "Invalid token provided: ./$0 <$TOKEN_KBS/$TOKEN_FDA/$TOKEN_APS>"
	exit 1
fi

aas_token=`curl -k -H "$CONTENT_TYPE" -H "$ACCEPT" --data \{\"username\":\"$AAS_USERNAME\",\"password\":\"$AAS_PASSWORD\"\} $AAS_BASE_URL/token`

if [ "$1" = "$TOKEN_FDA" ]; then
	curl -H "Authorization: Bearer ${aas_token}"  -H "$CONTENT_TYPE" -k \
			-H "$ACCEPT" --data @$CURRENT_PATH/tcs-custom-claim-request.json  -o $CURRENT_PATH/tcs-custom-claim-response.json -w "%{http_code}" \
				$AAS_BASE_URL/custom-claims-token
	cat $CURRENT_PATH/tcs-custom-claim-response.json | grep  "^[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*$" || exit 1
	cat $CURRENT_PATH/tcs-custom-claim-response.json
fi

if [ "$1" = $TOKEN_KBS ]; then
	curl \
	     -H "Authorization: Bearer ${aas_token}"  \
             -H "$CONTENT_TYPE" \
	     -H "$ACCEPT" \
	     "$AAS_BASE_URL"/custom-claims-token \
	     --data @"$CURRENT_PATH"/kbs-custom-claim-request.json \
	     -o "$CURRENT_PATH"/kbs-custom-claim-response.json -k  
	cat $CURRENT_PATH/kbs-custom-claim-response.json | grep  "^[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*$" || exit 1
	cat $CURRENT_PATH/kbs-custom-claim-response.json
fi

if [ "$1" = $TOKEN_APS ]; then

	curl \
	     -H "Authorization: Bearer ${aas_token}"  \
             -H "$CONTENT_TYPE" \
	     -H "$ACCEPT" \
	     "$AAS_BASE_URL"/custom-claims-token \
	     --data @"$CURRENT_PATH"/aps-custom-claim-request.json \
	     -o "$CURRENT_PATH"/aps-custom-claim-response.json \
	     -k  
	cat $CURRENT_PATH/aps-custom-claim-response.json | grep  "^[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*\.[A-Za-z0-9\|_\|-]*$" || exit 1
	cat $CURRENT_PATH/aps-custom-claim-response.json
fi


