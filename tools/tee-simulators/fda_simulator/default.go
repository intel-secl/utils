/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	commConfig "github.com/intel-secl/intel-secl/v5/pkg/lib/common/config"
	"github.com/spf13/viper"
	"intel/isecl/fda-sim/v5/config"
	"intel/isecl/fda-sim/v5/constants"
)

// This init function sets the default values for viper keys.
func init() {
	// Set default values for log
	viper.SetDefault(commConfig.LogLevel, constants.DefaultLogLevel)
	viper.SetDefault(commConfig.LogMaxLength, constants.DefaultLogMaxlength)
	viper.SetDefault(commConfig.LogEnableStdout, true)

	viper.SetDefault(config.NumberOfHosts, 1)
	viper.SetDefault(config.HostStartId, 1)
}

func defaultConfig() *config.Configuration {
	return &config.Configuration{
		CmsBaseUrl: viper.GetString(commConfig.CmsBaseUrl),
		FdsBaseUrl: viper.GetString(config.FdsBaseUrl),
		TcsBaseUrl: viper.GetString(config.TcsBaseUrl),
		Log: commConfig.LogConfig{
			MaxLength:    viper.GetInt(commConfig.LogMaxLength),
			EnableStdout: viper.GetBool(commConfig.LogEnableStdout),
			Level:        viper.GetString(commConfig.LogLevel),
		},
		CustomToken:   viper.GetString(config.CustomToken),
		NumberOfHosts: viper.GetInt(config.NumberOfHosts),
		HostStartId:   viper.GetInt(config.HostStartId),
	}
}
