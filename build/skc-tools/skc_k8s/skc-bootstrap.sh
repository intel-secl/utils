#!/bin/bash
source isecl-skc-k8s.env
if [ $? != 0 ]; then
  echo "failed to source isecl-skc-k8s.env"
fi

HOME_DIR=$(pwd)
CMS_ROOTCA=cms-ca.cert
RED='\033[0;31m'
NC='\033[0m' # No Color
KBS_PUB_KEY_PATH= #To store created certificate path

check_k8s_distribution() {
  if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
    KUBECTL=microk8s.kubectl
  elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    KUBECTL=kubectl
  else
    echo -e "$RED K8s Distribution \"$K8S_DISTRIBUTION\" not supported $NC"
  fi
}

check_mandatory_variables() {
  while read p; do
    echo "$p" | grep ".*=\(\s\+\)"
    if [ $? -eq 0 ]; then
	    echo -e "$RED invalid config provided = $p $NC"
	    exit 1
    fi 
  done <isecl-skc-k8s.env
}
tmp_file=/tmp/key_id_parse.txt
clean_tmp_files() {
	rm -r $tmp_file
}

update_skc_conf() {

  pushd skc_library
  ./resources/get_cms_ca.sh $K8S_CONTROL_PLANE_IP

  echo "Updating KBS IP in resources/kms_npm.ini"
  sed -i "s/server=.*/server=https:\/\/$KBS_IP:$KBS_PORT\/kbs/" resources/kms_npm.ini

  echo "Updating debug mode in files"
  sed -i "s/debug=.*/debug=$SKC_DEBUG/" resources/kms_npm.ini
  sed -i "s/debug=.*/debug=$SKC_DEBUG/" resources/sgx_stm.ini
  sed -i "s/debug=.*/debug=$SKC_DEBUG/" resources/pkcs11-apimodule.ini

  echo "Updating K8S control plane IP and Port number in resources/hosts"
  echo > resources/hosts
  echo "$K8S_CONTROL_PLANE_IP $K8S_CONTROL_PLANE_HOSTNAME" > resources/hosts

  echo "Updating PCCS URL in resources/sgx_default_qcnl.conf"
  sed -i 's|PCCS_URL=.*|PCCS_URL=https://'$SCS_IP':'$SCS_PORT'/scs/sgx/certification/v1/|g' resources/sgx_default_qcnl.conf
  sed -i "s/USE_SECURE_CERT=.*/USE_SECURE_CERT=$USE_SECURE_CERT/" resources/sgx_default_qcnl.conf
  
  echo "Updating details in resources/create_roles.conf"
  sed -i "s/AAS_IP=.*/AAS_IP=$AAS_IP/" resources/create_roles.conf
  sed -i "s/AAS_PORT=.*/AAS_PORT=$AAS_PORT/" resources/create_roles.conf
  sed -i "s/SKC_USER=.*/SKC_USER=$SKC_USER/" resources/create_roles.conf
  sed -i "s/SKC_USER_PASSWORD=.*/SKC_USER_PASSWORD=$SKC_USER_PASSWORD/" resources/create_roles.conf
  sed -i "s/ADMIN_USERNAME=.*/ADMIN_USERNAME=$AAS_ADMIN_USERNAME/" resources/create_roles.conf
  sed -i "s/ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$AAS_ADMIN_PASSWORD/" resources/create_roles.conf
  
  echo "Updating details in resources/skc_library.conf"
  sed -i "s/KBS_HOSTNAME=.*/KBS_HOSTNAME=$KBS_HOSTNAME/" resources/skc_library.conf
  sed -i "s/KBS_IP=.*/KBS_IP=$KBS_IP/" resources/skc_library.conf
  sed -i "s/KBS_PORT=.*/KBS_PORT=$KBS_PORT/" resources/skc_library.conf
  sed -i "s/CMS_IP=.*/CMS_IP=$CMS_IP/" resources/skc_library.conf
  sed -i "s/CMS_PORT=.*/CMS_PORT=$CMS_PORT/" resources/skc_library.conf
  sed -i "s/CSP_SCS_IP=.*/CSP_SCS_IP=$CSP_SCS_IP/" resources/skc_library.conf
  sed -i "s/CSP_SCS_PORT=.*/CSP_SCS_PORT=$CSP_SCS_PORT/" resources/skc_library.conf
  sed -i "s/CSP_CMS_IP=.*/CSP_CMS_IP=$CSP_CMS_IP/" resources/skc_library.conf
  sed -i "s/CSP_CMS_PORT=.*/CSP_CMS_PORT=$CSP_CMS_PORT/" resources/skc_library.conf
  sed -i "s/SKC_USER=.*/SKC_USER=$SKC_USER/" resources/skc_library.conf
  
  ./resources/skc_library_create_roles.sh > $tmp_file
  skc_token=$(tail -2 $tmp_file | head -1)
  sed -i "s/SKC_TOKEN=.*/SKC_TOKEN=$skc_token/" resources/skc_library.conf
  popd

  sed -i "s#\(\s\+image: \)\(.*\)#\1$SKC_LIBRARY_IMAGE_NAME:$SKC_LIBRARY_IMAGE_TAG#" skc_library/deployment.yml
  if [ ! -z "$SKC_LIBRARY_IMAGE_PULL_SECRET" ] && [ "$SKC_LIBRARY_IMAGE_PULL_SECRET" != "nil" ]; then
  sed -i 's/- name: <image-pull-secret>.*/- name: '$SKC_LIBRARY_IMAGE_PULL_SECRET'/' skc_library/deployment.yml
  fi
  sed -i "31s/\(\s\+- \)\(.*\)/\1\"$NODE_LABEL\"/" skc_library/deployment.yml

}

