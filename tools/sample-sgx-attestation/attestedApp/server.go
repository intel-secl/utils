/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

// #cgo CFLAGS: -I /opt/intel/sgxsdk/include -I /opt/intel/sgxssl/include -I /usr/lib/ -I ./libenclave/safestringlib/include/ -I ./libenclave/Include/
// #cgo LDFLAGS: -L./attestedApp/out/ -L /usr/lib64  -lssl -lcrypto  -L./libenclave/safestringlib/ -lsafestring -luntrusted -L/opt/intel/sgxssl/lib64 -lsgx_usgxssl
// #include "./libenclave/Untrusted/Untrusted.h"
import "C"

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	"github.com/intel-secl/sample-sgx-attestation/v5/common"
	"github.com/pkg/errors"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"unsafe"
)

type privilegeError struct {
	StatusCode int
	Message    string
}

func (e privilegeError) Error() string {
	return fmt.Sprintf("%d: %s", e.StatusCode, e.Message)
}

type resourceError struct {
	StatusCode int
	Message    string
}

func (e resourceError) Error() string {
	return fmt.Sprintf("%d: %s", e.StatusCode, e.Message)
}

type errorHandlerFunc func(w http.ResponseWriter, r *http.Request) error

func (ehf errorHandlerFunc) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := ehf(w, r); err != nil {
		log.WithError(err).Error("HTTP Error!")
		switch t := err.(type) {
		case *resourceError:
			http.Error(w, t.Message, t.StatusCode)
		case resourceError:
			http.Error(w, t.Message, t.StatusCode)
		case *privilegeError:
			http.Error(w, t.Message, t.StatusCode)
		case privilegeError:
			http.Error(w, t.Message, t.StatusCode)
		default:
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	}
}

func (a *App) getPubkeyFromEnclave() []byte {
	var keyBuffer []byte
	var pubKeySize C.int
	var keyPtr *C.u_int8_t

	keyPtr = C.get_public_key(&pubKeySize)

	if keyPtr == nil {
		log.Error("Unable to retrive public key from enclave.")
		return nil
	}

	log.Info("getPubkeyFromEnclave : Public key length : ", pubKeySize)

	if pubKeySize == 0 {
		log.Error("Unable to retrive public key from enclave.")
		return nil
	}

	keyBuffer = C.GoBytes(unsafe.Pointer(keyPtr), pubKeySize)

	return keyBuffer
}

func (a *App) getQuoteFromEnclave(nonce string) []byte {
	var qBytes []byte

	// qSize holds the length of the quote byte array returned from enclave
	var qSize C.int

	// qPtr holds the bytes array of the quote returned from enclave
	var qPtr *C.u_int8_t

	nonceCStr := C.CString(nonce)
	if nonceCStr == nil {
		log.Error("Error marshalling nonce.")
		return nil
	}

	qPtr = C.get_sgx_quote(&qSize, nonceCStr)
	if qPtr == nil {
		log.Error("Unable to retrive quote from enclave.")
		return nil
	}

	log.Printf("Quote size : %d", qSize)
	qBytes = C.GoBytes(unsafe.Pointer(qPtr), qSize)

	return qBytes
}

// EnclaveInit initializes the enclave.
func (a *App) EnclaveInit() error {
	log.Trace("EnclaveInit Entering")
	defer log.Trace("EnclaveInit Leaving")

	var enclaveInitStatus C.int

	// Initialize enclave
	log.Info("Initializing enclave...")
	enclaveInitStatus = C.init()

	if enclaveInitStatus != 0 {
		return errors.Errorf("EnclaveInit Failed to initialize enclave. Error code: %d", enclaveInitStatus)
	}

	log.Info("Enclave initialized.")

	return nil
}

