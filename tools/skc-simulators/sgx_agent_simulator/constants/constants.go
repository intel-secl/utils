/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package constants

const (
	HomeDir                   = "/opt/sgx_agent/"
	ConfigDir                 = "/etc/sgx_agent/"
	ExecLinkPath              = "/usr/bin/sgx_agent"
	RunDirPath                = "/run/sgx_agent"
	LogDir                    = "/var/log/sgx_agent/"
	LogFile                   = LogDir + "sgx_agent.log"
	SecurityLogFile           = LogDir + "sgx_agent-security.log"
	HTTPLogFile               = LogDir + "http.log"
	ConfigFile                = "config.yml"
	NumberOfHosts             = 50
	PCKDataFile               = "/opt/pckData"
	TrustedCAsStoreDir        = ConfigDir + "certs/trustedca/"
	CmsTLSCertDigestEnv       = "CMS_TLS_CERT_SHA384"
	SGXAgentLogLevel          = "SGX_AGENT_LOGLEVEL"
	DefaultLogEntryMaxLength  = 300
	ServiceRemoveCmd          = "systemctl disable sgx_agent"
	ExplicitServiceName       = "SGX Agent"
	SGXAgentUserName          = "sgx_agent"
	DefaultWaitTime           = 5
	DefaultRetryCount         = 5
	DefaultSHVSUpdateInterval = 120
	DefaultHostStartId        = 1
	EncPPIDKey                = "encrypted_ppid"
	CPUSvnKey                 = "cpu_svn"
	PceSvnKey                 = "pce_svn"
	PceIDKey                  = "pce_id"
	QeIDKey                   = "qe_id"
	ManifestKey               = "manifest"
)
