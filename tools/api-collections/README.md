# Intel® Security Libraries for Data Center API Collections	

One click Postman API Collections for Intel® SecL-DC use-cases.


## Use Case Collections

| Use case               | Sub-Usecase                                   | API Collection     |
| ---------------------- | --------------------------------------------- | ------------------ |
| Foundational Security  | Host Attestation(RHEL & VMWARE)                              | ✔️                  |
|                        | Data Fencing  with Asset Tags(RHEL & VMWARE)                 | ✔️                  |
|                        | Trusted Workload Placement (VM & Containers)  | ✔️ |
|                        | Application Integrity                         | ✔️                  |
| Launch Time Protection | VM Confidentiality                            | ✔️                  |
|                        | Container Confidentiality with CRIO Runtime   | ✔️                  |
| SGX Attestation Infra & Secure Key Caching | Secure Key Caching | ✔️ |
|  | SGX Discovery & Provisioning | ✔️ |
|  | SGX Discovery, Provisioning & Orchestration | ✔️ |

> **Note: ** `Foundational Security - Host Attestation` is a pre-requisite for all usecases beyond Host Attestation. E.g: For working with `Launch Time Protection - VM Confidentiality` , Host Attestation flow must be run as a pre-req before trying VM Confidentiality

## Requirements

* Intel® SecL-DC services installed and running as per chosen use case and deployment model supported as per Quick Start Guide/Product Guide.
* [Quick Start Guides]([docs/quick-start-guides at master · intel-secl/docs (github.com)](https://github.com/intel-secl/docs/tree/master/quick-start-guides))
* [Product Guides](https://github.com/intel-secl/docs/tree/master/product-guides)
* Postman client [downloaded](https://www.postman.com/downloads/) and Installed or accessible via web

## Using the API Collections

### Downloading API Collections

* Postman API Network for latest released collections: https://explore.postman.com/intelsecldc

  or 

* Github repo for all releases

  ```shell
  #Clone the github repo for api-collections
  git clone https://github.com/intel-secl/utils.git
  
  #Switch to specific release-version of choice
  cd utils/
  git checkout <release-version of choice>
  
  #Import Collections from
  cd tools/api-collections
  ```
  > **Note:**  The postman-collections are also available when cloning the repos via build manifest under `utils/tools/api-collections`



### Running API Collections

* Import the collection into Postman API Client

  > **Note:** This step is required only when not using Postman API Network and downloading from Github

  ![importing-collection](./images/importing_collection.gif)

* Update env as per the deployment details for specific use case

  ![updating-env](./images/updating_env.gif)

* View Documentation

  ![view-docs](./images/view_documentation.gif)

* Run the workflow

  ![running-collection](./images/running_collection.gif)

