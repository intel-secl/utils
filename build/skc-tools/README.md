# SKC Quick Start Guide

## SKC Key Components and Services

1. Authorization and Authentication Service
2. Certificate Management Service
3. SGX Host Verification Service
4. SGX Caching Service
5. SGX hub
6. Key Broker Service
7. SGX Quote Verification Service
8. SGX Agent
9. SKC Library

## System Requirements

**Recommended HW**

​	1 vCPUs 
​	RAM: 2 GB 
​	10 GB 
​	One network interface with network access to all Intel® SecL-DC services 

**Operating System**

​	RHEL8.2 with root account access (All SKC Services run as root)

**Disable Firewall**

​	systemctl stop firewalld

**SGX Agent & SKC Library**

**Hardware**

​	SGX Enabled ICX Whitley System

**Operating System**

​	RHEL 8.2

**Disable Firewall**

​	systemctl stop firewalld


## Building & Deployment of Services

**Build SKC Services**

- cd into skc_scripts
- run build_skc.sh
  - It will copy following component binaries to a common location
- Authentication and Authorization Service (AAS)
- Certificate Management Service (CMS)
- SGX Caching Service (SCS)
- SGX Quote Verification Service (SQVS)
- SGX Host Verification Service (SHVS)
- SGX Hub Service (SHUB)
- Key Broker Service (KBS)

**Deploy SKC Service**

- Update the skc.conf with the IP address of the VM, where services will be deployed
- run install_skc.sh
  - It will update all the required configuration files and install all the services
- Check Service Status
  - netstat -nltp
  - Using services command line
    - cms status
    - authservice status
    - scs status
    - sqvs status
    - shvs status
    - shub status
    - kms status
- Turn off Firewall service or ensure that these services can be accessed from the machine where SGX Agent/SKC_Library is running
   # systemctl stop firewalld

## Build & Deployment of SGX Agent & SKC Library

**Build SGX_Agent**

cd into sgx_agent/build_scripts folder

Follow the instructions in README.build file


**Deploy SGX Agent** (To be run on SGX Enabled server)

cd into sgx_agent/deploy_scripts folder

Follow the instructions in README.install file


**Build SKC Library**

cd into skc_library/build_scripts folder

Follow the instructions in README.build file


**Deploy SKC Library** (To be run on SGX Enabled server)

cd into skc_library/deploy_scripts folder

Follow the instructions in README.install file


## Creating AES and RSA Keys in Key Broker Service

**Configuration Update to create Keys in KBS**

​	cd into kbs_scripts folder

​	Update KBS and AAS IP address in run.sh

**Create AES Key**

​	Execute the command

​	./run.sh
- Copy the key id generated

**Create RSA Key**

​	Execute the command

​	./run.sh reg

- copy the generated cert file to sgx machine where skc_library is deployed. Also copy the key id generated

## Configuration for NGINX testing

**Note:** OpenSSL and NGINX base configuration updates are completed as part of deployment script.

**OpenSSL**

[openssl_def]
engines = engine_section

[engine_section]
pkcs11 = pkcs11_section

[pkcs11_section]
engine_id = pkcs11

dynamic_path =/usr/lib64/engines-1.1/pkcs11.so

MODULE_PATH =/opt/skc/lib/libpkcs11-api.so

init = 0

**Nginx**

user root;

ssl_engine pkcs11;

Update the location of certificate with the loaction where it was copied into the skc_library machine. 

ssl_certificate "/root/nginx/nginxcert.pem"; 

Update the KeyID with the KeyID received when RSA key was generated in KBS

ssl_certificate_key "engine:pkcs11:pkcs11:token=KMS;id=164b41ae-be61-4c7c-a027-4a2ab1e5e4c4;object=RSAKEY;type=private;pin-value=1234";

**SKC Configuration**

​ Create keys.txt in /tmp folder. The keyID should match the keyID of RSA key created in KBS. Other contents should match with nginx.conf. File location should match on pkcs11-apimodule.ini; 

​	pkcs11:token=KMS;id=164b41ae-be61-4c7c-a027-4a2ab1e5e4c4;object=RSAKEY;type=private;pin-value=1234";

​	**Note:** Content of this file should match with the nginx conf file

​	**/opt/skc/etc/pkcs11-apimodule.ini**

​	**[core]**

​	preload_keys=/tmp/keys.txt

​	keyagent_conf=/opt/skc/etc/key-agent.ini

​	mode=SGX

​	debug=true

​	**[SW]**

​	module=/usr/lib64/pkcs11/libsofthsm2.so

​	**[SGX]**

​	module=/opt/intel/cryptoapitoolkit/lib/libp11sgx.so


**Appendix**

**Product Guide**

https://github.com/intel-secl/skc-tools/blob/v3.0.0/SKC_Product_Guide.md

**Release Notes**

https://github.com/intel-secl/skc-tools/blob/v3.0.0/ReleaseNotes
