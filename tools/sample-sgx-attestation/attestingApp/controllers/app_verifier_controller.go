/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package controllers

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	cos "intel/isecl/lib/common/v5/os"
	"io"
	"io/ioutil"
	"math/big"
	"net/http"
	"strings"

	"github.com/intel-secl/sample-sgx-attestation/v5/common"
	"github.com/pkg/errors"
	logger "github.com/sirupsen/logrus"
)

// TODO : Consolidate loggers.
var log = logger.New()

type customFormatter struct {
	logger.TextFormatter
}

func (f *customFormatter) Format(entry *logger.Entry) ([]byte, error) {
	_, e := f.TextFormatter.Format(entry)
	customLog := "AttestingApp(Golang) : " + entry.Message + "\n"
	return []byte(customLog), e
}

type QuoteVerifyAttributes struct {
	ReportData             string `json:"reportData"`
	UserDataMatch          string `json:"userDataMatch"`
	Message                string `json:"Message"`
	EnclaveIssuer          string `json:"EnclaveIssuer"`
	EnclaveMeasurement     string `json:"EnclaveMeasurement"`
	EnclaveIssuerProductID string `json:"EnclaveIssuerProdID"`
	IsvSvn                 string `json:"IsvSvn"`
	TCBLevel               string `json:"TcbLevel"`
}

type AppVerifierController struct {
	Config             *common.Configuration
	ExtVerifier        ExternalVerifier
	SgxQuotePolicyPath string
}

func wrapSWKByPublicKey(swk []byte, key []byte) ([]byte, error) {
	// Public key format from the enclave : <exponent:4><modulus:n>
	exponentLength := 4

	modArr := key[exponentLength:]
	// Endianess : Key Buffer transmitted from Enclave is in LE.
	for i := 0; i < len(modArr)/2; i++ {
		modArr[i], modArr[len(modArr)-i-1] = modArr[len(modArr)-i-1], modArr[i]
	}
	modulus := big.Int{}
	modulus.SetBytes(modArr)

	exponentArr := key[:exponentLength]
	var ex int32
	buf := bytes.NewReader(exponentArr)
	err := binary.Read(buf, binary.LittleEndian, &ex)
	if err != nil {
		log.Info(err)
		return nil, errors.Wrap(err, "Failed to read exponent from key buffer.")
	}

	pubKey := rsa.PublicKey{N: &modulus, E: int(ex)}
	wrappedSWK, err := rsa.EncryptOAEP(sha256.New(), rand.Reader, &pubKey, swk, nil)
	if err != nil {
		return nil, errors.Wrap(err, "Failed to create cipher text")
	}
	return wrappedSWK, nil
}

func (ca AppVerifierController) GenerateSWK() ([]byte, error) {
	//Key for AES 256 bit
	keyBytes := make([]byte, common.SWKSize)
	_, err := rand.Read(keyBytes)
	if err != nil {
		return nil, errors.Wrap(err, "Failed to read the key bytes")
	}
	return keyBytes, nil
}

func (ca AppVerifierController) SharePubkeyWrappedSWK(baseURL string, key []byte, swk []byte) error {
	cipherText, err := wrapSWKByPublicKey(swk, key)
	if err != nil {
		log.Info("Cipher Text generation Failed.", err)
		return err
	}

	log.Info("Wrapped SWK Cipher Text Length : ", len(cipherText))

	url := baseURL + common.PostWrappedSWK

	var wsr common.WrappedSWKRequest
	wsr.SWK = base64.StdEncoding.EncodeToString(cipherText)

	reqBytes := new(bytes.Buffer)
	err = json.NewEncoder(reqBytes).Encode(wsr)
	if err != nil {
		return errors.Wrap(err, "Error in encoding SWK.")
	}

	// Send request to Attested App
	req, err := http.NewRequest("POST", url, reqBytes)
	if err != nil {
		return errors.Wrap(err, "Error in Creating request.")
	}

	req.Header.Add("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Add("Authorization", ca.Config.DummyBearerToken)

	// Get the SystemCertPool, continue with an empty pool on error
	rootCAs, _ := x509.SystemCertPool()
	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}

	// Looking for self signed certificates.
	rootCaCertPems, err := cos.GetDirFileContents("./", "cert.pem")
	if err != nil {
		return errors.Wrap(err, "Could not read root CA certificate")
	}

	for _, rootCACert := range rootCaCertPems {
		rootCAs.AppendCertsFromPEM(rootCACert)
	}

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: false,
				RootCAs:            rootCAs,
				ServerName:         common.SelfSignedCertSNI,
			},
		},
	}

	resp, err := client.Do(req)
	if resp != nil {
		defer func() {
			derr := resp.Body.Close()
			if derr != nil {
				log.WithError(derr).Error("Error closing wrapped SWK body.")
			}
		}()
	}

	if err != nil {
		log.Error(err)
		return errors.Wrap(err, "Error posting SWK Attested App.")
	}

	if resp.StatusCode != http.StatusOK {
		log.Error("Status Code : ", resp.StatusCode)
		return errors.New("Posting SWK to Attested App failed.")
	}

	return nil
}