create_configmap_secrets() {
  $KUBECTL create configmap skc-lib-config --from-file=skc_library/resources/skc_library.conf --namespace=isecl
  $KUBECTL create configmap nginx-config --from-file=skc_library/resources/nginx.conf --namespace=isecl
  $KUBECTL create configmap kbs-key-config --from-file=skc_library/resources/keys.txt --namespace=isecl
  $KUBECTL create configmap sgx-qcnl-config --from-file=skc_library/resources/sgx_default_qcnl.conf --namespace=isecl
  $KUBECTL create configmap openssl-config --from-file=skc_library/resources/openssl.cnf --namespace=isecl
  $KUBECTL create configmap pkcs11-config --from-file=skc_library/resources/pkcs11-apimodule.ini --namespace=isecl
  $KUBECTL create configmap kms-npm-config --from-file=skc_library/resources/kms_npm.ini --namespace=isecl
  $KUBECTL create configmap sgx-stm-config --from-file=skc_library/resources/sgx_stm.ini --namespace=isecl
  $KUBECTL create configmap haproxy-hosts-config --from-file=skc_library/resources/hosts --namespace=isecl
  $KUBECTL create secret generic cmsca-cert-secret --from-file=skc_library/resources/$CMS_ROOTCA --namespace=isecl
  $KUBECTL create secret generic kbs-cert-secret --from-file=skc_library/resources/$KBS_PUB_KEY_PATH --namespace=isecl
}

