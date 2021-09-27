/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package common

import (
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

type Configuration struct {
	AttestedAppServiceHost string `yaml:"attestedapp-host" mapstructure:"attestedapp-host"`
	AttestedAppServicePort int    `yaml:"attestedapp-port" mapstructure:"attestedapp-port"`
	SqvsUrl                string `yaml:"sqvs-url" mapstructure:"sqvs-url"`
	DummyBearerToken       string `yaml:"bearer-token" mapstructure:"bearer-token"`
}

func LoadConfiguration() (*Configuration, error) {
	// Look for config file in current working directory
	viper.AddConfigPath("./")
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")

	var ret Configuration
	// Find and read the config file
	if err := viper.ReadInConfig(); err != nil {
		log.Info("Error : ", err)
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			// Config file not found
			return &ret, errors.Wrap(err, "Config file not found")
		}
		return &ret, errors.Wrap(err, "Failed to load config")
	}

	if err := viper.Unmarshal(&ret); err != nil {
		log.Info("Error : ", err)
		return &ret, errors.Wrap(err, "Failed to unmarshal config")
	}
	return &ret, nil
}