func (ca AppVerifierController) ShareSWKWrappedSecret(baseURL string, key []byte, message []byte) error {
	log.Info("Message : ", string(message))

	if len(key) != common.SWKSize {
		log.Errorf("Key length has to be %d bytes.", common.SWKSize)
		return errors.New("Invalid key length.")
	}

	// Wrap the message with SWK
	cipherBlock, err := aes.NewCipher(key)
	if err != nil {
		log.Error("Error initialising cipher block", err)
		return err
	}

	gcm, err := cipher.NewGCM(cipherBlock)
	if err != nil {
		log.Error("Error creating GCM", err)
		return err
	}

	nonce := make([]byte, gcm.NonceSize())
	_, err = io.ReadFull(rand.Reader, nonce)
	if err != nil {
		log.Error("Error generating nonce for GCM.")
		return err
	}

	wrappedMessage := gcm.Seal(nonce, nonce, message, nil)

	// Send request to Attested App
	url := baseURL + common.PostWrappedMessage

	var wm common.WrappedMessage
	wm.Message = base64.StdEncoding.EncodeToString(wrappedMessage)
	reqBytes := new(bytes.Buffer)
	err = json.NewEncoder(reqBytes).Encode(wm)
	if err != nil {
		return errors.Wrap(err, "Error in encoding Wrapped Message.")
	}

	req, err := http.NewRequest("POST", url, reqBytes)
	if err != nil {
		return errors.Wrap(err, "Error in Creating request.")
	}

	req.Header.Add("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Add("Authorization", ca.Config.DummyBearerToken)

	// Get the SystemCertPool, continue with an empty pool on error
	rootCAs, _ := x509.SystemCertPool()
	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}

	// Look for self signed certificates
	rootCaCertPems, err := cos.GetDirFileContents("./", "cert.pem")
	if err != nil {
		return errors.Wrap(err, "Could not read root CA certificate")
	}

	for _, rootCACert := range rootCaCertPems {
		rootCAs.AppendCertsFromPEM(rootCACert)
	}

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: false,
				RootCAs:            rootCAs,
				ServerName:         common.SelfSignedCertSNI,
			},
		},
	}

	resp, err := client.Do(req)
	if resp != nil {
		defer func() {
			derr := resp.Body.Close()
			if derr != nil {
				log.WithError(derr).Error("Error closing wrapped message body.")
			}
		}()
	}

	if err != nil {
		log.Error(err)
		return errors.Wrap(err, "Error posting wrapped message Attested App.")
	}

	if resp.StatusCode != http.StatusOK {
		log.Error("Status Code : ", resp.StatusCode)
		return errors.New("Posting wrapped message to Attested App failed.")
	}
	return nil
}

