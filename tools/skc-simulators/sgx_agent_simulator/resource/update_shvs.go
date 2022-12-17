/*
* Copyright (C) 2020 Intel Corporation
* SPDX-License-Identifier: BSD-3-Clause
 */
package resource

import (
	"bytes"
	"encoding/json"
	"github.com/pkg/errors"
	"intel/isecl/lib/clients/v4"
	"intel/isecl/sgx_agent/v4/config"
	"intel/isecl/sgx_agent/v4/constants"
	"intel/isecl/sgx_agent/v4/utils"
	"io/ioutil"
	"net/http"
	"strconv"
	"time"
)

// UpdateSHVSPeriodically Updates SHVS periodically. If an error occurs,
// error is logged and wait for the next update.
func UpdateSHVSPeriodically(sgxDiscovery *SGXDiscoveryData, platformData *PlatformData, hardwareUUID string, period int) error {
	// update SHVS as per configured timer.
	for {
		tcbStatus, err := GetTCBStatus(platformData.QeID, platformData.PceID)
		if err != nil {
			// Log error . But don't throw it.
			log.WithError(err).Error("Unable to get TCB Status from SCS.")
		} else {
			tcbUptoDate, _ := strconv.ParseBool(tcbStatus)
			err = PushSGXEnablementData(sgxDiscovery, hardwareUUID, tcbUptoDate)
			if err != nil {
				// Log error . But don't throw it.
				log.WithError(err).Error("Unable to update SHVS.")
			}
		}

		// Sleep here on a timer.
		log.Infof("Waiting for %v minutes until next update.", period)
		time.Sleep(time.Duration(period) * time.Minute)
	}
}

type SGXHostInfo struct {
	HostName     string `json:"host_name"`
	Description  string `json:"description,omitempty"`
	UUID         string `json:"uuid"`
	SgxSupported bool   `json:"sgx_supported"`
	SgxEnabled   bool   `json:"sgx_enabled"`
	FlcEnabled   bool   `json:"flc_enabled"`
	EpcOffset    string `json:"epc_offset"`
	EpcSize      string `json:"epc_size"`
	TcbUptodate  bool   `json:"tcb_upToDate"`
}

// PushSGXEnablementData updates SHVS With SGX Discovery Data and TCB Status.
func PushSGXEnablementData(sgxDiscovery *SGXDiscoveryData, hardwareUUID string, tcbStatus bool) error {
	log.Trace("resource/update_shvs:PushHostSGXDiscovery Entering")
	defer log.Trace("resource/update_shvs:PushHostSGXDiscovery Leaving")

	conf := config.Global()
	if conf == nil {
		return errors.Wrap(errors.New("UpdateHostSGXDiscovery: Configuration pointer is null"), "Config error")
	}

	apiEndPoint := conf.SGXHVSBaseURL + "/hosts"
	log.Debug("Updating SGX Discovery data to SHVS at ", apiEndPoint)
	for i := conf.HostStartId; i < conf.HostStartId+conf.NumberOfHosts; i++ {
		ExtractSGXPlatformValues(i)
		id_str := strconv.Itoa(i)
		hostName := "sgxagent" + id_str
		for len(id_str) < 5 {
			id_str = "0" + id_str
		}

		requestData := SGXHostInfo{
			HostName:     hostName,
			UUID:         hardwareUUID,
			SgxSupported: sgxDiscovery.SgxSupported,
			SgxEnabled:   sgxDiscovery.SgxEnabled,
			FlcEnabled:   sgxDiscovery.FlcEnabled,
			EpcOffset:    sgxDiscovery.EpcStartAddress,
			EpcSize:      sgxDiscovery.EpcSize,
			TcbUptodate:  tcbStatus}

		reqBytes, err := json.Marshal(requestData)
		if err != nil {
			return errors.Wrap(err, "UpdateHostSGXDiscovery: struct to json marshalling failed")
		}
		request, _ := http.NewRequest("POST", apiEndPoint, bytes.NewBuffer(reqBytes))
		request.Header.Set("Content-Type", "application/json")
		request.Header.Set("Authorization", "Bearer "+conf.BearerToken)

		tokenExpired, err := utils.JwtHasExpired(conf.BearerToken)
		if err != nil {
			slog.WithError(err).Error("resource/update_shvs:UpdateHOSTSGXDiscovery() Error verifying token expiry")
			return errors.Wrap(err, "resource/update_shvs:UpdateHOSTSGXDiscovery() Error verifying token expiry")
		}
		if tokenExpired {
			slog.Warn("resource/update_shvs:UpdateHOSTSGXDiscovery() Token is about to expire within 7 days. Please refresh the token.")
		}
		client, err := clients.HTTPClientWithCADir(constants.TrustedCAsStoreDir)
		if err != nil {
			log.WithError(err).Error("resource/update_shvs:UpdateHOSTSGXDiscovery() Error while creating http client")
			return errors.Wrap(err, "resource/update_shvs:UpdateHOSTSGXDiscovery() Error while creating http client")
		}

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
			slog.WithError(err).Error("resource/UpdateHostSGXDiscovery Error making request")
			return errors.Wrapf(err, "resource/UpdateHostSGXDiscovery Error making request %s", apiEndPoint)
		}

		log.Debug("Request Completed : ", response.StatusCode)
		if (response.StatusCode != http.StatusOK) && (response.StatusCode != http.StatusCreated) {
			return errors.Errorf("resource/UpdateHostSGXDiscovery Request made to %s returned status %d", apiEndPoint, response.StatusCode)
		}

		data, err := ioutil.ReadAll(response.Body)
		if err != nil {
			return errors.Wrap(err, "resource/UpdateHostSGXDiscovery Error reading response")
		}

		log.Debugf("Response from SHVS: -%v", string(data))
	}
	return nil
}
