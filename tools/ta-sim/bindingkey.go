/*
 * Copyright (C) 2020  Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/binary"
	"encoding/hex"

	"github.com/intel-secl/intel-secl/v5/pkg/lib/privacyca"
	pcaConsts "github.com/intel-secl/intel-secl/v5/pkg/lib/privacyca/constants"
	wlaModel "github.com/intel-secl/intel-secl/v5/pkg/model/wlagent"
	"github.com/pkg/errors"
)

// this file reference hvs code in pkg/hvs/controllers/certify_host_keys_controller.go

// reference the file common/key_registration.go for contents in this structure
// refer the RegisterKeyInfo struct

func generateRegisterKeyInfo(aik, bindingKey *rsa.PrivateKey, aikCertByte []byte) (wlaModel.RegisterKeyInfo, error) {

	// pkg\lib\privacyca\tpm2utils\tpm2_certified_key.go: PopulateTpmCertifyKey20

	tpmCertifyKey := bytes.NewBuffer([]byte{})
	binary.Write(tpmCertifyKey, binary.BigEndian, pcaConsts.Tpm2CertifiedKeyMagic)
	binary.Write(tpmCertifyKey, binary.BigEndian, pcaConsts.Tpm2CertifiedKeyType)
	binary.Write(tpmCertifyKey, binary.BigEndian, uint16(6))
	// write with some random data
	binary.Write(tpmCertifyKey, binary.BigEndian, [6]byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06})

	binary.Write(tpmCertifyKey, binary.BigEndian, uint16(6))
	// write with some random data
	binary.Write(tpmCertifyKey, binary.BigEndian, [6]byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06})

	// write with 25 0x00 (Clock 8 bytes, ResentCount 5 bytes, RestartCount 4 bytes, Safe 1 byte, FirmwareVersion 8 bytes)
	binary.Write(tpmCertifyKey, binary.BigEndian, [25]byte{})

	binary.Write(tpmCertifyKey, binary.BigEndian, uint16(34))
	binary.Write(tpmCertifyKey, binary.BigEndian, uint16(pcaConsts.TPM_ALG_ID_SHA256))
	// random sha256 digest
	nameDigest, _ := hex.DecodeString("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	binary.Write(tpmCertifyKey, binary.BigEndian, nameDigest)

	paddingHead, _ := hex.DecodeString(pcaConsts.Tpm2NameDigestPrefixPadding)
	paddingTail, _ := hex.DecodeString(pcaConsts.Tpm2NameDigestSuffixPadding)
	nameDigest = append(paddingHead, nameDigest...)
	nameDigest = append(nameDigest, paddingTail...)

	binary.Write(tpmCertifyKey, binary.BigEndian, uint16(len(nameDigest)))
	binary.Write(tpmCertifyKey, binary.BigEndian, nameDigest)

	h := sha256.New()
	h.Write(tpmCertifyKey.Bytes())

	signature, err := rsa.SignPKCS1v15(rand.Reader, aik, crypto.SHA256, h.Sum(nil))
	if err != nil {
		return wlaModel.RegisterKeyInfo{}, errors.Wrap(err, "failed to sign certify key with aik")
	}

	err = rsa.VerifyPKCS1v15(&aik.PublicKey, crypto.SHA256, h.Sum(nil), signature)
	if err != nil {
		return wlaModel.RegisterKeyInfo{}, errors.Wrap(err, "signature can not be verified")
	}

	return wlaModel.RegisterKeyInfo{
		PublicKeyModulus:       bindingKey.PublicKey.N.Bytes(),
		TpmCertifyKey:          tpmCertifyKey.Bytes(),
		TpmCertifyKeySignature: append([]byte{0x01, 0x02}, signature...),
		NameDigest:             nameDigest,
		AikDerCertificate:      aikCertByte,
		TpmVersion:             "2.0",
		OsType:                 "linux",
	}, nil
}

func createBindingKeyCert(pcaKey crypto.PrivateKey, pcaCert *x509.Certificate, commName string, regKeyInfo wlaModel.RegisterKeyInfo) ([]byte, error) {

	certifyKey20, err := privacyca.NewCertifyKey(regKeyInfo)
	if err != nil {
		return nil, errors.Wrap(err, "failed to create privacy ca certify key instance")
	}
	rsaPubKey, err := certifyKey20.GetPublicKeyFromModulus()
	if err != nil {
		return nil, errors.Wrap(err, "Error while retrieving public key modulus")
	}
	certificate, err := certifyKey20.CertifyKey(pcaCert, rsaPubKey, pcaKey.(*rsa.PrivateKey), commName)
	if err != nil {
		return nil, errors.Wrapf(err, "controllers/certify_host_keys_controller:generateCertificate() Error while Certifying key")
	}
	return certificate, nil
}
