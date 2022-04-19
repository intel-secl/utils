# PCS Simulator

Primary objective of PCS simulator is to simulate the PCS Service behavior for providing the SGX collaterals like PCK Certificate, PCK CRL, TCB Info and QE Identity info.

## Key features

- PCS Simulator required to Provide dummy PCKCert, PCKCRL, TCBInfo, QEId to SGX caching service.

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

````{.shell}
wget https://dl.google.com/go/go1.16.7.linux-amd64.tar.gz
tar -xzf go1.16.7.linux-amd64.tar.gz
sudo mv go /usr/local

``` {.shell}
git clone https://github.com/intel-secl/utils.git && cd utils
git checkout v4.2/develop
cd tools/skc-simulators/pcs_simulator
````

- Replace PCS URL in /etc/scs/config.yml Sample: <http://pcssimulator_ip:8080/sgx/certification/v3>
- restart SCS

```{.shell}
scs stop
scs start
```

### Steps To verify Quote with PCS-simulator

Install Enterprise services with simulator ip and port in scs.env

Extract platform data from pckidretrieval tool in SGX hardware, Execute the below command

```{.shell}
PCKIDRetrievalTool
```

Collect platform data(manifest, pceid) from csv file to update below curl command to generate pckcert.txt in below mentioned step and Execute in pcs_simulator to update pckcert.txt.

```{.shell}
curl --location --request POST 'https://sbx.api.trustedservices.intel.com/sgx/certification/v3/pckcerts?Ocp-Apim-Subscription-Key=9e0153b3f0c948d9ade866635f039e1e' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--header 'Ocp-Apim-Subscription-Key: 9e0153b3f0c948d9ade866635f039e1e' \
--data-raw '{
   "platformManifest" : "<Platform manifest>",
   "pceid" : "<pceid>"
}' \
--output pckcert.txt -v
```

Get Content-Type, Request-ID, SGX-PCK-Certificate-Issuer-Chain, SGX-PCK-Certificate-CA-Type, SGX-FMSPC from response header of above curl command and Update GetPCKCertificateCB method in main.go

Note: Update the lower case value of SGX-FMSPC in GetPCKCertificateCB method in main.go

Update pckcrl.txt files in pcs simulator by excuting below curl command

```{.shell}
curl --location --request GET 'https://sbx.api.trustedservices.intel.com/sgx/certification/v3/pckcrl?ca=platform&encoding=der' --output pckcrl.txt -v
```

Get Content-Type, Request-ID, SGX-PCK-CRL-Issuer-Chain from response header of above curl command and update GetPCKCRLCB Method in main.go.

Get FMSPC value from pckcert response header and convert the alphabets in lower case. update fmspc value in below curl command and Execute in pcs_simulator to update tcb.txt file

```{.shell}
curl --location --request GET 'https://sbx.api.trustedservices.intel.com/sgx/certification/v3/tcb?fmspc=<fmspc>' --output tcb.txt -v
```

Get Content-Type, Request-ID, SGX-TCB-Info-Issuer-Chain from response header of above curl command and update GetTCBInfoCB Method in main.go.

Excute below curl command to update qeid.txt

```{.shell}
curl --location --request GET 'https://sbx.api.trustedservices.intel.com/sgx/certification/v3/qe/identity' --output qeid.txt -v
```

Get Content-Type, Request-ID, SGX-Enclave-Identity-Issuer-Chain from response header of above curl command and update GetQEIdentityInfoCB Method in main.go.

Run command to run the PCS simulator

```{.shell}
nohup go run main.go &
```

### Generate quote in HW:

Login to SGX machine

```{.shell}
git clone https://github.com/intel/SGXDataCenterAttestationPrimitives.git
cd SGXDataCenterAttestationPrimitives/SampleCode/QuoteGenerationSample/
vim Makefile
Remove the `-l$(Uae_Library_Name)` in Makefile (at line#72)
make
./app
It will generate quote.dat , which will have decoded quote.
openssl base64 -in quote.dat -out output.dat , It will encode the quote.
Remove all new line use that 1 liner quote to verify quote verification.
```

Note: Clean the scs database if any older data exists, scs will not use cached data hence it will contact with pccs simulator. Execute the below command to clean scs database

```{.shell}
psql -U "<SCS_DB_USERNAME>" -W "<SCS_DB_PASSWORD>" -d "<SCS_DB_NAME>"
delete from fmspc_tcb_infos;
delete from pck_cert_chains;
delete from pck_certs;
delete from pck_crls;
delete from platform_tcbs;
delete from platforms;
delete from qe_identities;
```

Create Bearer Token by below curl command

```{.shell}
curl --location --request POST 'https://<kbs_ip>:<kbs_port>/aas/v1/token' \
--header 'Content-Type: application/json' \
--data-raw '{
    "username": "<KBS_USERNAME>",
    "password": "<KBS_PASSWORD>"
}'
```

### verify Quote:

```{.shell}
curl --location --request POST 'https://<sqvs_ip>:<sqvs_port>/svs/v1/sgx_qv_verify_quote' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <KBS_TOKEN>' \
--data-raw '{
    "quote": "<Quote>",
    "userData": "<DummyData>"
}'
```

Note: Above mentioned 

<dummydata> is optional so it can be any string.</dummydata>

### Direct dependencies

Name Repo URL Minimum Version Required

--------------------------------------------------------------------------------

handlers github.com/gorilla/handlers v1.4.0 mux github.com/gorilla/mux v1.7.3

# Links

<https://01.org/intel-secl/>
