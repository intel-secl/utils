/*
 * Copyright (C) 2020  Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/asn1"
	"encoding/pem"
	"testing"

	"github.com/intel-secl/intel-secl/v5/pkg/lib/common/crypt"
	"github.com/intel-secl/intel-secl/v5/pkg/lib/privacyca"
	"github.com/intel-secl/intel-secl/v5/pkg/lib/privacyca/tpm2utils"
	model "github.com/intel-secl/intel-secl/v5/pkg/model/wlagent"
)

func TestBindingKey(t *testing.T) {

	// turns out this function "CreateKeyPairAndCertificate" only returns rsa 3072 if not given 4096 bits
	// while certifyKey20.IsCertifiedKeySignatureValid only recognizes 256 bits aik...
	//
	// aikCertByte, aikKeyDer, err := crypt.CreateKeyPairAndCertificate("aik-test", "", "rsa", 2048)
	// if err != nil {
	// 	t.Fatal("failed to generate aik:", err.Error())
	// }
	aikKey, aikCertPem, err := crypt.CreateSelfSignedCertAndRSAPrivKeys(2048)
	if err != nil {
		t.Fatal("failed to generate aik:", err.Error())
	}
	aikCertPemBlock, _ := pem.Decode([]byte(aikCertPem))
	if aikCertPemBlock == nil {
		t.Fatal("failed to decode aik cert pem")
	}
	aikCertByte := aikCertPemBlock.Bytes
	aikCert, err := x509.ParseCertificate(aikCertByte)
	if err != nil {
		t.Fatal("failed to parse aik certificate:", err.Error())
	}
	bindingKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal("failed to generate binding key:", err.Error())
	}
	rki, err := generateRegisterKeyInfo(aikKey, bindingKey, aikCert.Raw)
	if err != nil {
		t.Fatal("failed to create RegisterKeyInfo:", err.Error())
	}
	bindingKeyCertBytes, err := createBindingKeyCert(aikKey, aikCert, "binding-key", rki)
	if err != nil {
		t.Fatal("failed to create binding key cert:", err.Error())
	}
	bindingKeyCert, err := x509.ParseCertificate(bindingKeyCertBytes)
	if err != nil {
		t.Fatal("failed to parse binding key certificate:", err.Error())
	}

	tpm2CertifyKey := tpm2utils.Tpm2CertifiedKey{}
	// this function returns error in v3.3.0
	tpm2CertifyKey.PopulateTpmCertifyKey20(rki.TpmCertifyKey)

	t.Log(tpm2CertifyKey)

	pemBlock := &pem.Block{
		Type:  "CERTIFICATE",
		Bytes: aikCertByte,
	}
	t.Log(string(pem.EncodeToMemory(pemBlock)))

	pemBlock = &pem.Block{
		Type:  "CERTIFICATE",
		Bytes: bindingKeyCert.Raw,
	}
	t.Log(string(pem.EncodeToMemory(pemBlock)))

	if !verifyTpmBindingKeyCertificate(bindingKeyCert, aikCert, t) {
		t.Fatal("failed to verify binding key cert")
	}
}

// this function comes from pkg/kbs/keytransfer/transfer_with_saml.go,
// which is the function verifying binding key certificate in kbs
func verifyTpmBindingKeyCertificate(keyCert, aikCert *x509.Certificate, t *testing.T) bool {

	keyInfoOid := asn1.ObjectIdentifier{2, 5, 4, 133, 3, 2, 41}
	keySigOid := asn1.ObjectIdentifier{2, 5, 4, 133, 3, 2, 41, 1}

	tpmCertifyKeyInfo := crypt.GetCertExtension(keyCert, keyInfoOid)
	tpmCertifyKeySignature := crypt.GetCertExtension(keyCert, keySigOid)

	regKeyInfo := model.RegisterKeyInfo{
		TpmCertifyKey:          tpmCertifyKeyInfo,
		TpmCertifyKeySignature: tpmCertifyKeySignature,
		TpmVersion:             "2.0",
	}

	certifyKey20, _ := privacyca.NewCertifyKey(regKeyInfo)
	verified, err := certifyKey20.IsCertifiedKeySignatureValid(aikCert)
	if err != nil || !verified {
		t.Log(err.Error())
		t.Error("TPM Binding Public Key cannot be verified by the given AIK public key")
		return false
	}
	if !certifyKey20.IsTpmGeneratedKey() {
		t.Error("TPM Binding Key has incorrect attributes")
		return false
	}
	return true
}
