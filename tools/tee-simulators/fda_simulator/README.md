# FDA Simulator

Primary objective of FDA simulator is to simulate the FDA daemon behavior for pushing discovery data to FDS and pushing platform data to TCS.

## Key features

- FDA Simulator is required to provide push discovery data to FDS and push platform data to TCS.

## System Requirements

- Proxy settings if applicable

## Software requirements

- Go 1.16.7

# Step By Step Build Instructions

## Install required shell commands

### Disable Firewall

```{.shell}
sudo systemctl stop firewalld
```

### Install `go 1.16.7`


``` {.shell}
wget https://dl.google.com/go/go1.16.7.linux-amd64.tar.gz
tar -xzf go1.16.7.linux-amd64.tar.gz
sudo mv go /usr/local

``` {.shell}
git clone https://github.com/intel-secl/utils.git && cd utils
git checkout v5.0/develop
cd tools/tee-simulators/fda_simulator
make installer
````

Build will generate under /out folder
Copy the FDA simulator build fda-sim-vx.x.x.bin from build system to deploy system

- Run PCS simulator first
- Install FDS
- Replace PCS URL in /etc/tcs/config.yml Sample: <http://pcs_simulator_ip:8080/sgx/certification/v4>
- restart TCS

```{.shell}
tcs stop
tcs start
```

### Sample Env file for FDA simulator
- name: fda-sim.env

CMS_BASE_URL=https://<CMS IP>:8445/cms/v1/
FDS_BASE_URL=https://<FDS IP>:13000/fds/v1/
TCS_BASE_URL=https://<TCS IP>:9000/tcs/v4/sgx/

CUSTOM_TOKEN=<custom token from AAS>
NUMBER_OF_HOSTS=<No. of hosts to be simulated, ex: 1000>
HOST_START_ID=1


#### Note: Use "00b61da0-5ada-e811-906e-00163566263e" HW UUID in subject while creating FDA custom token

### Install FDA simulator

```{.shell}
./fda-sim-vx.x.x.bin
```

### Run FDA simulator

```{.shell}
fda-sim run
```
#### Note: Update soft limit for no. of open files as needed before running the simulator, ex: ulimit -n 10000

### Uninstall FDA simulator

```{.shell}
fda-sim uninstall
```