/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
	"os"

	"intel/isecl/fda-sim/v5/constants"
)

func (app *App) executablePath() string {
	if app.ExecutablePath != "" {
		return app.ExecutablePath
	}
	exc, err := os.Executable()
	if err != nil {
		// If we can't find self-executable path, we're probably in a state that is panic() worthy
		panic(err)
	}
	return exc
}

func (app *App) homeDir() string {
	if app.HomeDir != "" {
		return app.HomeDir
	}
	return constants.HomeDir
}

func (app *App) configDir() string {
	if app.ConfigDir != "" {
		return app.ConfigDir
	}
	return constants.ConfigDir
}

func (app *App) logDir() string {
	if app.LogDir != "" {
		return app.LogDir
	}
	return constants.LogDir
}

func (app *App) execLinkPath() string {
	if app.ExecLinkPath != "" {
		return app.ExecLinkPath
	}
	return constants.ExecLinkPath
}

func (app *App) runDirPath() string {
	if app.RunDirPath != "" {
		return app.RunDirPath
	}
	return constants.RunDirPath
}

func (app *App) uninstall() error {
	fmt.Println("Uninstalling " + constants.ExplicitServiceName)

	fmt.Println("removing : ", app.executablePath())
	err := os.Remove(app.executablePath())
	if err != nil {
		defaultLog.WithError(err).Error("Error removing executable")
	}
	fmt.Println("removing : ", app.execLinkPath())
	err = os.Remove(app.execLinkPath())
	if err != nil {
		defaultLog.WithError(err).Error("Error removing ", app.execLinkPath())
	}

	fmt.Println("removing : ", app.configDir())
	err = os.RemoveAll(app.configDir())
	if err != nil {
		defaultLog.WithError(err).Error("Error removing config dir")
	}

	fmt.Println("removing : ", app.logDir())
	err = os.RemoveAll(app.logDir())
	if err != nil {
		defaultLog.WithError(err).Error("Error removing log dir")
	}
	fmt.Println("removing : ", app.homeDir())
	err = os.RemoveAll(app.homeDir())
	if err != nil {
		defaultLog.WithError(err).Error("Error removing home dir")
	}

	fmt.Println(constants.ExplicitServiceName + " uninstalled")
	return nil
}
