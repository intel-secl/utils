/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"crypto/rand"
	"encoding/base64"
	"github.com/intel-secl/sample-sgx-attestation/v5/attestingApp/controllers"
	"github.com/intel-secl/sample-sgx-attestation/v5/common"
	"github.com/pkg/errors"
	"math/big"
	"strconv"
)

func (a *App) startVerifier() error {
	log.Trace("app:startVerifier() Entering")
	defer log.Trace("app:startVerifier() Leaving")

	c := a.configuration()
	if c == nil {
		return errors.New("Failed to load configuration!")
	}

	log.Info("Starting Attesting App ...")

	verifyController := controllers.AppVerifierController{
		Config:             c,
		ExtVerifier:        controllers.ExternalVerifier{Config: c, CaCertsDir: common.CaCertsDir},
		SgxQuotePolicyPath: common.SgxQuotePolicyPath,
	}

	baseURL := "https://" + c.AttestedAppServiceHost + ":" + strconv.Itoa(c.AttestedAppServicePort)

	// Generate a Nonce
	var nonceLimit big.Int
	nonceLimit.Exp(big.NewInt(2), big.NewInt(common.NonceSize), nil)
	nonce, err := rand.Int(rand.Reader, &nonceLimit)
	if err != nil {
		log.Error("Error generating nonce.")
		return err
	}

	// Send a connect message and receive SGX Quote + Public key
	err, respMsg := verifyController.ConnectAndReceiveQuote(baseURL, nonce.String())

	if err != nil {
		log.Error("Error in receiving quote and public key.")
		return err
	}

	log.Info("Received public key and SGX quote from AttestedApp.")

	pubkey, err := base64.StdEncoding.DecodeString(respMsg.Userdata.Publickey)
	if err != nil {
		log.Error("Unable to decode base64 public key.")
		return err
	}

	// User Data is Public Key + Nonce
	userData := append(pubkey, nonce.Bytes()...)

	quote, err := base64.StdEncoding.DecodeString(respMsg.Quote)
	if err != nil {
		log.Error("Unable to decode base64 quote.")
		return err
	}

	// Verify SGX Quote
	status := verifyController.VerifySGXQuote(quote, userData)
	if !status {
		err = errors.New("SGX Quote verification failed!")
		log.Error("SGX Quote verification failed!")
		return err
	}

	// Generate a SWK
	log.Info("Generating SWK ...")
	swk, err := verifyController.GenerateSWK()
	if err != nil {
		log.Error("SWK Generation Failed.")
		return err
	}

	// Share SWK with  the Attested App
	err = verifyController.SharePubkeyWrappedSWK(baseURL, pubkey, swk)
	if err != nil {
		log.Error("Sending Pubkey Wrapped SWK failed!")
		return err
	}

	log.Info("SWK Shared.")

	// Share secret with the Attested App
	log.Info("Sharing secret ...")
	secret := "For your eyes only!"
	err = verifyController.ShareSWKWrappedSecret(baseURL, swk, []byte(secret))
	if err != nil {
		log.Error("Sending SWK Wrapped Secret failed!")
		return err
	}

	log.Info("Secret shared.")

	return nil
}
