/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package common

const (
	DefaultAttestedAppHost = "127.0.0.1"
	DefaultAttestedAppPort = 9999
)

const (
	ConfigDir             = "./"
	CaCertsDir            = "./"
	DefaultConfigFilePath = ConfigDir + "config.yml"
	ConfigFile            = "config"
	SgxQuotePolicyPath    = ConfigDir + "sgx-quote-policy.txt"
	EndLine               = "\n"
	VerifyQuote           = "/sgx_qv_verify_quote"
	GetIdentity           = "/id"
	PostWrappedSWK        = "/wrapped_swk"
	PostWrappedMessage    = "/wrapped_message"
	// Enable client to verify the right cert using SNI.
	SelfSignedCertSNI = "attested.app"
	// SWK Size in bytes
	SWKSize = 32
	// NonceSize in bits
	NonceSize = 256
)

// SGX Policy
const (
	MREnclaveField  = "MREnclave"
	MRSignerField   = "MRSigner"
	CpuSvnField     = "CPU_SVN"
	PolicyFileDelim = ":"
)

// Message definitions
type UserData struct {
	Publickey string `json:"public-key"`
}

type IdentityResponse struct {
	Quote    string   `json:"quote"`
	Userdata UserData `json:"user-data"`
}

type IdentityRequest struct {
	Nonce string `json:"nonce"`
}

type WrappedSWKRequest struct {
	SWK string `json:swk`
}

type WrappedMessage struct {
	Message string `json:message`
}
