// SGX Sample Attestation
//
// The project demonstrates several fundamental usages of Intel® Software Guard Extensions (Intel® SGX) SDK such as
// Initializing and destroying a SGX enclave hosted in an attestedApp
// Generate a signed SGX Report and public/private key pair inside the enclave
// Generate a quote using SCS with Intel® DCAP APIs
// Verify the SGX quote using SGX Quote Verification Service (SQVS) by a separate attestingApp
// Verify that the quote complies with a user-defined quote policy by the attestingApp
// Generate a Symmetric Wrapping Key (SWK) in the attestingApp, wrap it with enclave's public key and share it with the enclave
// Exchange encrypted secrets between the attestingApp and the enclave using the SWK.
//
//  License: Copyright (C) 2021 Intel Corporation. SPDX-License-Identifier: BSD-3-Clause
//  Title: SGX Sample Attestation
//  Version: 1
//  Host: attestedapp.com:9000
//  BasePath: /
//
//  Schemes: https
//
//  SecurityDefinitions:
//   bearerAuth:
//     type: apiKey
//     in: header
//     name: Authorization
//     description: Enter your bearer token in the format **Bearer &lt;token&gt;**
//
// swagger:meta
package docs
