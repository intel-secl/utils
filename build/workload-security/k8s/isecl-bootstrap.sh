#!/bin/bash

source isecl-k8s.env
if [ $? != 0 ]; then
  echo "failed to source isecl-k8s.env"
fi

CMS_TLS_CERT_SHA384=""
AAS_BOOTSTRAP_TOKEN=""
BEARER_TOKEN=""

HOME_DIR=$(pwd)
AAS_DIR=$HOME_DIR/aas

AAS="aas"
CMS="cms"
HVS="hvs"
IHUB="ihub"
KBS="kbs"
WLS="wls"
TAGENT="tagent"
WLAGENT="wlagent"
ISECL_SCHEDULER="isecl-k8s-scheduler"
ISECL_CONTROLLER="isecl-k8s-controller"

check_k8s_distribution() {
  if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    KUBECTL=microk8s.kubectl
  elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    KUBECTL=kubectl
  else
    echo "K8s Distribution \"$K8S_DISTRIBUTION\" not supported"
  fi
}

check_mandatory_variables() {
  IFS=',' read -ra ADDR <<<"$2"
  for env_var in "${ADDR[@]}"; do
    if [[ ! -v "${env_var}" ]]; then
      echo "$env_var is not set for service: $1"
      exit 1
    fi
  done
}

deploy_cms() {

  echo "----------------------------------------------------"
  echo "|      DEPLOY: CERTIFICATE-MANAGEMENT-SERVICE      |"
  echo "----------------------------------------------------"

  cd cms/

  # update configMap
  sed -i "s/SAN_LIST:.*/SAN_LIST: $CMS_SAN_LIST/g" configMap.yml
  sed -i "s/AAS_TLS_SAN:.*/AAS_TLS_SAN: $AAS_SAN_LIST/g" configMap.yml

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=cms -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "CERTIFICATE-MANAGEMENT-SERVICE DEPLOYED SUCCESSFULLY"
  else
    echo "ERROR: Failed to deploy CMS"
    echo "Exiting with error..."
    exit 1
  fi
  echo "Waiting for CMS to bootstrap itself..."
  sleep 20
  cd $HOME_DIR
}

get_cms_tls_cert_sha384() {
  cms_pod=$($KUBECTL get pod -n isecl -l app=cms -o jsonpath="{.items[0].metadata.name}")
  CMS_TLS_CERT_SHA384=$($KUBECTL exec -n isecl --stdin $cms_pod -- cms tlscertsha384)
}

get_aas_bootstrap_token() {
  cms_pod=$($KUBECTL get pod -n isecl -l app=cms -o jsonpath="{.items[0].metadata.name}")
  AAS_BOOTSTRAP_TOKEN=$($KUBECTL exec -n isecl --stdin $cms_pod -- cms setup cms-auth-token --force | grep "JWT Token:" | awk '{print $3}')
  $KUBECTL create secret generic aas-bootstrap-token -n isecl --from-literal=BEARER_TOKEN=$AAS_BOOTSTRAP_TOKEN --save-config --dry-run=client -o yaml | $KUBECTL apply -f -
}

deploy_authservice() {

  get_cms_tls_cert_sha384
  get_aas_bootstrap_token
  echo "----------------------------------------------------"
  echo "|    DEPLOY: AUTHENTICATION-AUTHORIZATION-SERVICE  |"
  echo "----------------------------------------------------"

  required_variables="AAS_ADMIN_USERNAME,AAS_ADMIN_PASSWORD,AAS_DB_HOSTNAME,AAS_DB_NAME,AAS_DB_PORT,AAS_DB_SSLMODE,AAS_SAN_LIST"
  check_mandatory_variables $AAS $required_variables

  cd aas/

  # update configMap and secrets
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: $CMS_TLS_CERT_SHA384/g" configMap.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: $CMS_BASE_URL#g" configMap.yml
  sed -i "s/SAN_LIST:.*/SAN_LIST: $AAS_SAN_LIST/g" configMap.yml
  sed -i "s/AAS_DB_HOSTNAME:.*/AAS_DB_HOSTNAME: $AAS_DB_HOSTNAME/g" configMap.yml
  sed -i "s/AAS_DB_NAME:.*/AAS_DB_NAME: $AAS_DB_NAME/g" configMap.yml
  sed -i "s/AAS_DB_PORT:.*/AAS_DB_PORT: \"$AAS_DB_PORT\"/g" configMap.yml
  sed -i "s/AAS_DB_SSLMODE:.*/AAS_DB_SSLMODE: $AAS_DB_SSLMODE/g" configMap.yml
  nats_account_name_exists=$(grep "NATS_ACCOUNT_NAME" configMap.yml)
  if [ ! -z "${NATS_ACCOUNT_NAME}" ] && [ -z "$nats_account_name_exists" ]; then
    echo "  NATS_ACCOUNT_NAME: $NATS_ACCOUNT_NAME" >>configMap.yml
    echo "hi"
  fi
  echo $AAS_DB_USERNAME
  sed -i "s/AAS_DB_USERNAME:.*/AAS_DB_USERNAME: $AAS_DB_USERNAME/g" secrets.yml
  sed -i "s/AAS_DB_PASSWORD:.*/AAS_DB_PASSWORD: $AAS_DB_PASSWORD/g" secrets.yml
  sed -i "s/AAS_ADMIN_USERNAME:.*/AAS_ADMIN_USERNAME: $AAS_ADMIN_USERNAME/g" secrets.yml
  sed -i "s/AAS_ADMIN_PASSWORD:.*/AAS_ADMIN_PASSWORD: $AAS_ADMIN_PASSWORD/g" secrets.yml

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=aas -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "AUTHENTICATION-AUTHORIZATION-SERVICE DEPLOYED SUCCESSFULLY"
  else
    echo "ERROR: Failed to deploy AAS"
    echo "Exiting with error..."
    exit 1
  fi

  echo "Waiting for AAS to bootstrap itself..."
  sleep 60
  cd $HOME_DIR
}

