# Trust Agent Simulator

The Trust Agent Simulator could be used for simulating Trust Agents for performance testing of ISecl compoonents - in particular the HVS. The Trust Agent Simulator can simulate thousands of hosts in a single process. A single process hosts multiple `https servers` with one port per simulated host. Typically, you could simulate upto 25,000 hosts on a single Linux server. The number of servers and starting port number can be configured through the config file.

## Building from Source code

The Trust Agent Simulator is written in Go and the only tool that is needed for building it is Go

- Requires Go Version 1.14 or later

Simplest way to build the Trust Agent invoke the make commands from the commandline. This will produce an installer that will be located in deployments/installer/

```shell
cd tools/ta-sim
make installer
cp deployments/installer/ta-sim-v4.2.0.bin <target_directory>
```

If this is the first time that you are installing the Trust Agent Simulator, a helper .env file is also provided that can be used to automate the install of the product. Copy the .env file to the home directory of the user installing the simulator. Details about environment variables are documented in go-ta-env section below.

```shell
cp deployments/installer/go-ta-sim.env ~
```

There are advanced options to build the simulator such as the `ta-sim` binary alone. Please refer to the `Makefile` in the source.

## Installing

Copy installer to a machine that has access to the HVS privacy CA certificate and private key. Please refer to the env file documentation for further details. Use the `go-ta-sim.env` for easier setup and avoiding prompts during installation. Please refer to [go-ta-sim.env section](#go-ta-sim.env-File-Environment-variables)

Run the installer

```shell
cp go-ta-sim.env ~
./ta-sim-v4.2.0.bin
```

Some of the required values will be prompted for by the installer if they are not set via the .env file. For others that are needed, the installer will error out. Please check the documentation of the .env file for setting the necessary ones.

After successful installation, make configuration changes in the configuration file located at `/opt/go-ta-simulator/configuration/config.yml`.

Some of the value are discussed here

```shell
# PortStart - starting port number of the ports where web servers are listening on - one for each unique simulated host
PortStart : 10000

# Servers - Number of servers. PortStart and Servers should be set appropriately to make sure that there are no conflicting servers in the port range. For instance. In this example, the simulator will have a https server running on ports from 10000 to  10099 - make sure no other services are occupying ports in this range
Servers : 100

# Number of unique Platform and OS flavors that will be created. In this example, 5 Platform and 5 OS flavors will be created
DistinctFlavors : 5

# Number of milliseconds that simulates the TPM response time on the Node
QuoteDelayMs : 500

# Number of simulataneous threads - will wait for response to these to complete before sending another batch
RequestVolume : 50

# Indicates the Percentage of Hosts for which unique flavors are created. In this case, only 99 Host unique flavors would be registered since we have 100 servers - All 100 hosts would still be registered
TrustedHostsPercentage : 99
```

## Using the Trust Agent Simulator

Once configured, the Trust Agent simulator can be used to create flavors, and register hosts to support simulation.

```shell
cd /opt/go-ta-simulator
# start the simulator using the helper script. This script will set the ulimit and keep the process in the background
./tagent-sim start
# Create Flavors. In order for hosts to be trusted, it needs the software flavors as well (TA simulator does not generate software flavors). To address this problem, import flavors into HVS from a real Trust Agent which will import the necessary flavors into the "automatic" flavorgroup.
./ta-sim create-all-flavors

# Create Hosts.
./ta-sim create-all-hosts

# Leave the simulator running so that HVS can contact the simulated host to create and refresh hosts.
```

To stop the simulator, use helper script which looks for the process running the simulator and kills it

```shell
cd /opt/go-ta-simulator
./tagent-sim stop
```

## Uninstalling Trust Agent Simulator

Uninstalling the Trust Agent Simulator is as simple as stopping the TA simulator and removing the contents from the installed directory

```shell
/opt/go-ta-simulator/tagent-sim stop
rm -rf /opt/go-ta-simulator
```

## Moving Simulator to another server

The Simulator can be moved from one machine to another (as long as it is communicating with the same HVS and AAS) by copying the contents of the /opt/go-ta-simulator folder. If running multiple TA simulators, make sure the hardware uuids do not conflict. This can be done by zeroing out or deleting the hw_uuid_map.json file

```shell
cd /opt/go-ta-simulator
# Edit contents of config.yml 
vi configuration/config.yml
# change the SimulatorIP to reflect the IP of the new system 
#save the file
cat /dev/null > configuration/hw_uuid_map.json
# rm configuration/hw_uuid_map.json
# start the server and create flavor and hosts as explained previously
```

The Simulator can be stopped and restarted as needed. The simulator stores the simulated hardware uuids in a file in configuration/hw_uuid_map.json file. This ensures that when the Simulator is restarted, the hardware uuid and the connection strings (based on port numbers) matches.

### go-ta-sim.env File Environment variables

The following are contents of the env file

```shell
# Some variables will be prompted if they are not set. The ones that are prompted will be indicated in this
# document. For those variables that are not set and does not have default values, set them in the env file or export them from the terminal

# TA_IP is used to indicate the IP address of the a real trust agent where information can be copied from.
# Leave this as blank if the default response file can be used
TA_IP=1.2.3.4

# TA_PORT - default port 8443 - set if it needs to be overridden
TA_PORT=1443

# TA_SIM_IP - IP address where the TA simulator will be installed. Use IP address of machine where it is being installed. 
TA_SIM_IP=1.2.3.5

# AAS_IP - IP address where AAS is installed - used to get the token to request certificate. If commented, installer will prompt
AAS_IP=1.2.3.6

# AAS_PORT - default port 8444 - set if it needs to be overridden
AAS_PORT=8444

# CMS_IP - IP address of CMS. If commented, installer will prompt and default response is to use AAS IP address
CMS_IP=1.2.3.7

# CMS_PORT - default port 8445 - set if it needs to be overridden
CMS_PORT=8445

# HVS_IP - IP address of HVS. If commented, installer will prompt and default response is to use AAS IP address
HVS_IP=1.2.3.8

# HVS_PORT - leave commented if default port of 8443 is being used.
HVS_PORT=8443

# SIM_TLS_CERT_CN - Common name for Simulator TLS certificate. default value - "TA Simulator TLS Certificate"
SIM_TLS_CERT_CN="TA Simulator TLS Certificate"

# SIM_TLS_CERT_SAN - Subject alternative name/ IP address where TA simulator is running. Default value - '*'.
# Default value enables installer to request any SAN in the CSR sent to CMS. 
SIM_TLS_CERT_SAN="*"

# AAS_USERNAME - Installer will prompt if not set. User needs access to AAS, HVS and TA APIs. The Global Admin may be used for this purpose
AAS_USERNAME=<user with access to AAS, HVS and TA APIs>

# AAS_PASSWORD - if not set, installer will prompt.
AAS_PASSWORD=<password for user>

# PRIVACY_CA_CERT_PATH - - default value - /etc/hvs/certs/trustedca/privacy-ca/privacy-ca-cert.pem 
# The installer needs access to the HVS Privacy CA and private key in order to create an AIK certificate that can be used by the Trust Agent simulator. 
PRIVACY_CA_CERT_PATH=<path to HVS Privacy CA>

# PRIVACY_CA_KEY_PATH - Path to Privacy CA key that corresponds to the Privacy CA cert.
# default value - /etc/hvs/trusted-keys/privacy-ca.key
PRIVACY_CA_KEY_PATH=<path to HVS Privacy CA Private Key>

# An existing AIK certificate, Aik private key and Binding key from from another 
# TA simulator could be used instead of generating a new one. However, the AIK certificate
# and binding key would only valid for the same HVS. Different HVS will have a different
# Privacy CA and therefore the these will need to be regenerated.
# Use the below AIK_CERT_PATH, AIK_KEY_PATH, BINDING_KEY_CERT_PATH to set these.

# AIK_CERT_PATH - don't set if PRIVACY_CA_CERT_PATH and PRIVACY_CA_KEY_PATH are set.
# copy from a valid TA simulator and set AIK_CERT_PATH
AIK_CERT_PATH=<path to existing aik certificate that has been signed by Privacy CA>

# AIK_KEY_PATH - corresponding private key
# don't set if PRIVACY_CA_CERT_PATH and PRIVACY_CA_KEY_PATH are set. 
# copy from a valid TA simulator and set AIK_KEY_PATH
AIK_KEY_PATH=<path to Private Key for the AIK certificate>


# BINDING_KEY_CERT_PATH - Binding key certificate copied from another TA simulator that is in
# the same set as the AIK. 
# copy from a valid TA simulator and set BINDING_KEY_CERT_PATH
# don't set if PRIVACY_CA_CERT_PATH and PRIVACY_CA_KEY_PATH are set. 
BINDING_KEY_CERT_PATH=<path to Binding Key Certificate that is created using the AIK>
```
