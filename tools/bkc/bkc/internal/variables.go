/*
 * Copyright (C) 2021 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package commands

import (
	"github.com/intel-secl/intel-secl/v5/pkg/lib/tpmprovider"
	"os"
)

var tpm tpmprovider.TpmProvider
var tpmOwnerSecret string
var aikSecret string
var signingKeySecret string
var bindingKeySecret string

var (
	EventLogFile = ""
	RamfsDir     = ""

	CACertFile      = ""
	CACertKeyFile   = ""
	SavedFlavorFile = ""

	SavedManifestDir = ""
	SavedReportDir   = ""

	CheckNPWACMFile = ""
)

var (
	Write    = os.Stdout
	ErrWrite = os.Stderr
)