get_bearer_token() {

  aas_scripts_dir=$AAS_DIR/scripts
  echo "Running populate-users script"
  sed -i "s/ISECL_INSTALL_COMPONENTS=.*/ISECL_INSTALL_COMPONENTS=$ISECL_INSTALL_COMPONENTS/g" $aas_scripts_dir/populate-users.env
  sed -i "s#CMS_BASE_URL=.*#CMS_BASE_URL=$CMS_BASE_URL#g" $aas_scripts_dir/populate-users.env
  sed -i "s#AAS_API_URL=.*#AAS_API_URL=$AAS_API_CLUSTER_ENDPOINT_URL#g" $aas_scripts_dir/populate-users.env
  sed -i "s/HVS_CERT_SAN_LIST=.*/HVS_CERT_SAN_LIST=$HVS_CERT_SAN_LIST/g" $aas_scripts_dir/populate-users.env
  sed -i "s/IH_CERT_SAN_LIST=.*/IH_CERT_SAN_LIST=$IH_CERT_SAN_LIST/g" $aas_scripts_dir/populate-users.env
  sed -i "s/KBS_CERT_SAN_LIST=.*/KBS_CERT_SAN_LIST=$KBS_CERT_SAN_LIST/g" $aas_scripts_dir/populate-users.env
  sed -i "s/WLS_CERT_SAN_LIST=.*/WLS_CERT_SAN_LIST=$WLS_CERT_SAN_LIST/g" $aas_scripts_dir/populate-users.env
  sed -i "s#TA_CERT_SAN_LIST=.*#TA_CERT_SAN_LIST=$TA_CERT_SAN_LIST#g" $aas_scripts_dir/populate-users.env
  sed -i "s#NATS_CERT_SAN_LIST=.*#NATS_CERT_SAN_LIST=$NATS_CERT_SAN_LIST#g" $aas_scripts_dir/populate-users.env

  sed -i "s/AAS_ADMIN_USERNAME=.*/AAS_ADMIN_USERNAME=$AAS_ADMIN_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/AAS_ADMIN_PASSWORD=.*/AAS_ADMIN_PASSWORD=$AAS_ADMIN_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/IHUB_SERVICE_USERNAME=.*/IHUB_SERVICE_USERNAME=$IHUB_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/IHUB_SERVICE_PASSWORD=.*/IHUB_SERVICE_PASSWORD=$IHUB_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/WLS_SERVICE_USERNAME=.*/WLS_SERVICE_USERNAME=$WLS_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/WLS_SERVICE_PASSWORD=.*/WLS_SERVICE_PASSWORD=$WLS_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/WLA_SERVICE_USERNAME=.*/WLA_SERVICE_USERNAME=$WLA_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/WLA_SERVICE_PASSWORD=.*/WLA_SERVICE_PASSWORD=$WLA_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/WPM_SERVICE_USERNAME=.*/WPM_SERVICE_USERNAME=$WPM_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/WPM_SERVICE_PASSWORD=.*/WPM_SERVICE_PASSWORD=$WPM_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/HVS_SERVICE_USERNAME=.*/HVS_SERVICE_USERNAME=$HVS_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/HVS_SERVICE_PASSWORD=.*/HVS_SERVICE_PASSWORD=$HVS_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/KBS_SERVICE_USERNAME=.*/KBS_SERVICE_USERNAME=$KBS_SERVICE_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/KBS_SERVICE_PASSWORD=.*/KBS_SERVICE_PASSWORD=$KBS_SERVICE_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/INSTALL_ADMIN_USERNAME=.*/INSTALL_ADMIN_USERNAME=$INSTALL_ADMIN_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/INSTALL_ADMIN_PASSWORD=.*/INSTALL_ADMIN_PASSWORD=$INSTALL_ADMIN_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/GLOBAL_ADMIN_USERNAME=.*/GLOBAL_ADMIN_USERNAME=$GLOBAL_ADMIN_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/GLOBAL_ADMIN_PASSWORD=.*/GLOBAL_ADMIN_PASSWORD=$GLOBAL_ADMIN_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/CCC_ADMIN_USERNAME=.*/CCC_ADMIN_USERNAME=$CCC_ADMIN_USERNAME/g" $aas_scripts_dir/populate-users.env
  sed -i "s/CCC_ADMIN_PASSWORD=.*/CCC_ADMIN_PASSWORD=$CCC_ADMIN_PASSWORD/g" $aas_scripts_dir/populate-users.env

  sed -i "s/CUSTOM_CLAIMS_COMPONENTS=.*/CUSTOM_CLAIMS_COMPONENTS=$CUSTOM_CLAIMS_COMPONENTS/g" $aas_scripts_dir/populate-users.env
  sed -i "s/CUSTOM_CLAIMS_TOKEN_VALIDITY_SECS=.*/CUSTOM_CLAIMS_TOKEN_VALIDITY_SECS=$CUSTOM_CLAIMS_TOKEN_VALIDITY_SECS/g" $aas_scripts_dir/populate-users.env

  # TODO: need to check if this can be fetched from builds instead of bundling the script here
  chmod +x $aas_scripts_dir/populate-users
  $aas_scripts_dir/populate-users --answerfile $aas_scripts_dir/populate-users.env >$aas_scripts_dir/populate-users.log

  BEARER_TOKEN=$(grep "Token for User: $INSTALL_ADMIN_USERNAME" $aas_scripts_dir/populate-users.log -A 2 | grep BEARER_TOKEN | cut -d '=' -f2)
  echo "Install token: $BEARER_TOKEN"
  $KUBECTL create secret generic bearer-token -n isecl --from-literal=BEARER_TOKEN=$BEARER_TOKEN --save-config --dry-run=client -o yaml | $KUBECTL apply -f -

  if [ ! -z "$NATS_SERVERS" ]; then
    CC_TA_TOKEN=$(grep "Custom Claims Token For TA" $aas_scripts_dir/populate-users.log -A 2 | grep BEARER_TOKEN | cut -d '=' -f2)
  fi
}

