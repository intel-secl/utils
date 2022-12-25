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
9. SKC Library - Build and deploy only supported un ubuntu 20.04

## System Requirements

**Recommended HW**

	1 vCPUs 
	RAM: 2 GB 
	10 GB 
	One network interface with network access to all Intel® SecL-DC services 

**Operating System**

	RHEL8.4 and Ubuntu 20.04 with root account access (All SKC Services run as root)

**Disable Firewall**

	systemctl stop firewalld

**SGX Agent & SKC Library**

**Hardware**

	SGX Enabled System

**Operating System**

	RHEL 8.4 and Ubuntu 20.04

**Disable Firewall**

	systemctl stop firewalld


## Deployment of Services

**Deploy SKC Service on CSP VM**

- Follow product guide for deployment instruction
  - It will update all the required configuration files and install following services
- Check Service Status
  - netstat -nltp
  - Using services command line
    - cms status
    - authservice status
    - scs status
    - shvs status
    - ihub status
- Turn off Firewall service or ensure that these services can be accessed from the machine where SGX Agent/SKC_Library is running
   # systemctl stop firewalld

**Deploy SKC Service on Enterprise VM**

- Update the enterprise_skc.conf with the IP address of the Enterprise VM
- Follow product guide for deployment instruction
  - It will update all the required configuration files and install following services
- Check Service Status
  - netstat -nltp
  - Using services command line
    - cms status
    - authservice status
    - scs status
    - sqvs status
    - kbs status
- Turn off Firewall service or ensure that these services can be accessed from the machine where SGX Agent/SKC_Library is running
   # systemctl stop firewalld

### Build & Deployment of SGX Agent & SKC Library

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

Follow Product Guide

