/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package config

import (
	"os"

	commConfig "github.com/intel-secl/intel-secl/v5/pkg/lib/common/config"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
	"intel/isecl/fda-sim/v5/constants"
)

const (
	FdsBaseUrl    = "fds-base-url"
	TcsBaseUrl    = "tcs-base-url"
	CustomToken   = "custom-token"
	NumberOfHosts = "number-of-hosts"
	HostStartId   = "host-start-id"
)

type Configuration struct {
	CmsBaseUrl  string `yaml:"cms-base-url" mapstructure:"cms-base-url"`
	FdsBaseUrl  string `yaml:"fds-base-url" mapstructure:"fds-base-url"`
	TcsBaseUrl  string `yaml:"tcs-base-url" mapstructure:"tcs-base-url"`
	CustomToken string `yaml:"custom-token" mapstructure:"custom-token"`

	Log commConfig.LogConfig `yaml:"log"`

	// Configuration for deploying hosts
	NumberOfHosts int `yaml:"number-of-hosts" mapstructure:"number-of-hosts"`
	HostStartId   int `yaml:"host-start-id" mapstructure:"host-start-id"`
}

// init sets the configuration file name and type
func init() {
	viper.SetConfigName(constants.ConfigFile)
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
}

// LoadConfiguration loads application specific configuration from config.yml
func LoadConfiguration() (*Configuration, error) {
	ret := Configuration{}
	// Find and read the config file
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			// Config file not found
			return &ret, errors.Wrap(err, "Config file not found")
		}
		return &ret, errors.Wrap(err, "Failed to load config")
	}
	if err := viper.Unmarshal(&ret); err != nil {
		return &ret, errors.Wrap(err, "Failed to unmarshal config")
	}
	return &ret, nil
}

// Save saves application specific configuration to config.yml
func (config *Configuration) Save(filename string) error {
	configFile, err := os.OpenFile(filename, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if err != nil {
		return errors.Wrap(err, "Failed to create config file")
	}
	defer func() {
		err := configFile.Close()
		if err != nil {
			log.WithError(err).Error("Error closing config file")
		}
	}()
	err = yaml.NewEncoder(configFile).Encode(config)
	if err != nil {
		return errors.Wrap(err, "Failed to encode config structure")
	}
	return nil
}
