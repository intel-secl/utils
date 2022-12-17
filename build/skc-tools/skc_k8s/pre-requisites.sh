#!/bin/bash

echo "OpenSSL->"
openssl version
if [ $? != 0 ]; then
  echo "OpenSSL is not installed. Cannot create certificates needed for SSL connection to DB"
  echo "Exiting with Error.."
  exit 1
fi

which cfssl
if [ $? -ne 0 ]; then
  wget http://pkg.cfssl.org/R1.2/cfssl_linux-amd64
  chmod +x cfssl_linux-amd64
  mv cfssl_linux-amd64 /usr/local/bin/cfssl
fi

which cfssljson
if [ $? -ne 0 ]; then
  wget http://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
  chmod +x cfssljson_linux-amd64
  mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
fi

source isecl-skc-k8s.env
if [ $? != 0 ]; then
  echo "failed to source isecl-skc-k8s.env"
fi

if [ "$K8S_DISTRIBUTION" == "microk8s" ]; then
  KUBECTL=microk8s.kubectl
  $KUBECTL version --short
  if [ $? != 0 ]; then
    echo "microk8s not installed. Cannot bootstrap ISecL Services"
    echo "Exiting with Error.."
    exit 1
  fi
elif [ "$K8S_DISTRIBUTION" == "kubeadm" ]; then
  KUBECTL=kubectl
  kubeadm version
  if [ $? != 0 ]; then
    echo "kubeadm not installed. Cannot bootstrap ISecL Services"
    echo "Exiting with Error.."
    exit 1
  fi
else
  echo "K8s Distribution" $K8S_DISTRIBUTION "not supported"
fi

echo "----------------------------------------------------"
echo "|     DEPLOY: NAMESPACE FOR ISECL DEPLOYMENT        |"
echo "----------------------------------------------------"
echo ""

$KUBECTL create namespace isecl
if [ $? == 0 ]; then
  echo ""
  echo "Installed pre requisites for ISecl SKC Services"
  exit 0
else
  echo ""
  echo "Failed to install pre requisites for ISecl SKC Services"
  exit 1
fi