// EnclaveDestroy cleans up the enclave on exit
func (a *App) EnclaveDestroy() error {
	log.Trace("EnclaveDestroy Entering")
	defer log.Trace("EnclaveDestroy Leaving")

	// Destroy enclave
	enclaveDestroyStatus := C.destroy_enclave()

	if enclaveDestroyStatus != 0 {
		return errors.Errorf("Failed to destroy enclave. Error code: %d", enclaveDestroyStatus)
	}

	log.Info("Enclave destroyed.")

	return nil
}

func authorizeEndpoint(r *http.Request) error {
	// Dummy authorization.
	token := r.Header.Get("Authorization")
	if token != common.DummyBearerToken {
		return resourceError{Message: "Bearer token is invalid.", StatusCode: http.StatusUnauthorized}
	}

	return nil
}

// Step 1 - Receive a connect request. Respond with Quote and Public Key
func httpGetQuotePubkey(a *App) errorHandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) error {
		log.Info("Received HTTP client connection for ", common.GetIdentity)
		err := authorizeEndpoint(r)
		if err != nil {
			return err
		}

		w.Header().Set("Content-Type", "application/json")

		// Note : Robust input validation is skipped for brevity
		// Extract nonce from request
		var idr common.IdentityRequest
		err = json.NewDecoder(r.Body).Decode(&idr)
		if err != nil {
			log.Info(err)
			return resourceError{Message: "Unable to parse request.",
				StatusCode: http.StatusBadRequest}

		}
		// Get the quote from Enclave
		sgxQuote := a.getQuoteFromEnclave(idr.Nonce)
		if sgxQuote == nil {
			log.Error("Fetching quote from enclave failed!")
			w.WriteHeader(http.StatusInternalServerError)
			return &resourceError{
				Message:    "Fetching quote from enclave failed.",
				StatusCode: http.StatusInternalServerError}
		}

		// Get public key from Enclave.
		pubKey := a.getPubkeyFromEnclave()
		if pubKey == nil {
			log.Error("Fetching public key from enclave failed!")
			w.WriteHeader(http.StatusInternalServerError)
			return &resourceError{
				Message:    "Fetching public key from enclave failed.",
				StatusCode: http.StatusInternalServerError}
		}

		// Encode quote and public key.
		encodedQuote := base64.StdEncoding.EncodeToString(sgxQuote)
		encodedPublicKey := base64.StdEncoding.EncodeToString(pubKey)

		res := common.IdentityResponse{
			Quote:    encodedQuote,
			Userdata: common.UserData{Publickey: encodedPublicKey}}

		js, err := json.Marshal(res)
		if err != nil {
			return &resourceError{
				Message:    err.Error(),
				StatusCode: http.StatusInternalServerError}
		}

		_, err = w.Write(js)
		if err != nil {
			return &resourceError{
				Message:    err.Error(),
				StatusCode: http.StatusInternalServerError}
		}

		return nil
	}
}

// Step 2 : Receive Wrapped SWK from Attesting App
func httpReceiveWrappedSWK(a *App) errorHandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) error {

		log.Info("Received HTTP client connection for ", common.PostWrappedSWK)

		err := authorizeEndpoint(r)
		if err != nil {
			return err
		}

		w.Header().Set("Content-Type", "application/json")

		// Note : Robust input validation is skipped for brevity

		// Extract wrapped SWK from request
		var ws common.WrappedSWKRequest
		err = json.NewDecoder(r.Body).Decode(&ws)
		if err != nil {
			log.Info(err)
			return resourceError{Message: "Unable to parse request.",
				StatusCode: http.StatusBadRequest}

		}

		swk, err := base64.StdEncoding.DecodeString(ws.SWK)
		if err != nil {
			log.Error("Unable to decode base64 SWK.")
			return resourceError{Message: "Unable to decode base64 SWK.",
				StatusCode: http.StatusBadRequest}
		}

		pSize := C.ulong(len(swk))
		log.Info("Size of Wrapped SWK : ", pSize)

		pStr := C.CBytes(swk)
		p := (*C.uint8_t)(unsafe.Pointer(pStr))

		// Unwrap inside the enclave.
		status := C.unwrap_SWK(p, pSize)
		if status != 0 {
			log.Error("SWK unwrapping failed.")
			return &resourceError{
				Message:    "SWK unwrapping failed!",
				StatusCode: http.StatusInternalServerError}

		}

		return nil
	}
}

