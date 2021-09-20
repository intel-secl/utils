# Trust Agent Simulator

The Trust Agent Simulator could be used for simulating Trust Agents for performance testing of ISecl compoonents - in particular the HVS. The Trust Agent Simulator can simulate thousands of hosts in a single process. The simulated hosts can either be https servers or publish data to a channel on a NATS server.
- The Trust Agent Simulator that hosts multiple `https servers` with one port per simulated host could simulate upto 25,000 hosts on a single Linux server. The number of servers and starting port number can be configured through the config file.
- The Trust Agent Simulator that publishes data on to a NATS channel can simulate upto 10K hosts.

## Building from Source code

The Trust Agent Simulator is written in Go and the only tool that is needed for building it is Go

- Requires Go Version 1.16 or later

Simplest way to build the Trust Agent invoke the make commands from the commandline. This will produce an installer that will be located in deployments/installer/

```shell
cd tools/ta-sim
make installer
cp deployments/installer/ta-sim-v4.0.bin <target_directory>
```

If this is the first time that you are installing the Trust Agent Simulator, a helper .env file is also provided that can be used to automate the install of the product. Copy the .env file to the home directory of the user installing the simulator. Details about environment variables are documented in a sample env file [TA Simulator env file](go-ta-sim.env)

```shell
cp deployments/installer/go-ta-sim.env ~
```

There are advanced options to build the simulator such as the `ta-sim` binary alone. Please refer to the `Makefile` in the source.

## Installing

Copy installer to a machine that has access to the HVS privacy CA certificate and private key. Please refer to the env file documentation for further details. Use the `go-ta-sim.env` for easier setup and avoiding prompts during installation. Please refer to [go-ta-sim.env section](go-ta-sim.env)


Run the installer

```shell
cp go-ta-sim.env ~
./ta-sim-v4.0.bin
```

Some of the required values will be prompted for by the installer if they are not set via the .env file. For others that are needed, the installer will error out. Please check the documentation of the .env file for setting the necessary ones. If the TA service mode is not set, the default mode will be set to "http", which would require a trustagent to be running as https service to download TPM-quote and host-info to simulate the responses. The TA_SERVICE_MODE variable will also define the mode of the simulated trustagents. i.e If an actual trustagent agent from which the simulator downloads data from is running with an outbound communication, the simulated hosts from ta-simulator will also create outbound connection with the same NATS server as the trustagent.  

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

To stop the simulator running with http connections, use helper script which looks for the process running the simulator and kills it

```shell
cd /opt/go-ta-simulator
./tagent-sim stop
```

## Uninstalling Trust Agent Simulator

Uninstalling the Trust Agent Simulator is as simple as stopping the TA simulator and removing the contents from the installed directory.
In case of outbound communication, the `stop` command will close all the client connections with the NATS server.

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