deploy_hvs() {

  cd $HOME_DIR/hvs

  echo "-------------------------------------------------------------"
  echo "|            DEPLOY: HOST-VERIFICATION-SERVICE              |"
  echo "-------------------------------------------------------------"

  # The variables BEARER_TOKEN and CMS_TLS_CERT_SHA384 get loaded with below functions, this required if we want to deploy individual hvs service
  get_bearer_token
  get_cms_tls_cert_sha384

  required_variables="CMS_TLS_CERT_SHA384,HVS_SERVICE_USERNAME,HVS_SERVICE_PASSWORD,HVS_CERT_SAN_LIST,AAS_API_URL,CMS_BASE_URL,HVS_DB_HOSTNAME,HVS_DB_PORT,HVS_DB_NAME"
  check_mandatory_variables $SHVS $required_variables

  # update hvs configMap & secrets
  if [[ -z "${NATS_SERVERS}" ]]; then
    sed -i "s/NATS_SERVERS:.*//g" configMap.yml
  else
    sed -i "s#NATS_SERVERS:.*#NATS_SERVERS: ${NATS_SERVERS}#g" configMap.yml
  fi
  sed -i "s/HVS_SERVICE_USERNAME:.*/HVS_SERVICE_USERNAME: ${HVS_SERVICE_USERNAME}/g" secrets.yml
  sed -i "s/HVS_SERVICE_PASSWORD:.*/HVS_SERVICE_PASSWORD: ${HVS_SERVICE_PASSWORD}/g" secrets.yml
  sed -i "s/HVS_DB_USERNAME:.*/HVS_DB_USERNAME: ${HVS_DB_USERNAME}/g" secrets.yml
  sed -i "s/HVS_DB_PASSWORD:.*/HVS_DB_PASSWORD: ${HVS_DB_PASSWORD}/g" secrets.yml

  sed -i "s/SAN_LIST:.*/SAN_LIST: ${HVS_CERT_SAN_LIST}/g" configMap.yml
  sed -i "s/HVS_DB_HOSTNAME:.*/HVS_DB_HOSTNAME: ${HVS_DB_HOSTNAME}/g" configMap.yml
  sed -i "s/HVS_DB_NAME:.*/HVS_DB_NAME: ${HVS_DB_NAME}/g" configMap.yml
  sed -i "s/HVS_DB_PORT:.*/HVS_DB_PORT: \"$HVS_DB_PORT\"/g" configMap.yml
  sed -i "s/BEARER_TOKEN=.*/BEARER_TOKEN=${BEARER_TOKEN}/g" secrets.txt
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: ${CMS_TLS_CERT_SHA384}/g" configMap.yml
  sed -i "s#AAS_API_URL:.*#AAS_API_URL: ${AAS_API_URL}#g" configMap.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: ${CMS_BASE_URL}#g" configMap.yml
  sed -i "s/HVS_DB_HOSTNAME:.*/HVS_DB_HOSTNAME: ${HVS_DB_HOSTNAME}/g" configMap.yml

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=hvs -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "HOST-VERIFICATION-SERVICE DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying HVS"
    echo "Exiting with error..."
    exit 1
  fi
  cd $HOME_DIR
}

deploy_custom_controller() {

  echo "----------------------------------------------------"
  echo "|            DEPLOY: ISECL-K8S-CONTROLLER          |"
  echo "----------------------------------------------------"

  cd k8s-extensions-controller/

  $KUBECTL create clusterrolebinding isecl-clusterrole --clusterrole=system:node --user=system:serviceaccount:isecl:isecl

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=isecl-controller -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "K8S-CONTROLLER DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying K8S-CONTROLLER"
    echo "Exiting with error..."
    exit 1
  fi

  cd $HOME_DIR
}

