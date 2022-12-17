/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package config

import (
	"errors"
	"gopkg.in/yaml.v2"
	"net/url"
	"os"
	"path"
	"strconv"

	errorLog "github.com/pkg/errors"
	commLog "intel/isecl/lib/common/v4/log"
	"intel/isecl/lib/common/v4/setup"
	"intel/isecl/sgx_agent/v4/constants"

	log "github.com/sirupsen/logrus"
)

var slog = commLog.GetSecurityLogger()

// Configuration is the global configuration struct that is marshalled/unmarshalled to a persisted yaml file
// Probably should embed a config generic struct
type Configuration struct {
	configFile       string
	CmsTLSCertDigest string
	LogMaxLength     int
	LogEnableStdout  bool
	LogLevel         log.Level

	CMSBaseURL    string
	SGXHVSBaseURL string
	ScsBaseURL    string

	BearerToken        string
	NumberOfHosts      int
	HostStartId        int
	WaitTime           int
	RetryCount         int
	SHVSUpdateInterval int
}

var global *Configuration

func Global() *Configuration {
	log.Trace("config/config:Global() Entering")
	defer log.Trace("config/config:Global() Leaving")

	if global == nil {
		global = Load(path.Join(constants.ConfigDir, constants.ConfigFile))
	}
	return global
}

func (conf *Configuration) SaveConfiguration(taskName string, c setup.Context) error {
	log.Trace("config/config:SaveConfiguration() Entering")
	defer log.Trace("config/config:SaveConfiguration() Leaving")

	// target config changes only in scope for the setup task
	if taskName == "all" || taskName == "download_ca_cert" || taskName == "download_cert" {
		tlsCertDigest, err := c.GetenvString("CMS_TLS_CERT_SHA384", "TLS certificate digest")
		if err == nil && tlsCertDigest != "" {
			conf.CmsTLSCertDigest = tlsCertDigest
		} else if conf.CmsTLSCertDigest == "" {
			log.Error("CMS_TLS_CERT_SHA384 is not defined in environment")
			return errorLog.Wrap(errors.New("CMS_TLS_CERT_SHA384 is not defined in environment"), "SaveConfiguration() ENV variable not found")
		}

		cmsBaseURL, err := c.GetenvString("CMS_BASE_URL", "CMS Base URL")
		if err == nil && cmsBaseURL != "" {
			if _, err = url.Parse(cmsBaseURL); err != nil {
				log.Error("CMS_BASE_URL provided is invalid")
				return errorLog.Wrap(err, "SaveConfiguration() CMS_BASE_URL provided is invalid")
			} else {
				conf.CMSBaseURL = cmsBaseURL
			}
		} else if conf.CMSBaseURL == "" {
			log.Error("CMS_BASE_URL is not defined in environment")
			return errorLog.Wrap(errors.New("CMS_BASE_URL is not defined in environment"),
				"SaveConfiguration() ENV variable not found")
		}
	}

	numberOfHosts, err := c.GetenvString("HOST_COUNT", "Number of  Hosts")
	if err == nil && numberOfHosts != "" {
		conf.NumberOfHosts, err = strconv.Atoi(numberOfHosts)
	} else if conf.NumberOfHosts == 0 {
		conf.NumberOfHosts = constants.NumberOfHosts
	}
	hostStartId, err := c.GetenvString("HOST_START_ID", "Hosts Starts from")
	if err == nil && hostStartId != "" {
		conf.HostStartId, err = strconv.Atoi(hostStartId)
	} else if conf.HostStartId == 0 {
		conf.HostStartId = constants.DefaultHostStartId
	}
	return conf.Save()
}

func (conf *Configuration) Save() error {
	log.Trace("config/config:Save() Entering")
	defer log.Trace("config/config:Save() Leaving")

	if conf.configFile == "" {
		return errors.New("no config file")
	}
	file, err := os.OpenFile(conf.configFile, os.O_RDWR, 0)
	if err != nil {
		// we have an error
		if os.IsNotExist(err) {
			// error is that the config doesnt yet exist, create it
			file, err = os.OpenFile(conf.configFile, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
			if err != nil {
				return err
			}
		} else {
			// someother I/O related error
			return err
		}
	}
	defer func() {
		derr := file.Close()
		if derr != nil {
			log.WithError(derr).Error("Failed to flush config.yml")
		}
	}()

	return yaml.NewEncoder(file).Encode(conf)
}

func Load(filePath string) *Configuration {
	log.Trace("config/config:Load() Entering")
	defer log.Trace("config/config:Load() Leaving")

	var c Configuration
	file, _ := os.Open(filePath)
	if file != nil {
		defer func() {
			derr := file.Close()
			if derr != nil {
				log.WithError(derr).Error("Failed to close config.yml")
			}
		}()
		err := yaml.NewDecoder(file).Decode(&c)
		if err != nil {
			log.WithError(err).Error("Failed to decode config.yml contents")
		}

	} else {
		c.LogLevel = log.InfoLevel
	}

	c.configFile = filePath
	return &c
}
