/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package constants

// general FDA Simulator constants
const (
	ExplicitServiceName = "Feature Discovery Agent Simulator"
	ServiceName         = "FDA Simulator"
	ServiceDir          = "fda-sim/"
	ServiceUserName     = "fda-sim"

	HomeDir      = "/opt/" + ServiceDir
	RunDirPath   = "/run/" + ServiceDir
	ExecLinkPath = "/usr/bin/" + ServiceUserName
	LogDir       = "/var/log/" + ServiceDir
	ConfigDir    = "/etc/" + ServiceDir
	ConfigFile   = "config"

	// certificates' path
	TrustedCaCertsDir = ConfigDir + "certs/trustedca/"

	// defaults
	DefaultConfigFilePath = ConfigDir + "config.yml"

	// log constants
	DefaultLogLevel     = "info"
	DefaultLogMaxlength = 1500
)
