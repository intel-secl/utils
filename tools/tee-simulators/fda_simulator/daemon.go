/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"github.com/intel-secl/intel-secl/v5/pkg/clients"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/intel-secl/intel-secl-tee/v5/pkg/clients/fds"
	"github.com/intel-secl/intel-secl-tee/v5/pkg/clients/tcs"
	fdsModel "github.com/intel-secl/intel-secl-tee/v5/pkg/model/fds"
	"github.com/intel-secl/intel-secl/v5/pkg/lib/common/crypt"
	commLog "github.com/intel-secl/intel-secl/v5/pkg/lib/common/log"
	"github.com/pkg/errors"
	"intel/isecl/fda-sim/v5/constants"
	"intel/isecl/fda-sim/v5/utils"
)

var defaultLog = commLog.GetDefaultLogger()
var secLog = commLog.GetSecurityLogger()
var tcbStatusNA = "NA"

func (app *App) run() error {
	defaultLog.Trace("fda_simulator/daemon:run() Entering")
	defer defaultLog.Trace("fda_simulator/daemon:run() Leaving")

	configuration := app.configuration()
	if configuration == nil {
		return errors.New("fda_simulator/daemon:run() Failed to load configuration")
	}
	// Initialize log
	if err := app.configureLogs(configuration.Log.EnableStdout, true); err != nil {
		return errors.Wrap(err, "fda_simulator/daemon:run() Failed to initialize logging")
	}

	if IsEmpty(constants.TrustedCaCertsDir) {
		err := app.getCmsCaCert()
		if err != nil {
			return errors.Wrap(err, "fda_simulator/daemon:startDaemon() Failed to get CMS CA cert")
		}
	}

	caCerts, err := crypt.GetCertsFromDir(constants.TrustedCaCertsDir)
	if err != nil {
		return errors.Wrapf(err, "fda_simulator/daemon:run() Error in reading certs from %s", constants.TrustedCaCertsDir)
	}

	var tcsClient tcs.Client

	for i := configuration.HostStartId; i < configuration.HostStartId+configuration.NumberOfHosts; i++ {
		_, _, _, platformData, _ := utils.GetPlatformData(string(i))

		// Push data to TEE Caching Service
		if configuration.TcsBaseUrl != "" {
			defaultLog.Info("fda_simulator/daemon:run() Starting platform data push to TCS")
			if !strings.HasSuffix(configuration.TcsBaseUrl, "/") {
				configuration.TcsBaseUrl += "/"
			}
			baseUrl, err := url.Parse(configuration.TcsBaseUrl)
			if err != nil {
				return errors.Wrap(err, "fda_simulator/daemon:run() Unable to parse TCS base url")
			}

			tcsClient = tcs.NewClient(baseUrl, caCerts, configuration.CustomToken, 0, time.Minute*time.Duration(0))
			err = tcsClient.PushPlatformData(platformData)
			if err != nil {
				defaultLog.WithError(err).Error("fda_simulator/daemon:run() Error in pushing platform data to TCS")
			} else {
				defaultLog.Info("fda_simulator/daemon:run() Platform data pushed successfully to TCS")
			}

		}
	}

	for i := configuration.HostStartId; i < configuration.HostStartId+configuration.NumberOfHosts; i++ {
		sgxData, tdxData, hostData, platformData, _ := utils.GetPlatformData(strconv.Itoa(i))
		// Push data to Feature Discovery Service
		if configuration.FdsBaseUrl != "" {
			defaultLog.Info("fda_simulator/daemon:run() Starting discovery data push to FDS")
			if !strings.HasSuffix(configuration.FdsBaseUrl, "/") {
				configuration.FdsBaseUrl += "/"
			}
			baseUrl, err := url.Parse(configuration.FdsBaseUrl)
			if err != nil {
				return errors.Wrap(err, "fda_simulator/daemon:run() Unable to parse FDS base url")
			}

			var features fdsModel.HardwareFeatures
			if tdxData.TdxSupported {
				features.TDX = &fdsModel.TDX{
					Enabled: &tdxData.TdxEnabled,
					Meta: &fdsModel.Meta{
						TcbUptoDate: &tcbStatusNA,
					},
				}
			}

			if sgxData.SgxSupported {
				features.SGX = &fdsModel.SGX{
					Enabled: &sgxData.SgxEnabled,
					Meta: &fdsModel.Meta{
						IntegrityEnabled: &sgxData.SgxIntegrity,
						FlcEnabled:       &sgxData.FlcEnabled,
						EpcOffset:        &sgxData.EpcOffset,
						EpcSize:          &sgxData.EpcSize,
						TcbUptoDate:      &tcbStatusNA,
					},
				}
			}

			hostInfo := &fdsModel.HostInfo{
				HardwareUUID:     hostData.HardwareUuid,
				HardwareFeatures: &features,
			}

			host := &fdsModel.HostCreateRequest{
				HostName: hostData.HostName,
				HostInfo: hostInfo,
			}

			fdsClient := fds.NewClient(baseUrl, caCerts, configuration.CustomToken, 0, time.Minute*time.Duration(0))
			err = app.refreshPlatformData(tcsClient, fdsClient, platformData.QeId, platformData.PceId, host)
			if err != nil {
				defaultLog.WithError(err).Error("fda_simulator/daemon:run() Error in pushing discovery data")
			}

		}
	}
	return nil
}

