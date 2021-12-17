Ansible Role - Intel Security Libraries - DC
=====================================

An ansible role that installs Intel® Security Libraries for Data Center (Intel® SecL-DC) on supported Linux OS. 

Table of Contents
-----------------

   * [Ansible Role - Intel Security Libraries - DC](#ansible-role---intel-security-libraries---dc)
      * [Table of Contents](#table-of-contents)
      * [Requirements](#requirements)
      * [Dependencies](#dependencies)
      * [Usecase and Playbook Support](#usecase-and-playbook-support)
      * [Supported Deployment Model](#supported-deployment-model)
      * [Packages &amp; Repos Installed by Role](#packages--repos-installed-by-role)
      * [Supported Usecases and  Corresponding Components](#supported-usecases-and--corresponding-components)
      * [Example Inventory and Vars](#example-inventory-and-vars)
      * [Using the Role in Ansible](#using-the-role-in-ansible)
      * [Example Playbook and CLI](#example-playbook-and-cli)
      * [Additional Workflow Examples](#additional-workflow-examples)
      * [Intel® SecL-DC Services Details](#intel-secl-dc-services-details)
      * [Role Variables](#role-variables)
      * [License](#license)
      * [Author Information](#author-information)


Requirements
------------

This role requires the following as pre-requisites:

1. **Build Machine and Ansible Server**<br>
   
   - The Build machine is required to build Intel® SecL-DC repositories. More details on building repositories in [Quick Start Guide - Foundational & Workload Security](https://github.com/intel-secl/docs/blob/v4.1/develop/quick-start-guides/Quick%20Start%20Guide%20-%20Intel%C2%AE%20Security%20Libraries%20-%20Foundational%20%26%20Workload%20Security.md) and in [Quick Start Guide - Secure Key Caching](https://github.com/intel-secl/docs/blob/v4.1/develop/quick-start-guides/Quick%20Start%20Guide%20-%20Intel%C2%AE%20Security%20Libraries%20-%20Secure%20Key%20Caching.md)
   - The Ansible Server is required to use this role to deploy Intel® SecL-DC services based on the supported deployment   model. The Ansible server is recommended to be installed on the Build machine itself. 
   - The role has been tested with `Ansible Version 2.9.10`
   
2. **Repositories and OS**<br>

   * **Foundational and Workload Security Usecases**
     * `RHEL 8.3` OS
     * Repositories to be enabled are `rhel-8-for-x86_64-appstream-rpms` and `rhel-8-for-x86_64-baseos-rpms`<br>
   * **Secure Key Caching**
     * `RHEL 8.2` OS / `Ubuntu 18.04` OS / `Ubuntu 20.04` OS
     * Repositories to be enabled for RHEL OS are `rhel-8-for-x86_64-appstream-rpms` and `rhel-8-for-x86_64-baseos-rpms` and `codeready-builder-for-rhel-8-x86_64-rpms`<br>

3. **User Access**<br>
   Ansible should be able to talk to the remote machines using the `root` user and the Intel® SecL-DC services need to be installed as `root` user as well<br>

4. **Physical Server Requirements**<br>

   a. **Foundational and Workload Security Usecases**
      * Intel® SecL-DC supports and uses a variety of Intel security features, but there are some key requirements to consider before beginning an installation. Most important among these is the Root of Trust configuration. This involves deciding what combination of TXT, Boot Guard, tboot, and UEFI Secure Boot to enable on platforms that will be attested using Intel® SecL.

        > **Note:** At least one "Static Root of Trust" mechanism must be used (TXT and/or BtG). For Legacy BIOS systems, tboot must be used. For UEFI mode systems, UEFI SecureBoot must be used* Use the chart below for a guide to acceptable configuration options.Only dTPM is supported on Intel® SecL-DC platform hardware.  

        ![hardware-options](./images/trusted-boot-options.PNG)

        > **Note:** A security bug related to UEFI Secure Boot and Grub2 modules has resulted in some modules required by tboot to not be available on RedHat 8 UEFI systems. Tboot therefore cannot be used currently on RedHat 8. A future tboot release is expected to resolve this dependency issue and restore support for UEFI mode.

   b. **Secure Key Caching, SGX Attestation Kubernetes, SGX Attestation Openstack, SGX Orchestration Kubernetes, SGX Orchestration Openstack and Skc No Orchestration Usecases**
      * Supported Hardware: Intel® Xeon® SP products those support SGX
      * BIOS Requirements: Intel® SGX-TEM BIOS requirements are outlined in the latest Intel® SGX Platforms BIOS Writer's Guide, Intel® SGX should be enabled in BIOS menu (Intel® SGX is Disabled by default on Ice Lake), Intel® SGX BIOS requirements include exposing Flexible Launch Control menu.
      * OS Requirements (Intel® SGX does not supported on 32-bit OS): Linux RHEL 8.2 / Linux Ubuntu 18.04 / Linux Ubuntu 20.04<br>

Dependencies
------------

None



Usecase and Playbook Support on RHEL
------------------------------------

| Usecase                                            | Playbook Support |
| -------------------------------------------------- | ---------------- |
| Host Attestation                                   | Yes              |
| Data Fencing and Asset Tags                        | Yes              |
| Trusted Workload Placement                         | Yes(partial*)    |
| Application Integrity                              | Yes              |
| Launch Time Protection - VM Confidentiality        | Yes(partial*)    |
| Launch Time Protection - Container Confidentiality with CRIO runtime | Yes(partial*)    |
| Secure Key Caching                                 | Yes              |
| SGX Orchestration Kubernetes                                | Yes(partial*)    |
| SGX Attestation Kubernetes                                    | Yes(partial*)    |
| SGX Orchestration Openstack                                  | Yes(partial*)    |
| SGX Attestation Openstack                                    | Yes(partial*)    |
| SKC No Orchestration                               | Yes              |
| SGX Attestation No Orchestration                   | Yes              |
   > **Note:** *partial means orchestrator installation is not bundled with the role and need to be done independently. Also, components dependent on the orchestrator like `isecl-k8s-extensions` and `integration-hub` are installed either partially or not installed

Usecase and Playbook Support on Ubuntu
--------------------------------------

| Usecase                                            | Playbook Support |
| -------------------------------------------------- | ---------------- |
| Secure Key Caching                                 | Yes              |
| SGX Orchestration                                  | Yes(partial*)    |


Supported Deployment Model
---------------------------

![deployment-model](./images/isecl_deploy_model.PNG)

* Build + Deployment Machine
* CSP - ISecL Services Machine
* CSP - Physical Server as per supported configurations
* Enterprise - ISecL Services Machine

Packages & Repos Installed by Role on RHEL
------------------------------------------

* tar
* dnf-plugins-core
* https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm


The below is installed for only `Launch Time Protection - Container Confidentiality with CRIO Runtime` Usecase on Enterprise and Compute Node
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/cri-o-1.17.5-4.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-1.0.7-13.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-debuginfo-1.0.7-13.el8.x86_64.rpm
* https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/1.17/CentOS_8/x86_64/golang-github-cpuguy83-go-md2man-debugsource-1.0.7-13.el8.x86_64.rpm 
* docker-ce-19.03.13
* skopeo
* crio
> **Note** : As part of CRIO installation,  this role would also configure crio runtime to work with Intel® SecL-DC

Repo & Key Installed by Role on Ubuntu
--------------------------------------------

* https://apt.postgresql.org/pub/repos/apt
* https://www.postgresql.org/media/keys/ACCC4CF8.asc


Supported Usecases and  Corresponding Components
------------------------------------------------

The following usecases are supported and the respective variables can be provided directly in the playbook or `--extra-vars` in command line.

| Usecase                                            | Variable                                                     |
| -------------------------------------------------- | ------------------------------------------------------------ |
| Host Attestation                                   | `setup: host-attestation` in playbook or via `--extra-vars` as `setup=host-attestation` in CLI |
| Application Integrity                              | `setup: application-integrity` in playbook or via `--extra-vars` as `setup=application-integrity` in CLI |
| Data Fencing & Asset Tags                          | `setup: data-fencing` in playbook or via `--extra-vars` as `setup=data-fencing` in CLI |
| Trusted Workload Placement - VM            | `setup: trusted-workload-placement-vm` in playbook or via `--extra-vars` as `setup=trusted-workload-placement-vm` in CLI |
| Trusted Workload Placement - Containers            | `setup: trusted-workload-placement-containers` in playbook or via `--extra-vars` as `setup=trusted-workload-placement-containers` in CLI |
| Launch Time Protection - VM Confidentiality        | `setup: workload-conf-vm` in playbook or via `--extra-vars` as `setup=workload-conf-vm` in CLI || 
| Launch Time Protection - Container Confidentiality with CRIO Runtime | `setup: workload-conf-containers-crio` in playbook or via `--extra-vars` as `setup=workload-conf-crio`in CLI |
| Secure Key Caching                                 | `setup: secure-key-caching` in playbook or via `--extra-vars` as `setup=secure-key-caching`in CLI |
| SGX Orchestration Kubernetes                      | `setup: sgx-orchestration-kubernetes` in playbook or via `--extra-vars` as `setup=sgx-orchestration-kubernetes`in CLI |
| SGX Attestation Kubernetes                        | `setup: sgx-attestation-kubernetes` in playbook or via `--extra-vars` as `setup=sgx-attestation-kubernetes`in CLI |
| SGX Orchestration Openstack                       | `setup: sgx-orchestration-openstack` in playbook or via `--extra-vars` as `setup=sgx-orchestration-openstack`in CLI |
| SGX Attestation Openstack                         | `setup: sgx-attestation-openstack` in playbook or via `--extra-vars` as `setup=sgx-attestation-openstack`in CLI |
| SKC No Orchestration                              | `setup: skc-no-orchestration` in playbook or via `--extra-vars` as `setup=skc-no-orchestration`in CLI |
| SGX Attestation No Orchestration                  | `setup: sgx-attestation-no-orchestration` in playbook or via `--extra-vars` as `setup=sgx-attestation-no-orchestration`in CLI |


The ISecL services and scripts required w.r.t each use case is as follows. The binaries and scripts are generated when Intel® SecL-DC repositories are built.

> **Note**: The DB installation done as part of this role using `Bootstrap Database` task is a local installation and not a remote DB installation.

**Host Attestation**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Application Integrity**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Data Fencing & Asset Tags**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Trust Agent

**Trusted Workload Placement - VM**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Integration Hub
7. Trust Agent
> **Note**: `Trusted Workload Placement - VM` requires orchestrators `Openstack` and `integration-hub` to be configured to talk to Openstack. 
    The playbook will place the `integration-hub` installer and configure the env except for `Openstack` configuration in the `ihub.env`. 
    Once `Openstack` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Openstack and installation of `integration-hub`<br>

**Trusted Workload Placement - Containers**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Integration Hub
7. Trust Agent
> **Note**: `Trusted Workload Placement - Containers` requires orchestrator `Kubernetes` and `integration-hub` to be configured to talk to Kubernetes. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`. 
    Once `kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Kubernetes and installation of `integration-hub`<br>

**Launch Time Protection - VM Confidentiality**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Workload Service
7. Key Broker Service
8. Workload Policy Manager
9. Trust Agent
10. Workload Agent
> **Note**: `Trusted Workload Placement - VM` requires orchestrators `Openstack` and `integration-hub` to be configured to talk to Openstack. 
    The playbook will place the `integration-hub` installer and configure the env except for `Openstack` configuration in the `ihub.env`. 
    Once `Openstack` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 
    Please refer product guide for supported versions of Openstack and installation of `integration-hub`<br>
> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes control-plane. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**Launch Time Protection - Container Confidentiality with CRIO Runtime**

1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. Populate Users (scripts)
5. Host Verification Service
6. Workload Service
7. Key Broker Service
8. Docker(Runtime)
9. Skopeo
10. Workload Policy Manager
11. Trust Agent
12. Crio(Runtime)
13. Workload Agent
> **Note**: `Launch Time Protection - Container Confidentiality with CRIO Runtime` requires `Kubernetes` orchestrator .
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `Kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes control-plane. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**Secure Key Caching**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SGX Quote Verfication Service
7. Key Broker Service
8. SGX Agent
9. SKC Library

**SGX Orchestration Kubernetes**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. Key Broker Service
9. SGX Agent
10. SKC Library
> **Note**: `SGX Orchestration Kubernetes` requires `kubernetes` orchestrator 
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes`  configuration in the `ihub.env`.  
    Once `kubernetes`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes control-plane. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**SGX Attestation Kubernetes**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. SGX Agent
9. SGX Dependencies
> **Note**: For`SGX Attestation Kubernetes` orchestration is optional. It requires `kubernetes` orchestrator.
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `kubernetes` configuration in the `ihub.env`.  
    Once `kubernetes` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

> **Note:** In addition to this `isecl-k8s-extensions` need to be installed on Kubernetes control-plane. 
    Please refer product guide for supported versions of orchestrator and setup details for installing `isecl-k8s-extensions`<br>

**SGX Orchestration Openstack**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. Key Broker Service
9. SGX Agent
10. SKC Library
> **Note**: `SGX Orchestration openstack` requires `openstack` orchestrator 
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `openstack`  configuration in the `ihub.env`.  
    Once `openstack`  is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

**SGX Attestation Openstack**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Host Verification Service
6. SKC Integration Hub
7. SGX Quote Verfication Service
8. SGX Agent
9. SGX Dependencies
> **Note**: For`SGX Attestation Openstack` orchestration is optional. It requires `openstack` orchestrator.
    In addition to this, it also requires the installation of `integration-hub` to talk to the orchestrator. 
    The playbook will place the `integration-hub` installer and configure the env except for `openstack` configuration in the `ihub.env`.  
    Once `openstack` is installed and running, `ihub.env` can be updated for `tenant` configuration and installed. 

**SKC No Orchestration**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Quote Verfication Service
6. Key Broker Service
7. SGX Agent
8. SKC Library

**SGX Attestation No Orchestration**
1. Certificate Management Service
2. Bootstrap Database (scripts)
3. Authentication & Authorization Service
4. SGX Caching Service
5. SGX Quote Verfication Service
6. SGX Agent
7. SGX Dependencies

Example Inventory and Vars
--------------------------

In order to deploy Intel® SecL-DC binaries, the following inventory can be used and the required inventory vars as below need to be set. The below example inventory can be created under `/etc/ansible/hosts`

On RHEL:
```
[CSP]
<machine1_ip/hostname>

[Enterprise]
<machine2_ip/hostname>

[Node]
<machine3_ip/hostname>

[CSP:vars]
isecl_role=csp
ansible_user=root
ansible_password=<password>

[Enterprise:vars]
isecl_role=enterprise
ansible_user=root
ansible_password=<password>

[Node:vars]
isecl_role=node
ansible_user=root
ansible_password=<password>
```

On Ubuntu: (Only applicable for SKC usecases)
```
[CSP]
<machine1_ip/hostname>

[Enterprise]
<machine2_ip/hostname>

[Node]
<machine3_ip/hostname>

[CSP:vars]
isecl_role=csp
ansible_user=<ubuntu_user>
ansible_password=<password>

[Enterprise:vars]
isecl_role=enterprise
ansible_user=<ubuntu_user>
ansible_password=<password>

[Node:vars]
isecl_role=node
ansible_user=<ubuntu_user>
ansible_password=<password>
```

> **Note:** Ansible requires `ssh` and `root` user access to remote machines. The following command can be used to ensure ansible can connect to remote machines with host key check `
  ```shell
  ssh-keyscan -H <ip_address/hostname> >> /root/.ssh/known_hosts
  ```

Using the Role in Ansible
-------------------------

The role can be cloned locally from git and the contents can be copied to the roles folder used by your ansible server <br>

```shell
#Create directory for using ansible deployment
mkdir -p /root/intel-secl/deploy/

#Clone the repository
cd /root/intel-secl/deploy/ && git clone https://github.com/intel-secl/utils.git

#Checkout to specific release version
cd utils/
git checkout <release-version of choice>
cd tools/ansible-role

#Update `roles_path` under `ansible.cfg` to point to /root/intel-secl/deploy/utils/tools/
```



Example Playbook and CLI
------------------------

The following are playbook and CLI example for deploying Intel® SecL-DC binaries based on the supported deployment models and usecases. The below example playbooks can be created as `site-bin-isecl.yml`

> **Note:** If running behind a proxy, update the proxy variables under `vars/main.yml` and run as below

> **Note:** Go through the `Additional Examples and Tips` section for specific workflow samples

Playbook

```yaml
- hosts: all
  any_errors_fatal: true
  gather_facts: yes
  vars:
    setup: <setup var from supported usecases>
    binaries_path: <path where built binaries are copied to>
  roles:   
  - ansible-role
  environment:
    http_proxy: "{{http_proxy}}"
    https_proxy: "{{https_proxy}}"
    no_proxy: "{{no_proxy}}"
```

and

```shell
ansible-playbook <playbook-name>
```

> **Note:** Update the `roles_path` under `ansible.cfg` to point to the cloned repository so that the role can be read by Ansible


or (skip `vars` from above playbook and provide using CLI of ansible)

Playbook

```yaml
- hosts: all
  any_errors_fatal: true 
  gather_facts: yes
  roles:   
  - ansible-role
  environment:
    http_proxy: "{{http_proxy}}"
    https_proxy: "{{https_proxy}}"
    no_proxy: "{{no_proxy}}"
```

and

```shell (on RHEL)
ansible-playbook <playbook-name> --extra-vars setup=<setup var from supported usecases> --extra-vars binaries_path=<path where built binaries are copied to>
```

```shell (on Ubuntu)(SKC usecases only)
ansible-playbook <playbook-name> --extra-vars setup=<setup var from supported usecases> --extra-vars binaries_path=<path where built binaries are copied to> --extra-vars "ansible_sudo_pass=<password>"
```

> **Note:** Update the `roles_path` under `ansible.cfg` to point to the cloned repository so that the role can be read by Ansible


Additional Workflow Examples
----------------------------

#### TBoot Installation

Tboot needs to be built by the user from tboot source and the `tboot.gz` & `tboot-syms` files needs to be copied under the `binaries` folder. The supported version of Tboot as of 4.0 release is `tboot-1.10.1`.The options must then be provided during runtime in the playbook:

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars tboot_gz_file=<path where built binaries are copied to>/tboot.gz
--extra-vars tboot_syms_file=<path where built binaries are copied to>/tboot-syms
```

or 

Update the following in `vars/main.yml`

```yaml
# The TPM Storage Root Key(SRK) Password to be used if TPM is already owned
tboot_gz_file: "<binaries_path>/tboot.gz"
tboot_syms_file: "<binaries_path>/tboot-syms"
```

#### TPM is already owned

If the Trusted Platform Module(TPM) is already owned, the owner secret(SRK) can be provided directly during runtime in the playbook:

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars tpm_secret=<tpm owner secret>
```
or

Update the following vars in `vars/main.yml`

```yaml
# The TPM Storage Root Key(SRK) Password to be used if TPM is already owned
tpm_owner_secret: <tpm_secret>
```

#### UEFI SecureBoot enabled

If UEFI mode and UEFI SecureBoot feature is enabled, the following option can be used to during runtime in the playbook

```shell
ansible-playbook <playbook-name> \
--extra-vars setup=<setup var from supported usecases> \
--extra-vars binaries_path=<path where built binaries are copied to> \
--extra-vars uefi_secureboot=yes \
--extra-vars grub_file_path=<uefi mode grub file path>
```

or

Update the following vars in `vars/main.yml`

```yaml
# UEFI mode or UEFI SecureBoot mode
# ['no' - UEFI mode, 'yes' - UEFI SecureBoot mode]
uefi_secureboot: 'yes'

# The grub file path for UEFI Mode systems
# [/boot/efi/EFI/redhat/grub.cfg - UEFI Mode]
grub_file_path: /boot/efi/EFI/redhat/grub.cfg
```



#### In case of Misconfigurations 

If any service installation fails due to any misconfiguration, just uninstall the specific service manually , fix the misconfiguration in ansible and rerun the playbook. The successfully installed services wont be reinstalled.


Intel® SecL-DC Services Details
-------------------------------

The details for the file locations of Intel® SecL-DC services are as follows as per the installation done by the role

**Certificate Management Service**<br>

Installation log file: `/root/certificate_management_service-install.log`<br>
Service files: `/opt/cms`<br>
Configuration files: `/etc/cms`<br>
Log files: `/var/log/cms`<br>
Default Port: `8445`<br>
<br>

**Authentication and Authorization Service**<br>

Installation log file: `/root/authentication_authorization_service-install.log`<br>
Service files: `/opt/aas`<br>
Configuration files: `/etc/aas`<br>
Log files: `/var/log/aas`<br>
Default Port: `8444`<br>
<br>

**Host Verification Service**<br>

Installation log file: `/root/host_verification_service-install.log`<br>
Service files: `/opt/hvs`<br>
Configuration files: `/etc/hvs`<br>
Log files: `/var/log/hvs`<br>
Default Port: `8443`<br>
<br>

**Integration Hub**<br>

Installation log file: `/root/integration_hub-install.log`<br>
Service files: `/opt/ihub`<br>
Configuration files: `/etc/ihub`<br>
Log files: `/var/log/ihub`<br>
Default Port: `none`<br>

**Workload Service**<br>

Installation log file: `/root/workload_service-install.log`<br>
Service files: `/opt/workload-service`<br>
Configuration files: `/etc/workload-service`<br>
Log files: `/var/log/workload-service`<br>
Default Port: `5000`<br>
<br>

**Key Broker Service**<br>

Installation log file: `/root/key_broker_service-install.log`<br>
Service files: `/opt/kbs`<br>
Configuration files: `/opt/kbs/configuration`<br>
Log files: `/opt/kbs/logs`<br>
Default Port: `9443`<br>
<br>

**Workload Policy Manager**<br>

Installation log location: `/root/key_broker_service-install.log`<br>
Service files: `/opt/workload-policy-manager`<br>
Configuration files: `/etc/workload-policy-manager`<br>
Log files: `/var/log/workload-policy-manager`<br>
Default Port: `none`<br>
<br>

**Trust Agent**<br>

Installation log location: `/root/trust_agent-install.log`<br>
Service files: `/opt/trustagent`<br>
Configuration files: `/opt/trustagent/configuration`<br>
Log files: `/var/log/trustagent/`<br>
Default Port: `1443`<br>
<br>

**Workload Agent**<br>

Installation log location: `/root/workload_agent-install.log`<br>
Service files: `/opt/workload-agent`<br>
Configuration files: `/etc/workload-agent`<br>
Log files: `/var/log/workload-agent/`<br>
Default Port: `none`<br>

**SGX Caching Service**<br>

Installation log file: `/root/sgx_caching_service-install.log`<br>
Service files: `/opt/scs`<br>
Configuration files: `/etc/scs`<br>
Log files: `/var/log/scs`<br>
Default Port: `9000`<br>
<br>

**SGX Host Verification Service**<br>

Installation log file: `/root/sgx_host_verification_service-install.log`<br>
Service files: `/opt/shvs`<br>
Configuration files: `/etc/shvs`<br>
Log files: `/var/log/shvs`<br>
Default Port: `13000`<br>
<br>

**SGX Quote Verification Service**<br>

Installation log file: `/root/sgx_quote_verification_service-install.log`<br>
Service files: `/opt/sqvs`<br>
Configuration files: `/etc/sqvs`<br>
Log files: `/var/log/sqvs`<br>
Default Port: `12000`<br>
<br>

**SGX Agent**<br>

Installation log file: `/root/sgx_agent-install.log`<br>
Service files: `/opt/sgx_agent`<br>
Configuration files: `/etc/sgx_agent`<br>
Log files: `/var/log/sgx_agent`<br>
Default Port: `none`<br>
<br>

**SKC Library**<br>

Installation log file: `/root/skc_library-install.log`<br>
Service files: `/opt/skc`<br>
Configuration files: `none`<br>
Log files: `none`<br>
Default Port: `none`<br>
<br>

**SGX Dependencies**<br>

Installation log file: `/root/sgx-dependency-installer.log`<br>
Service files: `none`<br>
Configuration files: `none`<br>
Log files: `none`<br>
Default Port: `none`<br>
<br>


License
-------

BSD


Author Information
------------------

This role is developed by Intel® SecL-DC team
