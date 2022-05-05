#!/bin/bash
source isecl-skc-k8s.env
if [ $? != 0 ]; then
  echo "failed to source isecl-skc-k8s.env"
fi

HOME_DIR=$(pwd)
CMS_ROOTCA=cms-ca.cert
RED='\033[0;31m'
NC='\033[0m' # No Color

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
	rm -f ./skc_library/resources/custom-claim-token/*-response.json
	rm -r $tmp_file
}

update_skc_conf() {

  pushd skc_library
  sed -i "s/\(.*\"validity_seconds\":\s\)\(.*\)/\1$TOKEN_VALIDITY_SECS,/g" ./resources/custom-claim-token/aps-custom-claim-request.json
  sed -i "s/\(.*\"validity_seconds\":\s\)\(.*\)/\1$TOKEN_VALIDITY_SECS,/g" ./resources/custom-claim-token/kbs-custom-claim-request.json

  ./resources/get_cms_ca.sh $K8S_CONTROL_PLANE_IP
  ./resources/custom-claim-token/custom-claim-token.sh kbs $K8S_CONTROL_PLANE_IP $AAS_ADMIN_USERNAME $AAS_ADMIN_PASSWORD
  ./resources/custom-claim-token/custom-claim-token.sh aps $K8S_CONTROL_PLANE_IP $AAS_ADMIN_USERNAME $AAS_ADMIN_PASSWORD

  kbs_token=$(cat ./resources/custom-claim-token/kbs-custom-claim-response.json)
  aps_token=$(cat ./resources/custom-claim-token/aps-custom-claim-response.json)

  if [ -z "$kbs_token" -o -z "$aps_token" ]; then
	  echo -e "$RED APS/KBS Token Generation failed ...............$NC"
	  popd
	  clean_tmp_files
	  exit 1
  fi
  
  sed -i "s#auth_token=.*#auth_token=$kbs_token#g" resources/npm.ini
  sed -i "s#aps_token=.*#aps_token=$aps_token#g" resources/npm.ini
  sed -i "s/mode=.*/mode=$MODE/" resources/npm.ini
  popd

  sed -i "s#\(\s\+image: \)\(.*\)#\1$SKC_LIBRARY_IMAGE_NAME:$SKC_LIBRARY_IMAGE_TAG#" skc_library/deployment.yml
  sed -i "31s/\(\s\+- \)\(.*\)/\1\"$NODE_LABEL\"/" skc_library/deployment.yml

}

create_configmap_secrets() {
  $KUBECTL create configmap nginx-config --from-file=skc_library/resources/nginx.conf --namespace=isecl
  $KUBECTL create configmap kbs-key-config --from-file=skc_library/resources/keys.txt --namespace=isecl
  $KUBECTL create configmap sgx-qcnl-config --from-file=skc_library/resources/sgx_default_qcnl.conf --namespace=isecl
  $KUBECTL create configmap openssl-config --from-file=skc_library/resources/openssl.cnf --namespace=isecl
  $KUBECTL create configmap pkcs11-config --from-file=skc_library/resources/pkcs11-apimodule.ini --namespace=isecl
  $KUBECTL create configmap kbs-npm-config --from-file=skc_library/resources/npm.ini --namespace=isecl
  $KUBECTL create configmap sgx-stm-config --from-file=skc_library/resources/sgx_stm.ini --namespace=isecl
  $KUBECTL create secret generic cmsca-cert-secret --from-file=skc_library/resources/$CMS_ROOTCA --namespace=isecl
  $KUBECTL create secret generic kbs-cert-secret --from-file=skc_library/resources/nginx.crt --namespace=isecl
  $KUBECTL create configmap haproxy-hosts-config --from-file=skc_library/resources/hosts --namespace=isecl
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


  sed -i "s/\(.*;id=\)\(.*\)\(;object=.*\)/\1$key_id\3/" skc_library/resources/keys.txt
  sed -i "s/\(.*;id=\)\(.*\)\(;object=.*\)/\1$key_id\3/" skc_library/resources/nginx.conf


  echo $cert_path
  cp $cert_path ./skc_library/resources/nginx.crt

  # deploy
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
  $KUBECTL delete configmap nginx-config kbs-key-config sgx-qcnl-config openssl-config pkcs11-config sgx-stm-config kbs-npm-config haproxy-hosts-config --namespace isecl
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
