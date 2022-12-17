/*
* Copyright (C) 2020 Intel Corporation
* SPDX-License-Identifier: BSD-3-Clause
 */
package resource

import (
	"encoding/json"
	"fmt"
	"github.com/pkg/errors"
	"intel/isecl/lib/clients/v4"
	"intel/isecl/sgx_agent/v4/config"
	"intel/isecl/sgx_agent/v4/constants"
	"intel/isecl/sgx_agent/v4/utils"
	"io/ioutil"
	"net/http"
)

// GetTCBStatus Fetches TCB status from SCS using QEID and PCEID.
func GetTCBStatus(qeID, pceID string) (string, error) {
	log.Trace("resource/fetch_tcbstatus:GetTCBStatus() Entering")
	defer log.Trace("resource/fetch_tcbstatus:GetTCBStatus() Leaving")

	log.Debug("Fetching TCB Status from SCS...")

	status := ""

	conf := config.Global()
	if conf == nil {
		return status, errors.Wrap(errors.New("getTCBStatus: Configuration pointer is null"), "Config error")
	}

	SCSBaseURL := conf.ScsBaseURL

	fetchURL := SCSBaseURL + "/certification/v1/tcbstatus"
	request, _ := http.NewRequest("GET", fetchURL, nil)

	log.Debug("SCS TCB Fetch URL : ", fetchURL)

	// Add qeid and pceid query parameter for fetching tcb status
	q := request.URL.Query()
	q.Add("qeid", qeID)
	q.Add("pceid", pceID)
	request.URL.RawQuery = q.Encode()
	request.Header.Set("Authorization", "Bearer "+conf.BearerToken)

	tokenExpired, err := utils.JwtHasExpired(conf.BearerToken)
	if err != nil {
		slog.WithError(err).Error("resource/fetch_tcbstatus:GetTCBStatus() Error verifying token expiry")
		return status, errors.Wrap(err, "resource/fetch_tcbstatus:GetTCBStatus() Error verifying token expiry")
	}
	if tokenExpired {
		slog.Warn("resource/fetch_tcbstatus:GetTCBStatus() Token is about to expire within 7 days. Please refresh the token.")
	}

	client, err := clients.HTTPClientWithCADir(constants.TrustedCAsStoreDir)
	if err != nil {
		log.WithError(err).Error("resource/fetch_tcbstatus:Run() Error while creating http client")
		return status, errors.Wrap(err, "resource/fetch_tcbstatus:Run() Error while creating http client")
	}

	log.Debug("Client Created.")

	httpClient := &http.Client{
		Transport: client.Transport,
	}

	response, err := httpClient.Do(request)
	if response != nil {
		defer func() {
			derr := response.Body.Close()
			if derr != nil {
				log.WithError(derr).Error("Error closing response")
			}
		}()
	}
	if err != nil {
		slog.WithError(err).Error("resource/fetch_tcbstatus:Run() Error making request")
		return status, errors.Wrapf(err, "resource/fetch_tcbstatus:Run() Error making request %s", fetchURL)
	}

	log.Debug("Request Completed : ", response.StatusCode)

	if (response.StatusCode != http.StatusOK) && (response.StatusCode != http.StatusCreated) {
		return status, errors.Errorf("resource/fetch_tcbstatus: Run() Request made to %s returned status %d", fetchURL, response.StatusCode)
	}

	data, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return status, errors.Wrap(err, "resource/fetch_tcbstatus: Run() Error reading response")
	}

	log.Debugf("SCS Fetch TCBStatus response: -%v", string(data))

	var respBody map[string]interface{}
	err = json.Unmarshal(data, &respBody)
	if err != nil {
		return status, errors.Wrap(err, "resource/fetch_tcbstatus: Run() Error while unmarshaling the response")
	}

	status = fmt.Sprint(respBody["Status"])
	log.Debug("TCB Status : ", status)

	return status, nil
}
