/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
	"github.com/intel-secl/sample-sgx-attestation/v5/attestingApp/version"
	"os"
)

const helpStr = `Usage:
	sgx-attesting-app <command> [arguments]
	
Available Commands:
	help|-h|--help              Show this help message
	version|-v|--version        Show the version of current sgx-attesting-app build
	run                         Run sgx-attesting-app workflow

`

func (a *App) printUsage() {
	fmt.Fprintln(os.Stdout, helpStr)
}

func (a *App) printUsageWithError(err error) {
	fmt.Fprintln(os.Stderr, "Application returned with error:", err.Error())
	fmt.Fprintln(os.Stderr, helpStr)
}

func (a *App) printVersion() {
	fmt.Fprintf(os.Stdout, "%s %s-%s\nBuilt %s\n", "Attesting App", version.Version, version.GitHash, version.BuildDate)
}
