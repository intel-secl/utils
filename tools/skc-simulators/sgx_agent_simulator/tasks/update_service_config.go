/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package tasks

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	clog "intel/isecl/lib/common/v4/log"
	"intel/isecl/lib/common/v4/setup"
	"intel/isecl/sgx_agent/v4/config"
	"intel/isecl/sgx_agent/v4/constants"
	"io"
	"net/url"
)

var log = clog.GetDefaultLogger()
var slog = clog.GetSecurityLogger()

type Update_Service_Config struct {
	Flags         []string
	Config        *config.Configuration
	ConsoleWriter io.Writer
}

func (u Update_Service_Config) Run(c setup.Context) error {
	log.Trace("tasks/update_service_config:Run() Entering")
	defer log.Trace("tasks/update_service_config:Run() Leaving")

	fmt.Fprintln(u.ConsoleWriter, "Running update_service_config...")

	sgxHVSBaseURL, err := c.GetenvString("SHVS_BASE_URL", "HVS Base URL")
	if err == nil && sgxHVSBaseURL != "" {
		if _, err = url.Parse(sgxHVSBaseURL); err != nil {
			return errors.Wrap(err, "SaveConfiguration() SHVS_BASE_URL provided is invalid")
		} else {
			u.Config.SGXHVSBaseURL = sgxHVSBaseURL
		}
	} else if u.Config.SGXHVSBaseURL == "" {
		log.Info("SHVS_BASE_URL is not defined in environment")
	}

	scsBaseURL, err := c.GetenvString("SCS_BASE_URL", "SCS Base URL")
	if err == nil && scsBaseURL != "" {
		if _, err = url.Parse(scsBaseURL); err != nil {
			return errors.Wrap(err, "SaveConfiguration() SCS_BASE_URL provided is invalid")
		} else {
			u.Config.ScsBaseURL = scsBaseURL
		}
	} else if u.Config.ScsBaseURL == "" {
		log.Error("SCS_BASE_URL is not defined in environment")
		return errors.Wrap(errors.New("SCS_BASE_URL is not defined in environment"),
			"SaveConfiguration() ENV variable not found")
	}

	bearerToken, err := c.GetenvString("BEARER_TOKEN", "BEARER TOKEN")
	if err == nil && bearerToken != "" {
		u.Config.BearerToken = bearerToken
	} else if u.Config.BearerToken == "" {
		log.Error("BEARER_TOKEN is not defined in environment")
		return errors.Wrap(errors.New("BEARER_TOKEN is not defined in environment"),
			"SaveConfiguration() ENV variable not found")
	}

	logLevel, err := c.GetenvString("SGX_AGENT_LOGLEVEL", "SGX_AGENT Log Level")
	if err != nil {
		slog.Infof("config/config:SaveConfiguration() %s not defined, using default log level: Info", constants.SGXAgentLogLevel)
		u.Config.LogLevel = logrus.InfoLevel
	} else {
		llp, err := logrus.ParseLevel(logLevel)
		if err != nil {
			slog.Info("config/config:SaveConfiguration() Invalid log level specified in env, using default log level: Info")
			u.Config.LogLevel = logrus.InfoLevel
		} else {
			u.Config.LogLevel = llp
			slog.Infof("config/config:SaveConfiguration() Log level set %s\n", logLevel)
		}
	}

	waitTime, err := c.GetenvInt("WAIT_TIME", "Time between each retries to PCS")
	if err == nil {
		if waitTime > constants.DefaultWaitTime {
			u.Config.WaitTime = waitTime
		} else {
			u.Config.WaitTime = constants.DefaultWaitTime
		}
	} else {
		u.Config.WaitTime = constants.DefaultWaitTime
	}

	retryCount, err := c.GetenvInt("RETRY_COUNT", "Push Data Retry Count to SCS")
	if err == nil {
		if retryCount > constants.DefaultRetryCount {
			u.Config.RetryCount = retryCount
		} else {
			u.Config.RetryCount = constants.DefaultRetryCount
		}
	} else {
		u.Config.RetryCount = constants.DefaultRetryCount
	}

	shvsUpdateInterval, err := c.GetenvInt("SHVS_UPDATE_INTERVAL", "SHVS update interval in minutes")
	if err == nil {
		if shvsUpdateInterval > 0 && shvsUpdateInterval <= constants.DefaultSHVSUpdateInterval {
			u.Config.SHVSUpdateInterval = shvsUpdateInterval
			log.Info("SHVS Update interval is out of range 1 < SHVSUpdateInterval < 120 . Using default value of 120 minutes")
		} else {
			u.Config.SHVSUpdateInterval = constants.DefaultSHVSUpdateInterval
		}
	} else {
		u.Config.SHVSUpdateInterval = constants.DefaultSHVSUpdateInterval
	}

	logMaxLen, err := c.GetenvInt("SGX_AGENT_LOG_MAX_LENGTH", "SGX Agent Log maximum length")
	if err != nil || logMaxLen < constants.DefaultLogEntryMaxLength {
		u.Config.LogMaxLength = constants.DefaultLogEntryMaxLength
	} else {
		u.Config.LogMaxLength = logMaxLen
	}

	logEnableStdout, err := c.GetenvString("SGX_AGENT_ENABLE_CONSOLE_LOG", "SGX Agent Enable standard output")
	if err != nil || logEnableStdout == "" {
		u.Config.LogEnableStdout = false
	} else {
		u.Config.LogEnableStdout = true
	}

	err = u.Config.Save()
	if err != nil {
		return errors.Wrap(err, "failed to save SGX Agent config")
	}
	return nil
}

func (u Update_Service_Config) Validate(c setup.Context) error {
	log.Trace("tasks/update_service_config:Validate() Entering")
	defer log.Trace("tasks/update_service_config:Validate() Leaving")
	return nil
}