deploy_SKC_library() {

  echo "----------------------------------------------------"
  echo "|      DEPLOY: SKC-LIBRARY                          |"
  echo "----------------------------------------------------"

  update_skc_conf

  pushd kbs_script
  sed -i "s/SYSTEM_IP=.*/SYSTEM_IP=$K8S_CONTROL_PLANE_IP/" kbs.conf
  sed -i "s/AAS_PORT=.*/AAS_PORT=$AAS_PORT/" kbs.conf
  sed -i "s/CMS_PORT=.*/CMS_PORT=$CMS_PORT/" kbs.conf
  sed -i "s/KBS_PORT=.*/KBS_PORT=$KBS_PORT/" kbs.conf
  sed -i "s/AAS_USERNAME=.*/AAS_USERNAME=$AAS_ADMIN_USERNAME/" kbs.conf
  sed -i "s/AAS_PASSWORD=.*/AAS_PASSWORD=$AAS_ADMIN_PASSWORD/" kbs.conf
  sed -i "s/ENTERPRISE_ADMIN=.*/ENTERPRISE_ADMIN=$CCC_ADMIN_USERNAME/" kbs.conf
  sed -i "s/ENTERPRISE_PASSWORD=.*/ENTERPRISE_PASSWORD=$CCC_ADMIN_PASSWORD/" kbs.conf
  sed -i "s/^KMIP_IP\(\s\+\)\?=.*/KMIP_IP = \'$KMIP_IP\'/" rsa_create.py
  sed -i "s#^CERT_PATH\(\s\+\)\?=.*#CERT_PATH = \'$KMIP_CLIENT_CERT\'#" rsa_create.py
  sed -i "s#^KEY_PATH\(\s\+\)\?=.*#KEY_PATH = \'$KMIP_CLIENT_KEY\'#" rsa_create.py
  sed -i "s#^CA_PATH\(\s\+\)\?=.*#CA_PATH = \'$KMIP_CLIENT_ROOTCA\'#" rsa_create.py

  sed -i "s/AAS_USERNAME=.*/AAS_USERNAME=$AAS_ADMIN_USERNAME/" kbs.conf
  sed -i "s#^\(\s\+\"mrenclave\":\s\+\?\[\"\)\(.*\)\(\"\],\)#\1$CTK_ENCLAVE_MEASUREMENT\3#" transfer_policy_request.json
  sed -i "s#^\(\s\+\"mrsigner\":\s\+\?\[\"\)\(.*\)\(\"\],\)#\1$CTK_SIGNER_MEASUREMENT\3#" transfer_policy_request.json
  sed -i "s#^\(\s\+\"isvprodid\":\s\+\?\[\)\(.*\)\(\],\)#\1$PROD_ID\3#" transfer_policy_request.json
  sed -i "s#^\(\s\+\"isvsvn\":\s\+\?\)\(.*\)\(,\)#\1$ISV_SVN\3#" transfer_policy_request.json
  sed -i "s#^\(\s\+\"enforce_tcb_upto_date\":\s\+\?\)\(.*\)#\1$TCB_UPDATE#" transfer_policy_request.json

  result=$(./run.sh reg)
  echo $result | tr -d '\n' > $tmp_file
  
  key_id=$(sed -e "s/\(.*Created Key: \)\([0-9a-fA-F]\{8\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{4\}-[0-9a-fA-F]\{12\}\)\(.*\)/\2/"  -e "s#[[:space:]]##" $tmp_file)
  cert_path=$(sed -e "s/\(^.*Key Certificate Path:\s\)\(.*[a-f0-9]*\.crt\)/\2/" -e "s/Created Key.*//" -e "s/\(.*crt\)\(.*\)/\1/" $tmp_file)
  if [ -z "$key_id" -o -z "$cert_path" ]; then
	  echo -e "$RED KBS Key Generation failed ...............$NC"
	  popd
	  clean_tmp_files
	  exit 1
  fi
  echo $key_id
  echo $cert_path
  popd

  pushd skc_library
  sed -i "s/\(.*;id=\)\(.*\)\(;object=.*\)/\1$key_id\3/" resources/keys.txt
  sed -i "s/\(.*;id=\)\(.*\)\(;object=.*\)/\1$key_id\3/" resources/nginx.conf
  sed -i 's|ssl_certificate .*|ssl_certificate \"/root/'$key_id'.crt\";|g' resources/nginx.conf

  echo "Updating mountPath and subPath in SKC library deployment.yml"
  sed -i 's/- mountPath: \/root\/<kbs public certificate>.crt.*/- mountPath: \/root\/'$key_id'.crt/' deployment.yml
  sed -i 's/subPath: <kbs public certificate>.crt.*/subPath: '$key_id'.crt/' deployment.yml
  popd
  
  echo $cert_path
  cp $cert_path ./skc_library/resources/$key_id.crt
  KBS_PUB_KEY_PATH=$key_id.crt

  # deploy
  echo "Creating configmap secrets"
  create_configmap_secrets
  pushd skc_library
  $KUBECTL kustomize . | $KUBECTL apply -f -

  # wait to get ready
  echo "Wait for pods to initialize..."
  POD_NAME=$($KUBECTL get pod -l app=skclib -n isecl -o name)
  $KUBECTL wait --for=condition=Ready $POD_NAME -n isecl --timeout=60s
  if [ $? == 0 ]; then
    echo "SKC LIBRARY DEPLOYED SUCCESSFULLY"
  else
    echo -e "$RED ERROR: Failed to deploy skc library $NC"
    echo "Exiting with error..."
    popd 
    clean_tmp_files
    exit 1
  fi

  echo "Waiting for SKC LIBRARY to bootstrap itself..."
  sleep 60
  popd 

  clean_tmp_files
  cd $HOME_DIR

}

