/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
)

const helpStr = `Usage:
	fda <command> [arguments]
	
Available Commands:
	help|-h|--help                  Show this help message
	run                             Run FDA simulator
	update-config                   Updates config by reading it from fda-sim.env file.
	uninstall                       Uninstall FDA simulator. All configuration and data files will be removed if this flag is set.
`

func (app *App) printUsage() {
	fmt.Fprintln(app.consoleWriter(), helpStr)
}

func (app *App) printUsageWithError(err error) {
	fmt.Fprintln(app.errorWriter(), "Application returned with error:", err.Error())
	fmt.Fprintln(app.errorWriter(), helpStr)
}