// Step 3 : Receive Wrapped Message from Attesting App
func httpReceiveWrappedMessage(a *App) errorHandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) error {

		log.Info("Handling HTTP client connection for ", common.PostWrappedMessage)

		err := authorizeEndpoint(r)
		if err != nil {
			return err
		}

		w.Header().Set("Content-Type", "application/json")

		// Note : Robust input validation is skipped for brevity

		// Extract wrapped SWK from request
		var wm common.WrappedMessage
		err = json.NewDecoder(r.Body).Decode(&wm)
		if err != nil {
			log.Error(err)
			return resourceError{Message: "Unable to parse request.",
				StatusCode: http.StatusBadRequest}

		}

		wrappedMessage, err := base64.StdEncoding.DecodeString(wm.Message)
		if err != nil {
			log.Error("Unable to decode base64 wrapped message.")
			return resourceError{Message: "Unable to decode base64 wrapped message.",
				StatusCode: http.StatusBadRequest}
		}

		if len(wrappedMessage) == 0 {
			log.Error("Size of wrapped message can't be zero!")
			return &resourceError{
				Message:    "Size of wrapped message can't be zero!",
				StatusCode: http.StatusInternalServerError}
		}

		pSecretSize := C.ulong(len(wrappedMessage))
		pSecret := C.CBytes(wrappedMessage)
		pSecretPtr := (*C.uint8_t)(unsafe.Pointer(pSecret))

		//Unwrap the secret inside the Enclave
		status := C.unwrap_secret(pSecretPtr, pSecretSize)
		if status != 0 {
			return &resourceError{
				Message:    "Unwrapping of secret failed!",
				StatusCode: http.StatusInternalServerError}

		}

		return nil
	}
}

func (a *App) startServer() error {
	log.Trace("app:startServer() Entering")
	defer log.Trace("app:startServer() Leaving")

	c := a.configuration()
	if c == nil {
		return errors.New("Failed to load configuration")
	}

	log.Info("Starting Attested App ...")

	r := mux.NewRouter()
	r.SkipClean(true)

	r.Handle("/id", handlers.ContentTypeHandler(httpGetQuotePubkey(a), "application/json")).Methods("GET")
	r.Handle("/wrapped_swk", handlers.ContentTypeHandler(httpReceiveWrappedSWK(a), "application/json")).Methods("POST")
	r.Handle("/wrapped_message", handlers.ContentTypeHandler(httpReceiveWrappedMessage(a), "application/json")).Methods("POST")

	serverCert, err := tls.LoadX509KeyPair("cert.pem", "key.pem")
	if err != nil {
		log.WithError(err).Error("app:startServer() Unable to load TLS certificates!")
		return err
	}

	h := &http.Server{
		Addr:    fmt.Sprintf(":%d", c.AttestedAppServicePort),
		Handler: r,

		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{serverCert},
			ServerName:   common.SelfSignedCertSNI,
		},
	}

	err = a.EnclaveInit()
	if err != nil {
		log.WithError(err).Error("app:startServer() Error initializing enclave!")
		return err
	}

	// Setup signal handlers to gracefully handle termination
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP, syscall.SIGQUIT, syscall.SIGKILL)

	// Dispatch web server go routine
	go func() {
		err := h.ListenAndServeTLS("", "")
		if err != nil {
			log.Info(err)
			log.WithError(err).Info("Failed to start HTTP server")
			stop <- syscall.SIGTERM
		}
	}()

	<-stop

	// Destroy enclave and exit
	err = a.EnclaveDestroy()

	if err != nil {
		log.WithError(err).Info("app:startServer() Error destroying enclave")
	}

	return nil

}
