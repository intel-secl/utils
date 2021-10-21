#!/bin/sh

export WAIT_INTERVAL=${WAIT_INTERVAL:-4}
export ITERATIONS=${ITERATIONS:-20}
i=0

# Waits for $ITERATIONS * $WAIT_INTERVAL for any service with given API with $URL
while [[ $i -lt $ITERATIONS ]]; do
  resp=$(curl -k -sw '%{http_code}' --connect-timeout 1 "$URL" -o /dev/null)
  if [[ $resp -eq 200 ]]; then
    version_resp=$(curl -k "$URL")
    version=$(echo $version_resp | grep -o 'Version: v[1-9].[0-9].[0-9]' | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
    if [[ "$version" == "$VERSION" ]]; then
      echo "$DEPEDENT_SERVICE_NAME $version is running"
      exit 0
    fi
  fi
  sleep $WAIT_INTERVAL
  i=$((i + 1))
  echo "Waiting for $DEPEDENT_SERVICE_NAME connection, attempt: $i"
done
if [ $i -eq $ITERATIONS ]; then
  echo "Error: timeout exceeded for job/container: $COMPONENT"
  exit 1
fi