launch_SKC_library() {

  echo "----------------------------------------------------"
  echo "|      DEPLOY: SKC-LIBRARY                          |"
  echo "----------------------------------------------------"

  update_skc_conf

  # deploy
  create_configmap_secrets
  pushd skc_library
  $KUBECTL kustomize . | $KUBECTL apply -f -
  
  popd
  rm -f ./skc_library/resources/custom-claim-token/*-response.json
  cd $HOME_DIR

}
cleanup_SKC_library() {

  echo "Uninstaling K8S SKC LIBRARY..."
  cd skc_library
  $KUBECTL delete secret kbs-cert-secret cmsca-cert-secret --namespace isecl
  $KUBECTL delete configmap skc-lib-config nginx-config kbs-key-config sgx-qcnl-config openssl-config pkcs11-config sgx-stm-config kms-npm-config haproxy-hosts-config --namespace isecl
  $KUBECTL delete deploy skclib-deployment --namespace isecl
  $KUBECTL delete svc skclib-svc --namespace isecl
  cd ../
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
      echo -e "$RED microk8s not installed. Cannot bootstrap ISecL Services $NC"
      echo "Exiting with Error.."
      exit 1
    fi
  elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
    kubeadm version
    if [ $? != 0 ]; then
      echo -e "$RED kubeadm not installed. Cannot bootstrap ISecL Services $NC"
      echo "Exiting with Error.."
      exit 1
    fi
  else
    echo -e "$RED K8s Distribution" $K8S_DISTRIBUTION "not supported $NC"
  fi

  echo "ipAddress: $K8S_CONTROL_PLANE_IP"
  echo "hostName: $K8S_CONTROL_PLANE_HOSTNAME"

  echo "----------------------------------------------------"
  echo "|     DEPLOY: SKC	                           |"
  echo "----------------------------------------------------"
  echo ""

  cd ../

}

# #Function to cleanup Intel Micro SecL on Micro K8s
cleanup() {

  echo "----------------------------------------------------"
  echo "|                    CLEANUP                       |"
  echo "----------------------------------------------------"

  cleanup_SKC_library
  if [ $? == 0 ]; then
    echo "Wait for pods to terminate..."
    sleep 30
  fi

}

#Help section
print_help() {
  echo "Usage: $0 [help/install/launch/uninstall]"
  echo "    help   	Print help"
  echo "    install     Install SKC Library in K8s environment"
  echo "    launch      Launch SKC Library in K8s environment"
  echo "    uninstall   UnInstall SKC Library in K8s environment"
  echo ""
}



#Dispatch works based on args to script
dispatch_works() {

  case $1 in
  "install")
    check_k8s_distribution
    deploy_SKC_library
    ;;
  "launch")
    check_k8s_distribution
    launch_SKC_library
    ;;
  "uninstall")
    check_k8s_distribution
    cleanup_SKC_library
    ;;
  "help")
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
check_mandatory_variables
dispatch_works $*
