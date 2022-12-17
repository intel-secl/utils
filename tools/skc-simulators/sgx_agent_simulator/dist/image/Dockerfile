# Copyright (C) 2021 Intel Corporation
# SPDX-License-Identifier: BSD-3-Clause

FROM centos:8

# Set env variables
ENV SGX_AGENT_BIN dist/image/bin

COPY dist/image/create_roles.sh /create_roles.sh
RUN chmod +x /create_roles.sh
COPY $SGX_AGENT_BIN/sgx_rpm_local_repo ${PWD}/sgx_rpm_local_repo
COPY $SGX_AGENT_BIN/libdcap_quoteprov.so.1 $SGX_AGENT_BIN/pck_id_retrieval_tool_enclave.signed.so /usr/sbin/ 
COPY $SGX_AGENT_BIN/PCKIDRetrievalTool /usr/sbin/
COPY $SGX_AGENT_BIN/libsgx-ra-uefi-1.11.100.2-1.el8.x86_64.rpm $PWD

RUN dnf install -qy https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf install -qy yum-utils dmidecode

RUN yum-config-manager --add-repo file://$PWD/sgx_rpm_local_repo && \
    dnf install -qy --nogpgcheck libsgx-dcap-ql && \
    rm -rf sgx_rpm_local_repo /etc/yum.repos.d/*sgx_rpm_local_repo.repo

RUN rpm -ivh libsgx-ra-uefi-1.11.100.2-1.el8.x86_64.rpm

COPY out/sgx_agent /usr/bin/sgx_agent
COPY dist/image/entrypoint.sh /entrypoint.sh
RUN touch /.container-env && chmod +x /entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