func (ca AppVerifierController) ConnectAndReceiveQuote(baseURL string, nonce string) (*common.IdentityResponse, error) {

	url := baseURL + common.GetIdentity

	var idr common.IdentityRequest
	idr.Nonce = nonce

	reqBytes := new(bytes.Buffer)
	err := json.NewEncoder(reqBytes).Encode(idr)
	if err != nil {
		return nil, errors.Wrap(err, "Error in encoding the nonce.")
	}

	// Send request to Attested App
	req, err := http.NewRequest("GET", url, reqBytes)
	if err != nil {
		return nil, errors.Wrap(err, "Error in Creating request.")
	}

	req.Header.Add("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Add("Authorization", ca.Config.DummyBearerToken)

	// Get the SystemCertPool, continue with an empty pool on error
	rootCAs, _ := x509.SystemCertPool()
	if rootCAs == nil {
		rootCAs = x509.NewCertPool()
	}

	// Looking for self signed certificates.
	rootCaCertPems, err := cos.GetDirFileContents("./", "cert.pem")
	if err != nil {
		return nil, errors.Wrap(err, "Could not read root CA certificate")
	}

	for _, rootCACert := range rootCaCertPems {
		rootCAs.AppendCertsFromPEM(rootCACert)
	}

	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: false,
				RootCAs:            rootCAs,
				ServerName:         common.SelfSignedCertSNI,
			},
		},
	}

	resp, err := client.Do(req)
	if resp != nil {
		defer func() {
			derr := resp.Body.Close()
			if derr != nil {
				log.WithError(derr).Error("Error closing get quote response body.")
			}
		}()
	}

	if err != nil {
		log.Error(err)
		return nil, errors.Wrap(err, "Error fetching quote and public key from Attested App.")
	}

	if resp.StatusCode != http.StatusOK {
		log.Error("Status Code : ", resp.StatusCode)
		return nil, errors.New("Fetching quote and public key from Attested App failed.")
	}

	response, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.WithError(err).Error("Could not read Quote Response body.")
		return nil, err
	}

	// Unmarshal JSON response
	var responseAttributes common.IdentityResponse
	err = json.Unmarshal(response, &responseAttributes)
	if err != nil {
		return nil, errors.Wrap(err, "Error in unmarshalling response.")
	}

	return &responseAttributes, nil
}

func (ca AppVerifierController) VerifySGXQuote(sgxQuote []byte, userData []byte) bool {
	err := ca.verifyQuote(sgxQuote, userData)
	if err != nil {
		log.WithError(err).Errorf("Error while verifying SGX quote")
		return false
	}
	log.Info("Verified SGX quote successfully.")
	return true
}

// verifySgxQuote verifies the quote
func (ca AppVerifierController) verifyQuote(quote []byte, userData []byte) error {
	var err error

	// Initialize logger.
	Formatter := new(customFormatter)
	Formatter.DisableTimestamp = true
	log.SetFormatter(Formatter)

	// Convert byte array to string.
	qData := base64.StdEncoding.EncodeToString(quote)
	uData := base64.StdEncoding.EncodeToString(userData)

	var responseAttributes QuoteVerifyAttributes
	responseAttributes, err = ca.ExtVerifier.VerifyQuote(qData, uData)

	if err != nil {
		return errors.Wrap(err, "Error in quote verification!")
	}

	log.Printf("Verifying against quote policy stored at %s", ca.SgxQuotePolicyPath)

	// Load quote policy from path
	qpRaw, err := ioutil.ReadFile(ca.SgxQuotePolicyPath)
	if err != nil {
		return errors.Wrap(err, "Error reading quote policy file!")
	}

	// split by newline
	lines := strings.Split(string(qpRaw), common.EndLine)
	var mreValue, mrSignerValue string
	for _, line := range lines {
		// split by :
		lv := strings.Split(strings.TrimSpace(line), common.PolicyFileDelim)
		if len(lv) != 2 {
			continue
		}
		// switch by field name
		switch lv[0] {
		case common.MREnclaveField:
			mreValue = lv[1]
		case common.MRSignerField:
			mrSignerValue = lv[1]
		}
	}

	log.Infof("Quote policy has values \n\tMREnclaveField = %s \n\tMRSignerField = %s",
		mreValue, mrSignerValue)

	if responseAttributes.EnclaveIssuer != mrSignerValue {
		log.Errorf("Quote policy mismatch in %s", common.MRSignerField)
		err = errors.Errorf("Quote policy mismatch in %s", common.MRSignerField)
		return err
	} else {
		log.Infof("%s matched with Quote Policy", common.MRSignerField)
	}

	if responseAttributes.EnclaveMeasurement != mreValue {
		log.Errorf("Quote policy mismatch in %s", common.MREnclaveField)
		err = errors.Errorf("Quote policy mismatch in %s", common.MREnclaveField)
		return err
	} else {
		log.Infof("%s matched with Quote Policy", common.MREnclaveField)
	}

	if responseAttributes.UserDataMatch != "true" {
		log.Errorf("UserData (public key hash) did not match!")
		err = errors.Errorf("UserData (public key hash) did not match!")
		return err
	} else {
		log.Infof("User Data (public key hash) matched.")
	}
	return nil
}