deploy_ihub() {

  echo "----------------------------------------------------"
  echo "|             DEPLOY: INTEGRATION-HUB              |"
  echo "----------------------------------------------------"

  required_variables="IHUB_SERVICE_USERNAME,IHUB_SERVICE_PASSWORD,K8S_API_SERVER_CERT,HVS_BASE_URL"
  check_mandatory_variables $IHUB $required_variables

  cd ihub/

  kubernetes_token=$($KUBECTL get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}" -n isecl | base64 --decode)

  # The variables BEARER_TOKEN and CMS_TLS_CERT_SHA384 get loaded with below functions, this required if we want to deploy individual ihub service
  get_bearer_token
  get_cms_tls_cert_sha384

  mkdir -p secrets
  mkdir -p /etc/ihub/

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    API_SERVER_PORT=6443
  elif [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    API_SERVER_PORT=16443
  else
    echo "K8s Distribution" $K8S_DISTRIBUTION "not supported"
    exit 1
  fi

  cp $K8S_API_SERVER_CERT secrets/apiserver.crt

  #update configMap & secrets
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: $CMS_TLS_CERT_SHA384/g" configMap.yml
  sed -i "s/TLS_SAN_LIST:.*/TLS_SAN_LIST: $IH_CERT_SAN_LIST/g" configMap.yml
  sed -i "s/KUBERNETES_TOKEN:.*/KUBERNETES_TOKEN: $kubernetes_token/g" configMap.yml
  sed -i "s/KUBERNETES_URL:.*/KUBERNETES_URL: https:\/\/$K8S_CONTROL_PLANE_IP:$API_SERVER_PORT\//g" configMap.yml
  sed -i "s/IHUB_SERVICE_USERNAME:.*/IHUB_SERVICE_USERNAME: $IHUB_SERVICE_USERNAME/g" secrets.yml
  sed -i "s/IHUB_SERVICE_PASSWORD:.*/IHUB_SERVICE_PASSWORD: $IHUB_SERVICE_PASSWORD/g" secrets.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: ${CMS_BASE_URL}#g" configMap.yml
  sed -i "s#AAS_API_URL:.*#AAS_API_URL: ${AAS_API_URL}#g" configMap.yml
  sed -i "s#HVS_BASE_URL:.*#HVS_BASE_URL: ${HVS_BASE_URL}#g" configMap.yml
  sed -i "s/SHVS_BASE_URL:.*//g" configMap.yml

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=ihub -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "INTEGRATION-HUB DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying HUB"
    echo "Exiting with error..."
    exit 1
  fi

  echo "Waiting for IHub to bootstrap itself..."
  sleep 20
  cd $HOME_DIR

}

deploy_extended_scheduler() {

  #K8s SCHEDULER
  echo "----------------------------------------------------"
  echo "|            DEPLOY: ISECL-K8S-SCHEDULER            |"
  echo "----------------------------------------------------"

  required_variables="K8S_CA_CERT,K8S_CA_KEY"
  check_mandatory_variables "$ISECL_SCHEDULER" $required_variables

  cd k8s-extensions-scheduler/

  echo "Installing Pre-requisites"

  sed -i "s#{HVS_IHUB_PUBLIC_KEY_PATH_VALUE}#\"/opt/isecl-k8s-extensions/hvs_ihub_public_key.pem\"#g" isecl-scheduler.yml
  sed -i "s#{SGX_IHUB_PUBLIC_KEY_PATH_VALUE}#\"\"#g" isecl-scheduler.yml
  # create certs
  chmod +x scripts/create_k8s_extsched_certs.sh
  cd scripts && echo ./create_k8s_extsched_certs.sh -n "K8S Extended Scheduler" -s "$K8S_CONTROL_PLANE_IP","$K8S_CONTROL_PLANE_HOSTNAME" -c "$K8S_CA_CERT" -k "$K8S_CA_KEY"
  ./create_k8s_extsched_certs.sh -n "K8S Extended Scheduler" -s "$K8S_CONTROL_PLANE_IP","$K8S_CONTROL_PLANE_HOSTNAME" -c "$K8S_CA_CERT" -k "$K8S_CA_KEY"
  if [ $? -ne 0 ]; then
    echo "Error while creating certificates for extended scheduler"
    exit 1
  fi

  cd ..
  mkdir -p secrets
  cp scripts/server.key secrets/
  cp scripts/server.crt secrets/

  if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    cp /etc/ihub/ihub_public_key.pem secrets/hvs_ihub_public_key.pem
  elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    cp $IHUB_PUB_KEY_PATH secrets/hvs_ihub_public_key.pem
  else
    echo "K8s Distribution" $K8S_DISTRIBUTION "not supported"
    exit 1
  fi

  # Create kubernetes secrets scheduler-secret for isecl-scheduler.
  $KUBECTL create secret generic scheduler-certs --namespace isecl --from-file=secrets

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  cd $HOME_DIR
}

deploy_kbs() {

  #KBS
  echo "----------------------------------------------------"
  echo "|            DEPLOY: KEY-BROKER-SERVICE            |"
  echo "----------------------------------------------------"

  required_variables="ENDPOINT_URL,KBS_CERT_SAN_LIST,KMIP_SERVER_IP,KMIP_SERVER_PORT,KMIP_CLIENT_CERT_NAME,KMIP_CLIENT_KEY_NAME,KMIP_ROOT_CERT_NAME,KMIP_HOSTNAME"
  check_mandatory_variables $KBS $required_variables

  get_bearer_token
  get_cms_tls_cert_sha384
  cd kbs/

  #update configMap
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: $CMS_TLS_CERT_SHA384/g" configMap.yml
  sed -i "s/TLS_SAN_LIST:.*/TLS_SAN_LIST: $KBS_CERT_SAN_LIST/g" configMap.yml
  sed -i "s#ENDPOINT_URL:.*#ENDPOINT_URL: $ENDPOINT_URL#g" configMap.yml
  sed -i "s/SKC_CHALLENGE_TYPE:.*//g" configMap.yml
  sed -i "s/SQVS_URL:.*//g" configMap.yml
  sed -i "s/SESSION_EXPIRY_TIME:.*//g" configMap.yml

  # Create kubernetes secrets kmip-certs for kbs kmip certificates.
  sed -i "s/KMIP_HOSTNAME:.*/KMIP_HOSTNAME: \"$KMIP_HOSTNAME\"/g" configMap.yml
  sed -i "s/KMIP_SERVER_PORT:.*/KMIP_SERVER_PORT: \"$KMIP_SERVER_PORT\"/g" configMap.yml
  sed -i "s/KMIP_SERVER_IP:.*/KMIP_SERVER_IP: $KMIP_SERVER_IP/g" configMap.yml
  KMIP_CLIENT_CERT_PATH=/etc/kmip/$KMIP_CLIENT_CERT_NAME
  KMIP_CLIENT_KEY_PATH=/etc/kmip/$KMIP_CLIENT_KEY_NAME
  KMIP_ROOT_CERT_PATH=/etc/kmip/$KMIP_ROOT_CERT_NAME
  cd kmip-secrets
  if [ ! -f "$KMIP_CLIENT_CERT_NAME" ] && [ ! -f "$KMIP_CLIENT_KEY_NAME" ] && [ ! -f "$KMIP_ROOT_CERT_NAME" ]; then
    echo "One or more Kmip related certificates are empty"
  fi
  cd ..
  sed -i "s#KMIP_CLIENT_CERT_PATH:.*#KMIP_CLIENT_CERT_PATH: $KMIP_CLIENT_CERT_PATH#g" configMap.yml
  sed -i "s#KMIP_CLIENT_KEY_PATH:.*#KMIP_CLIENT_KEY_PATH: $KMIP_CLIENT_KEY_PATH#g" configMap.yml
  sed -i "s#KMIP_ROOT_CERT_PATH:.*#KMIP_ROOT_CERT_PATH: $KMIP_ROOT_CERT_PATH#g" configMap.yml
  $KUBECTL create secret generic kmip-certs --namespace isecl --from-file=kmip-secrets

    if [ -z "$KMIP_USERNAME" ] || [ ! -f "$KMIP_PASSWORD" ]; then
      echo "Either or both values for KMIP_USERNAME and KMIP_PASSWORD are not set. Ignoring..."
      sed -i "s/KMIP_USERNAME:.*//g" secrets.yml
      sed -i "s/KMIP_PASSWORD:.*//g" secrets.yml
      sed -i "s/- secrets.yml*//g" kustomization.yml
    else
      sed -i "s/KMIP_USERNAME:.*/KMIP_USERNAME: $KMIP_USERNAME/g" secrets.yml
      sed -i "s/KMIP_PASSWORD:.*/KMIP_PASSWORD: $KMIP_PASSWORD/g" secrets.yml
  fi

  if [ -z "$KBS_USERNAME" ] || [ ! -f "$KBS_PASSWORD" ]; then
      echo "Either or both values for KBS_USERNAME and KBS_PASSWORD are not set. Ignoring..."
      sed -i "s/KBS_USERNAME:.*//g" secrets.yml
      sed -i "s/KBS_PASSWORD:.*//g" secrets.yml
      sed -i "s/- secrets:.*//g" kustomization.yml
    else
      sed -i "s/KBS_USERNAME:.*/KBS_USERNAME: $KBS_USERNAME/g" secrets.yml
      sed -i "s/KBS_PASSWORD:.*/KBS_PASSWORD: $KBS_PASSWORD/g" secrets.yml
  fi

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=kbs -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "KBS DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying KBS"
    echo "Exiting with error..."
    exit 1
  fi
  cd $HOME_DIR

}

deploy_wls() {
  #WLS
  echo "----------------------------------------------------"
  echo "|            DEPLOY: WORKLOAD-SERVICE               |"
  echo "----------------------------------------------------"

  cd wls/

  required_variables="WLS_SERVICE_USERNAME,WLS_SERVICE_PASSWORD,WLS_CERT_SAN_LIST,AAS_API_URL,HVS_URL,CMS_BASE_URL"
  check_mandatory_variables $WLS $required_variables

  # The variables bearer_token and cms_tls_digest get loaded with below functions, this required if we want to deploy individual wls service
  get_bearer_token
  get_cms_tls_cert_sha384

  # update wls configMap & secrets
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: ${CMS_TLS_CERT_SHA384}/g" configMap.yml
  sed -i "s#AAS_API_URL:.*#AAS_API_URL: $AAS_API_URL#g" configMap.yml
  sed -i "s#HVS_URL:.*#HVS_URL: $HVS_URL#g" configMap.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: $CMS_BASE_URL#g" configMap.yml
  sed -i "s/SAN_LIST:.*/SAN_LIST: $WLS_CERT_SAN_LIST/g" configMap.yml
  sed -i "s/WLS_SERVICE_USERNAME:.*/WLS_SERVICE_USERNAME: ${WLS_SERVICE_USERNAME}/g" secrets.yml
  sed -i "s/WLS_SERVICE_PASSWORD:.*/WLS_SERVICE_PASSWORD: ${WLS_SERVICE_PASSWORD}/g" secrets.yml
  sed -i "s/WLS_DB_USERNAME:.*/WLS_DB_USERNAME: ${WLS_DB_USERNAME}/g" secrets.yml
  sed -i "s/WLS_DB_PASSWORD:.*/WLS_DB_PASSWORD: ${WLS_DB_PASSWORD}/g" secrets.yml

  # deploy
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=wls -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "WORKLOAD-SERVICE DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying WLS"
    echo "Exiting with error..."
    exit 1
  fi
  cd $HOME_DIR
}

deploy_tagent() {

  echo "----------------------------------------------"
  echo "|            DEPLOY: TRUST-AGENT             |"
  echo "----------------------------------------------"

  # get latest bearer_token and cms tls cert digest
  get_bearer_token
  get_cms_tls_cert_sha384

  required_variables="TA_CERT_SAN_LIST,AAS_API_URL,HVS_URL,CMS_BASE_URL"
  check_mandatory_variables $TAGENT $required_variables

  cd ta/
  # update trustagent configMap.yml
  sed -i "s#AAS_API_URL:.*#AAS_API_URL: $AAS_API_URL#g" configMap.yml
  sed -i "s#HVS_URL:.*#HVS_URL: $HVS_URL#g" configMap.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: $CMS_BASE_URL#g" configMap.yml
  sed -i "s#CMS_TLS_CERT_SHA384:.*#CMS_TLS_CERT_SHA384: $CMS_TLS_CERT_SHA384#g" configMap.yml

  if [ ! -z "$TPM_OWNER_SECRET" ]; then
    sed -i "s/TPM_OWNER_SECRET:.*/TPM_OWNER_SECRET: $TPM_OWNER_SECRET/g" secrets.yml
  else
    sed -i "s/- secrets.yml//g" kustomization.yml
  fi
  if [ "$TA_SERVICE_MODE" == "outbound" ]; then
    sed -i "s/TA_SERVICE_MODE:.*/TA_SERVICE_MODE: $TA_SERVICE_MODE/g" configMap.yml
    sed -i "s#NATS_SERVERS:.*#NATS_SERVERS: $NATS_SERVERS#g" configMap.yml
    $KUBECTL create secret generic bearer-token -n isecl --from-literal=BEARER_TOKEN=$CC_TA_TOKEN --save-config --dry-run=client -o yaml | $KUBECTL apply -f -
  else
    sed -i "s/TA_SERVICE_MODE:.*//g" configMap.yml
    sed -i "s/NATS_SERVERS:.*//g" configMap.yml
  fi

  $KUBECTL kustomize . | $KUBECTL apply -f -
  # wait to get ready
  echo "Wait for ta daemonsets to initialize..."
  sleep 120
  cd $HOME_DIR

}

deploy_nats() {

  echo "-------------------------------------------------"
  echo "|            DEPLOY: NATS-SERVICE               |"
  echo "-------------------------------------------------"

  cd $HOME_DIR/nats/
  get_bearer_token

  mkdir -p secrets
  SERVER_KEY_PATH=secrets/server.key
  SERVER_CERT_PATH=secrets/server.pem
  ./download-nats-tls-certs.sh -d secrets -n "$NATS_CERT_COMMON_NAME" -u "$CMS_K8S_ENDPOINT_URL" -s "$NATS_CERT_SAN_LIST" -t $BEARER_TOKEN
  if [ $? != 0 ]; then
    echo "Error while downloading tls certs for nats server"
    exit 1
  fi

  # get operator and resolver preload from aas logs
  aas_pod=$($KUBECTL get pod -n isecl -l app=aas -o jsonpath="{.items[0].metadata.name}")
  credentials=$($KUBECTL exec -n isecl --stdin $aas_pod -- authservice setup create-credentials --force)
  nats_operator=$(echo "$credentials" | grep operator: | awk '{print $2}')
  resolver_preload=$(echo "$credentials" | grep "Account $NATS_ACCOUNT_NAME" -A 1)
  resolver_jwt=$(echo "$resolver_preload" | cut -d$'\n' -f2)

  sed -i "s#operator:.*#operator: $nats_operator#g" configMap.yml
  sed -i "s#resolver_preload:.*#resolver_preload: { $resolver_jwt }#g" configMap.yml

  $KUBECTL create secret generic nats-certs --from-file=secrets --namespace=isecl

  $KUBECTL kustomize . | $KUBECTL apply -f -
  # wait to get ready
  echo "Wait for nats to initialize..."
  sleep 20
  $KUBECTL get pod -n isecl -l app=nats | grep Running
  if [ $? == 0 ]; then
    echo "NATS STATEFULSET DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying NATS"
    echo "Exiting with error..."
    exit 1
  fi
  cd $HOME_DIR

}

deploy_wlagent() {

  echo "----------------------------------------------"
  echo "|            DEPLOY: WORKLOAD-AGENT          |"
  echo "----------------------------------------------"

  # get latest bearer_token and cms tls cert digest
  get_bearer_token
  get_cms_tls_cert_sha384

  required_variables="WLA_SERVICE_USERNAME,WLA_SERVICE_PASSWORD,AAS_API_URL,HVS_URL,CMS_BASE_URL"
  check_mandatory_variables $WLAGENT $required_variables
  cd wla/
  # #update trustagent.env
  sed -i "s#AAS_API_URL:.*#AAS_API_URL: $AAS_API_URL#g" configMap.yml
  sed -i "s#HVS_URL:.*#HVS_URL: $HVS_URL#g" configMap.yml
  sed -i "s#CMS_BASE_URL:.*#CMS_BASE_URL: $CMS_BASE_URL#g" configMap.yml
  sed -i "s/CMS_TLS_CERT_SHA384:.*/CMS_TLS_CERT_SHA384: $CMS_TLS_CERT_SHA384/g" configMap.yml
  sed -i "s/WLA_SERVICE_USERNAME:.*/WLA_SERVICE_USERNAME: $WLA_SERVICE_USERNAME/g" secrets.yml
  sed -i "s/WLA_SERVICE_PASSWORD:.*/WLA_SERVICE_PASSWORD: $WLA_SERVICE_PASSWORD/g" secrets.yml

  $KUBECTL kustomize . | $KUBECTL apply -f -
  # wait to get ready
  echo "Wait for daemonset to initialize..."
  sleep 20
  $KUBECTL get pod -n isecl -l app=wla | grep Running
  if [ $? == 0 ]; then
    echo "WLA DAEMONSET DEPLOYED SUCCESSFULLY"
  else
    echo "Error: Deploying WLA"
    echo "Exiting with error..."
    exit 1
  fi
  cd $HOME_DIR

}

cleanup_wls() {

  echo "Cleaning up WORKLOAD-SERVICE..."

  $KUBECTL delete secret wls-credentials --namespace isecl
  $KUBECTL delete configmap wls-config --namespace isecl
  $KUBECTL delete deploy wls-deployment --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc wls-config-pvc --namespace isecl
    $KUBECTL delete pvc wls-logs-pvc --namespace isecl
    $KUBECTL delete pv wls-config-pv --namespace isecl
    $KUBECTL delete pv wls-logs-pv --namespace isecl

  fi

}

cleanup_nats() {

  echo "Cleaning up NATS..."

  $KUBECTL delete secret nats-certs --namespace isecl
  $KUBECTL delete configmap nats-config --namespace isecl
  $KUBECTL delete service nats --namespace isecl
  $KUBECTL delete statefulset nats --namespace isecl

}

cleanup_tagent() {
  echo "Cleaning up TRUST-AGENT..."

  $KUBECTL delete configmap ta-config --namespace isecl
  $KUBECTL delete secret ta-credentials --namespace isecl

  $KUBECTL delete daemonset ta-daemonset-txt --namespace isecl
  $KUBECTL delete daemonset ta-daemonset-suefi --namespace isecl
}

cleanup_wlagent() {
  echo "Cleaning up WORKLOAD-AGENT..."

  $KUBECTL delete configmap wla-config --namespace isecl
  $KUBECTL delete secret wla-credentials --namespace isecl
  $KUBECTL delete daemonset wla-daemonset --namespace isecl
}

cleanup_kbs() {

  echo "Cleaning up KEY-BROKER-SERVICE..."

  $KUBECTL delete secret kbs-credentials --namespace isecl
  $KUBECTL delete configmap kbs-config --namespace isecl
  $KUBECTL delete deploy kbs-deployment --namespace isecl
  $KUBECTL delete svc kbs-svc --namespace isecl
  $KUBECTL delete secret kmip-certs --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc kbs-config-pvc --namespace isecl
    $KUBECTL delete pvc kbs-logs-pvc --namespace isecl
    $KUBECTL delete pvc kbs-opt-pvc --namespace isecl
    $KUBECTL delete pv kbs-config-pv --namespace isecl
    $KUBECTL delete pv kbs-logs-pv --namespace isecl
    $KUBECTL delete pv kbs-opt-pv --namespace isecl
  fi
}

cleanup_ihub() {

  echo "Cleaning up INTEGRATION-HUB..."

  IFS=$'\r\n' GLOBIGNORE='*' command eval 'secrets=$(kubectl get secrets -n isecl | grep ihub-k8s-certs | cut -d " " -f 1)'
  for i in "${secrets[@]}"; do kubectl delete secret -n isecl $i >/dev/null; done

  $KUBECTL delete secret ihub-credentials --namespace isecl
  $KUBECTL delete configmap ihub-config --namespace isecl
  $KUBECTL delete deploy ihub-deployment --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc ihub-config-pvc --namespace isecl
    $KUBECTL delete pvc ihub-logs-pvc --namespace isecl
    $KUBECTL delete pv ihub-config-pv --namespace isecl
    $KUBECTL delete pv ihub-logs-pv --namespace isecl
  fi
}

cleanup_isecl_controller() {

  echo "Cleaning up ISECL-K8S-CONTROLLER..."

  $KUBECTL delete deploy isecl-controller-deployment --namespace isecl
  $KUBECTL delete crd hostattributes.crd.isecl.intel.com --namespace isecl
  $KUBECTL delete clusterrole isecl-controller --namespace isecl
  $KUBECTL delete clusterrolebinding isecl-controller-binding --namespace isecl
  $KUBECTL delete clusterrolebinding isecl-clusterrole --namespace isecl
  $KUBECTL delete serviceaccount -n isecl default

}

cleanup_isecl_scheduler() {

  echo "Cleaning up ISECL-K8S-SCHEDULER..."
  cd k8s-extensions-scheduler/

  $KUBECTL delete deploy isecl-scheduler-deployment --namespace isecl
  $KUBECTL delete svc isecl-scheduler-svc --namespace isecl
  $KUBECTL delete secret scheduler-certs --namespace isecl
  rm -rf secrets

  cd $HOME_DIR
}

cleanup_hvs() {

  echo "Cleaning up HOST-VERIFICATION-SERVICE..."

  $KUBECTL delete secret hvs-credentials --namespace isecl

  $KUBECTL delete configmap hvs-config --namespace isecl
  $KUBECTL delete deploy hvs-deployment --namespace isecl
  $KUBECTL delete svc hvs-svc --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc hvs-config-pvc --namespace isecl
    $KUBECTL delete pvc hvs-logs-pvc --namespace isecl
    $KUBECTL delete pv hvs-config-pv --namespace isecl
    $KUBECTL delete pv hvs-logs-pv --namespace isecl
  fi

  echo $(pwd)
}

cleanup_authservice() {

  echo "Cleaning up AUTHENTICATION-AUTHORIZATION-SERVICE..."

  $KUBECTL delete secret aas-credentials --namespace isecl
  $KUBECTL delete configmap aas-config --namespace isecl
  $KUBECTL delete deploy aas-deployment --namespace isecl
  $KUBECTL delete svc aas-svc --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc aas-config-pvc --namespace isecl
    $KUBECTL delete pvc aas-logs-pvc --namespace isecl
    $KUBECTL delete pv aas-config-pv --namespace isecl
    $KUBECTL delete pv aas-logs-pv --namespace isecl
  fi

}

cleanup_cms() {

  echo "Cleaning up CERTIFICATE-MANAGEMENT-SERVICE..."

  $KUBECTL delete configmap cms-config --namespace isecl
  $KUBECTL delete deploy cms-deployment --namespace isecl
  $KUBECTL delete svc cms-svc --namespace isecl

  if [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    $KUBECTL delete pvc cms-config-pvc --namespace isecl
    $KUBECTL delete pvc cms-logs-pvc --namespace isecl
    $KUBECTL delete pv cms-config-pv --namespace isecl
    $KUBECTL delete pv cms-logs-pv --namespace isecl
  fi
  echo $(pwd)
}

bootstrap() {

  echo "----------------------------------------------------"
  echo "|        BOOTSTRAPPING ISECL SERVICES               |"
  echo "----------------------------------------------------"

  echo "----------------------------------------------------"
  echo "|                    PRECHECKS                     |"
  echo "----------------------------------------------------"
  echo "Kubenertes-> "

  if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    $KUBECTL version --short
    if [ $? != 0 ]; then
      echo "microk8s not installed. Cannot bootstrap ISecL Services"
      echo "Exiting with Error.."
      exit 1
    fi
  elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    kubeadm version
    if [ $? != 0 ]; then
      echo "kubeadm not installed. Cannot bootstrap ISecL Services"
      echo "Exiting with Error.."
      exit 1
    fi
  else
    echo "K8s Distribution" $K8S_DISTRIBUTION "not supported"
  fi

  echo "ipAddress: $K8S_CONTROL_PLANE_IP"
  echo "hostName: $K8S_CONTROL_PLANE_HOSTNAME"

  echo "----------------------------------------------------"
  echo "|     DEPLOY: ISECL SERVICES                        |"
  echo "----------------------------------------------------"
  echo ""

  deploy_common_components
  deploy_custom_controller
  deploy_ihub
  deploy_wls
  deploy_kbs
  deploy_wlagent

  if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    deploy_extended_scheduler
  fi

  cd ../

}

cleanup_bearer_token() {
  $KUBECTL delete secret bearer-token -n isecl
}

# #Function to cleanup Intel Micro SecL on Micro K8s
cleanup() {

  echo "----------------------------------------------------"
  echo "|                    CLEANUP                       |"
  echo "----------------------------------------------------"

  cleanup_kbs
  cleanup_wlagent
  cleanup_ihub
  cleanup_wls
  cleanup_isecl_scheduler
  cleanup_isecl_controller
  cleanup_common_components
  cleanup_bearer_token
  if [ $? == 0 ]; then
    echo "Wait for pods to terminate..."
    sleep 30
  fi

}

purge() {
  echo "Cleaning up logs from /var/log/"
  rm -rf /var/log/cms/ /var/log/authservice /var/log/workload-service /var/log/hvs /var/log/ihub /var/log/trustagent /var/log/workload-agent /var/log/kbs
  echo "Cleaning up config from /etc/"
  rm -rf /etc/cms /etc/authservice /etc/workload-service /etc/hvs /etc/ihub /opt/trustagent /etc/workload-agent /etc/kbs
}

#Help section
print_help() {
  echo "Usage: $0 [-help/up/down/purge]"
  echo "    -help                                     Print help and exit"
  echo "    up   [all/<agent>/<service>/<usecase>]    Bootstrap ISecL K8s environment for specified agent/service/usecase"
  echo "    down [all/<agent>/<service>/<usecase>]    Delete ISecL K8s environment for specified agent/service/usecase [will not delete data, config, logs]"
  echo "    purge                                     Delete ISecL K8s environment with data, config, logs [only supported for single node deployments]"
  echo ""
  echo "    Available Options for up/down command:"
  echo "        agent      Can be one of tagent, wlagent"
  echo "        service    Can be one of cms, authservice, hvs, ihub, wls, kbs, isecl-controller, isecl-scheduler"
  echo "        usecase    Can be one of foundational-security, workload-security, isecl-orchestration-k8s, csp, enterprise, foundational-security-control-plane"
}

deploy_common_components() {
  deploy_cms
  deploy_authservice
  if [[ ! -z "${NATS_SERVERS}" ]]; then
    deploy_nats
  fi
  deploy_hvs
  deploy_tagent
  cleanup_bearer_token
}

cleanup_common_components() {
  cleanup_cms
  cleanup_authservice
  cleanup_hvs
  if [[ ! -z "${NATS_SERVERS}" ]]; then
    cleanup_nats
  fi
  cleanup_tagent
  cleanup_bearer_token
}

#Dispatch works based on args to script
dispatch_works() {

  case $1 in
  "up")
    check_k8s_distribution
    case $2 in
    "cms")
      deploy_cms
      ;;
    "authservice")
      deploy_authservice
      ;;
    "wls")
      deploy_wls
      ;;
    "hvs")
      deploy_hvs
      ;;
    "ihub")
      deploy_ihub
      ;;
    "tagent")
      deploy_tagent
      ;;
    "kbs")
      deploy_kbs
      ;;
    "isecl-controller")
      deploy_custom_controller
      ;;
    "isecl-scheduler")
      deploy_extended_scheduler
      ;;
    "wlagent")
      deploy_wlagent
      ;;
    "foundational-security-control-plane")
      deploy_cms
      deploy_authservice
      if [[ ! -z "${NATS_SERVERS}" ]]; then
        deploy_nats
      fi
      deploy_hvs
      ;;
    "foundational-security")
      deploy_common_components
      ;;
    "workload-security")
      deploy_common_components
      deploy_wls
      deploy_kbs
      deploy_wlagent
      ;;
    "isecl-orchestration-k8s")
      deploy_common_components
      deploy_custom_controller
      deploy_ihub
      if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
        deploy_extended_scheduler
      fi
      ;;
    "csp")
      deploy_common_components
      deploy_custom_controller
      deploy_ihub
      if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
        deploy_extended_scheduler
      fi
      deploy_wls
      deploy_wlagent
      ;;
    "enterprise")
      deploy_cms
      deploy_authservice
      deploy_kbs
      ;;
    "all")
      bootstrap
      ;;
    *)
      print_help
      exit 1
      ;;
    esac
    ;;

  "down")
    check_k8s_distribution
    case $2 in
    "cms")
      cleanup_cms
      ;;
    "authservice")
      cleanup_authservice
      ;;
    "wls")
      cleanup_wls
      ;;
    "hvs")
      cleanup_hvs
      ;;
    "ihub")
      cleanup_ihub
      ;;
    "isecl-controller")
      cleanup_isecl_controller
      ;;
    "isecl-scheduler")
      cleanup_isecl_scheduler
      ;;
    "tagent")
      cleanup_tagent
      ;;
    "kbs")
      cleanup_kbs
      ;;
    "wlagent")
      cleanup_wlagent
      ;;
    "foundational-security")
      cleanup_common_components
      ;;
    "foundational-security-control-plane")
      cleanup_cms
      cleanup_authservice
      cleanup_hvs
      if [[ ! -z "${NATS_SERVERS}" ]]; then
        cleanup_nats
      fi
      ;;
    "isecl-orchestration-k8s")
      cleanup_common_components
      cleanup_ihub
      cleanup_isecl_controller
      cleanup_isecl_scheduler
      ;;
    "workload-security")
      cleanup_common_components
      cleanup_kbs
      cleanup_wlagent
      cleanup_wls
      ;;
    "csp")
      cleanup_common_components
      cleanup_isecl_controller
      cleanup_ihub
      if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
        cleanup_isecl_scheduler
      fi
      cleanup_wls
      cleanup_wlagent
      ;;
    "enterprise")
      cleanup_cms
      cleanup_authservice
      cleanup_kbs
      ;;
    "all")
      cleanup
      ;;

    *)
      print_help
      exit 1
      ;;
    esac
    ;;
  "purge")
    if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
      KUBECTL=microk8s.kubectl
      cleanup
      purge
      if [ $? -ne 0 ]; then exit 1; fi
    else
      echo "purge command not supported for this K8s distribution"
      exit 1
    fi
    ;;
  "-help")
    print_help
    ;;
  *)
    echo "Invalid Command"
    print_help
    exit 1
    ;;
  esac
}

if [ $# -eq 0 ]; then
  print_help
  exit 1
fi

# run commands
dispatch_works $*