func (app *App) refreshPlatformData(tcsClient tcs.Client, fdsClient fds.Client, qeId, pceId string, host *fdsModel.HostCreateRequest) error {
	defaultLog.Trace("fda_simulator/daemon:refreshPlatformData() Entering")
	defer defaultLog.Trace("fda_simulator/daemon:refreshPlatformData() Leaving")

	if tcsClient != nil {
		resp, err := tcsClient.GetTcbStatus(qeId, pceId)
		if err != nil {
			defaultLog.WithError(err).Error("fda_simulator/daemon:refreshPlatformData() Error in fetching Tcb Status")
		} else {
			host.HostInfo.HardwareFeatures.SGX.Meta.TcbUptoDate = &resp.Status
			if host.HostInfo.HardwareFeatures.TDX != nil {
				host.HostInfo.HardwareFeatures.TDX.Meta.TcbUptoDate = &resp.Status
			}
		}
	}

	err := fdsClient.CreateHost(host)
	if err != nil {
		defaultLog.WithError(err).Error("fda_simulator/daemon:refreshPlatformData() Error in pushing discovery data to FDS")
	} else {
		defaultLog.Info("fda_simulator/daemon:refreshPlatformData() Discovery data pushed successfully to FDS")
	}

	return nil
}

func (app *App) getCmsCaCert() error {
	parsedUrl, err := url.Parse(app.Config.CmsBaseUrl)
	if err != nil {
		return errors.Wrap(err, "Failed to parse CMS URL")
	}
	certificates, _ := parsedUrl.Parse("ca-certificates")
	endpoint := parsedUrl.ResolveReference(certificates)
	req, err := http.NewRequest("GET", endpoint.String(), nil)
	if err != nil {
		return errors.Wrap(err, "Failed to instantiate http request to CMS")
	}
	req.Header.Set("Accept", "application/x-pem-file")
	//InsecureSkipVerify is set to true as connection is validated manually
	client := clients.HTTPClientTLSNoVerify()
	resp, err := client.Do(req)
	if err != nil {
		return errors.Wrap(err, "Failed to perform HTTP request to CMS")
	}
	certBytes, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return errors.Wrap(err, "Failed to read CMS response body")
	}
	err = crypt.SavePemCertWithShortSha1FileName(certBytes, constants.TrustedCaCertsDir)
	if err != nil {
		return errors.Wrap(err, "crypt.SavePemCertWithShortSha1FileName failed")
	}
	return nil
}

func IsEmpty(name string) bool {
	f, err := os.Open(name)
	if err != nil {
		defaultLog.WithError(err).Error("Error opening CA cert directory")
		return false
	}
	defer f.Close()

	_, err = f.Readdirnames(1)
	if err == io.EOF {
		return true
	}
	defaultLog.WithError(err).Error("Error reading directory")
	return false
}
